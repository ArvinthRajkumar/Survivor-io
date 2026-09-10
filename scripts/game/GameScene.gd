extends Node2D
## Assembles and runs one attempt at a level.
##
## This node is the wiring hub only: it spawns the player, hands the level data
## to each system and routes signals between the simulation and the UI. All the
## actual behaviour lives in the systems it owns.

const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const AUTOSAVE_INTERVAL := 15.0
## How long the tree may sit paused with no dialog visible before the watchdog
## treats it as a fault. Comfortably longer than any one-frame handover.
const STUCK_PAUSE_GRACE := 1.5

@onready var background: Node2D = $BackgroundLayer/Background
@onready var world: Node2D = $World
@onready var enemies: EnemyDirector = $World/Enemies
@onready var projectiles: ProjectileSystem = $World/Projectiles
@onready var pickups: Node2D = $World/Pickups
@onready var effects: Node2D = $World/Effects
@onready var hazards: HazardSystem = $World/Hazards
@onready var fx: EffectSpawner = $World/FX
@onready var waves: WaveDirector = $Waves
@onready var camera: Camera2D = $Camera
@onready var hud: Control = $UI/HUD
@onready var upgrade_panel: Control = $UI/UpgradePanel
@onready var pause_menu: Control = $UI/PauseMenu
@onready var results_screen: Control = $UI/Results
@onready var revive_prompt: Control = $UI/RevivePrompt

var player: Player
var level: LevelData

var _upgrade_open: bool = false
var _shake: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO
## Set by `-- --smoke`: drives the player and auto-picks upgrades so a headless
## soak run exercises levelling, powers and bosses without a human.
var _autopilot: bool = false
var _autopilot_time: float = 0.0
## Endless runs are long, so the run state is checkpointed periodically as well
## as on shutdown - a crash or a force-quit then costs at most this many seconds.
var _autosave_timer: float = AUTOSAVE_INTERVAL
## Watchdog for the one failure the player cannot do anything about: the tree
## left paused with nothing on screen to un-pause it. See _watch_for_stuck_pause.
var _stuck_timer: float = 0.0


func _ready() -> void:
	# The watchdog is the only thing here that has to run while the tree is
	# paused, and it gets its own node for it. Setting PROCESS_MODE_ALWAYS on the
	# scene root instead was a real bug: children default to
	# PROCESS_MODE_INHERIT, so the whole world - enemies, projectiles, the
	# player - kept simulating through every level-up.
	_install_pause_watchdog()
	level = RunManager.level_data
	if level == null:
		push_error("GameScene: no level configured; returning to the menu.")
		GameManager.goto_main_menu()
		return

	_spawn_player()
	background.call("setup", level, camera)
	hazards.setup(level)
	waves.setup(level)
	enemies.set_player_position(player.global_position)

	_connect_signals()
	hud.call("bind", player, level)

	_autopilot = DevTools.pilot
	AudioManager.play_music(&"battle")
	RunManager.start()
	waves.start()
	SaveManager.capture_active_run()


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate() as Player
	world.add_child(player)
	player.global_position = Vector2.ZERO
	HeroPassives.apply(RunManager.hero, RunManager.stats)
	player.setup(RunManager.hero, RunManager.stats)
	camera.global_position = player.global_position


func _connect_signals() -> void:
	RunManager.leveled_up.connect(_on_leveled_up)
	RunManager.run_finished.connect(_on_run_finished)
	player.died.connect(_on_player_died)
	waves.boss_warning.connect(_on_boss_warning)
	waves.boss_spawned.connect(_on_boss_spawned)
	waves.boss_defeated.connect(_on_boss_defeated)
	upgrade_panel.connect("choice_made", _on_upgrade_chosen)
	pause_menu.connect("resume_requested", _on_resume)
	pause_menu.connect("quit_requested", _on_quit)
	results_screen.connect("retry_requested", _on_retry)
	results_screen.connect("menu_requested", _on_quit)
	revive_prompt.connect("revive_accepted", _on_revive_accepted)
	revive_prompt.connect("revive_declined", _on_revive_declined)
	hud.connect("pause_pressed", _on_pause_pressed)
	hud.connect("joystick_moved", _on_joystick_moved)
	GameManager.shake_requested.connect(shake)


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if player == null or not is_instance_valid(player):
		return
	_update_camera(delta)
	enemies.set_player_position(player.global_position)
	if _autopilot:
		_drive_autopilot(delta)

	_autosave_timer -= delta
	if _autosave_timer <= 0.0:
		_autosave_timer = AUTOSAVE_INTERVAL
		SaveManager.capture_active_run()

	# Level-ups queue up while a panel is already open.
	if not _upgrade_open and RunManager.pending_level_ups > 0 and not RunManager.finished:
		_open_upgrade_panel()


## A node whose only job is to run the watchdog below while the rest of the
## scene is frozen. It is created in code rather than placed in the scene so the
## pairing with _watch_for_stuck_pause cannot be broken by editing the .tscn.
func _install_pause_watchdog() -> void:
	var watchdog := Node.new()
	watchdog.name = "PauseWatchdog"
	watchdog.set_script(preload("res://scripts/game/PauseWatchdog.gd"))
	watchdog.process_mode = Node.PROCESS_MODE_ALWAYS
	watchdog.call("bind", _watch_for_stuck_pause)
	add_child(watchdog)


## Runs while the tree is paused (driven by PauseWatchdog), which is the only
## time it can do its job: if the game is paused but nothing is on screen that
## could release that pause, the player has no way out except killing the app.
## Rather than trust every open/close pair to be perfectly balanced, this
## notices the state and recovers from it.
func _watch_for_stuck_pause(delta: float) -> void:
	if not get_tree().paused or RunManager.finished:
		_stuck_timer = 0.0
		return
	# Any of these being on screen means the pause is legitimate and someone is
	# being asked to make a decision.
	var owned := pause_menu.visible or results_screen.visible or revive_prompt.visible
	if not owned:
		owned = bool(upgrade_panel.call("is_awaiting_choice"))
	if owned:
		_stuck_timer = 0.0
		return
	_stuck_timer += delta
	if _stuck_timer < STUCK_PAUSE_GRACE:
		return
	_stuck_timer = 0.0
	push_warning("GameScene: paused with no dialog on screen; releasing.")
	_upgrade_open = false
	GameManager.clear_stuck_pause()


## The pause key lives here rather than in GameManager: pausing the tree without
## also opening the menu would leave the player with no way to resume.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("game_pause"):
		return
	if GameManager.state != GameManager.State.PLAYING or RunManager.finished:
		return
	get_viewport().set_input_as_handled()
	_on_pause_pressed()


## Test-only pilot.
##
## It has to engage, not just kite. Every run now opens with a melee weapon that
## cuts along the direction of travel, so a bot that only backs away kills
## nothing, never levels, and makes the soak run a measurement of an empty room.
## So it closes on the nearest enemy while it is healthy and peels off when it is
## not — which is also roughly how the weapon is meant to be played.
func _drive_autopilot(delta: float) -> void:
	_autopilot_time += delta
	# Deliberately below full tilt: a real player repositions rather than
	# sprinting in a straight line forever, and a full-speed bot would simply
	# outrun the swarm and never test close-range builds.
	var drift := Vector2(cos(_autopilot_time * 0.35), sin(_autopilot_time * 0.27)) * 0.45
	var healthy := player.health.current_health / maxf(1.0, player.health.max_health) > 0.45

	var avoid := Vector2.ZERO
	if enemies != null:
		for enemy in enemies.get_in_radius(player.global_position, 240.0, 16):
			var offset := player.global_position - enemy.global_position
			var dist := maxf(40.0, offset.length())
			avoid += offset / dist * (240.0 / dist)
		# Capped so the pilot behaves like a player who accepts some contact
		# rather than a perfect kiter that never lets anything near it.
		avoid = avoid.limit_length(1.1)

	var engage := Vector2.ZERO
	if enemies != null and healthy:
		var target := enemies.get_nearest(player.global_position, 800.0)
		if target != null:
			var to_target := target.global_position - player.global_position
			# Stop short rather than standing inside it: the cut has reach, and
			# walking through a body is how the pilot takes contact damage.
			if to_target.length() > 90.0:
				engage = to_target.normalized()

	# Hazards telegraph before they arm, so a real player walks out of them.
	for node in get_tree().get_nodes_in_group(&"hazards"):
		var hazard := node as Node2D
		if hazard == null or not hazard.visible:
			continue
		var offset := player.global_position - hazard.global_position
		var dist := offset.length()
		if dist < 240.0:
			avoid += offset.normalized() * (240.0 - dist) / 240.0 * 6.0

	var heading := drift + engage * 0.95 + avoid * (0.5 if healthy else 1.3)
	if heading.length_squared() < 0.0025:
		heading = drift
	player.set_move_input(heading.limit_length(1.0))


func _update_camera(delta: float) -> void:
	# A little lead in the direction of travel gives more warning of what is
	# coming without needing a wider view.
	var lead := player.velocity * 0.18
	var target := player.global_position + lead.limit_length(160.0)
	camera.global_position = camera.global_position.lerp(target, clampf(delta * 6.0, 0.0, 1.0))
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 3.0)
		_shake_offset = Vector2(
			RunManager.rng.randf_range(-1.0, 1.0),
			RunManager.rng.randf_range(-1.0, 1.0)) * _shake * 18.0
		camera.offset = _shake_offset
	elif camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO


func shake(amount: float) -> void:
	_shake = maxf(_shake, clampf(amount, 0.0, 1.5))


# --- Level up ---------------------------------------------------------------

func _on_leveled_up(_new_level: int) -> void:
	AudioManager.play_sfx(&"levelup")
	AudioManager.vibrate(40)


func _open_upgrade_panel() -> void:
	if not RunManager.consume_level_up():
		return
	var extra := int(RunManager.relic_special_value(&"extra_choice"))
	var offers := UpgradeSystem.generate(3 + extra)
	if offers.is_empty():
		# Nothing to choose means nothing to tap, which would freeze the run
		# behind an empty panel. Skip the level-up rather than open one.
		push_warning("GameScene: level-up produced no offers; skipping.")
		return
	_upgrade_open = true
	# The stick keeps whatever touch it was holding when the tree paused, and
	# that touch never gets its release. Dropping it here means the next tap
	# starts clean on the panel instead of being swallowed by the joystick.
	hud.call("cancel_touch")
	GameManager.request_pause("levelup")
	upgrade_panel.call("open", offers, RunManager.player_level)


func _on_upgrade_chosen(offer: Dictionary) -> void:
	# Un-pause first. Applying an upgrade runs power behaviour code, and if any
	# of that fails the run must still be playable rather than frozen behind a
	# panel that has already dismissed itself.
	_upgrade_open = false
	GameManager.release_pause("levelup")
	var line := UpgradeSystem.apply(offer)
	hud.call("push_log", line)
	AudioManager.play_sfx(&"ui_confirm")


# --- Boss -------------------------------------------------------------------

func _on_boss_warning(title: String) -> void:
	hud.call("show_boss_warning", title)
	shake(0.6)


func _on_boss_spawned(boss: Boss) -> void:
	hud.call("bind_boss", boss)
	shake(0.8)


func _on_boss_defeated() -> void:
	hud.call("clear_boss")
	shake(1.0)


# --- Death / results --------------------------------------------------------

func _on_player_died() -> void:
	if GameManager.offer_revive():
		revive_prompt.call("open", GameManager.revives_available)
		return
	RunManager.finish()


func _on_revive_accepted() -> void:
	GameManager.consume_revive()
	player.revive()
	shake(0.8)


func _on_revive_declined() -> void:
	GameManager.decline_revive()


func _on_run_finished(results: Dictionary) -> void:
	waves.stop()
	if player != null and is_instance_valid(player):
		player.powers.set_firing(false)
	enemies.set_physics_process(false)
	hazards.enabled = false
	AudioManager.stop_music()
	results_screen.call("show_results", results)
	if _autopilot:
		print("[smoke] survived %s - level %d, %d kills, %d elites, %d bosses, %d damage, threshold=%s" % [
			MathUtil.format_time(float(results.get("time", 0.0))),
			int(results.get("level", 0)), int(results.get("kills", 0)),
			int(results.get("elite_kills", 0)), int(results.get("boss_kills", 0)),
			int(results.get("damage", 0.0)),
			"yes" if bool(results.get("threshold_cleared", false)) else "no"])
		get_tree().quit(0)


# --- UI callbacks -----------------------------------------------------------

func _on_pause_pressed() -> void:
	GameManager.request_pause("menu")
	pause_menu.call("open")


func _on_resume() -> void:
	GameManager.release_pause("menu")


func _on_quit() -> void:
	_teardown()
	GameManager.abandon_run()


func _on_retry() -> void:
	_teardown()
	GameManager.retry_run()


func _on_joystick_moved(dir: Vector2) -> void:
	if player != null and is_instance_valid(player):
		player.set_move_input(dir)


func _teardown() -> void:
	# Pools survive scene changes, so live nodes must be returned explicitly.
	SaveManager.capture_active_run()
	waves.stop()
	enemies.clear_all()
	projectiles.clear_all()
	hazards.clear_all()
	PoolManager.release_group(&"pickups")
	PoolManager.release_group(&"enemy_projectiles")


func _exit_tree() -> void:
	_teardown()
	# The systems clear their own static handles in _exit_tree, but node exit
	# order is not guaranteed, so make sure nothing outlives the run.
	EnemyDirector.instance = null
	ProjectileSystem.instance = null
	EffectSpawner.instance = null
	Player.instance = null
