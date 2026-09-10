# Last Light: Swarmfall

A portrait-mode mobile roguelite survival shooter built in **Godot 4.x** with **GDScript**.
You hold one thumb on the screen and move; everything else — aiming, firing, target
selection — happens on its own. Runs are **endless**: there is no timer to beat and no
victory screen. The swarm gets denser and harder for as long as you stay alive, and the
only question is how long that is.

Between level-ups you build a loadout out of **twelve upgrades** — seven Powers and five
Passive Abilities — but you may only ever own **six of them**. Nothing can be swapped
out, so every pick is a commitment.

Everything in the project is original. There are no imported textures, fonts, or audio
files: all visuals are drawn procedurally with Godot's 2D draw calls, and every sound
effect and music loop is synthesised into a buffer at boot (`AudioManager`).

---

## Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Running the game](#running-the-game)
- [Controls](#controls)
- [Project structure](#project-structure)
- [How the game is put together](#how-the-game-is-put-together)
- [Content and how to change it](#content-and-how-to-change-it)
- [Save data](#save-data)
- [Development tooling](#development-tooling)
  - [Balance snapshot](#balance-snapshot)
- [Performance notes](#performance-notes)
- [Android export](#android-export)
- [iOS export](#ios-export)
- [Known gaps](#known-gaps)

---

## Requirements

- **Godot 4.x**, standard build (not .NET/Mono — the project is pure GDScript).
  Developed and tested against **4.7.2-stable**.
- For Android: the Android SDK, JDK 17, and a debug keystore (see
  [Android export](#android-export)).
- For iOS: macOS with Xcode.

No add-ons, plugins, or asset-library downloads are needed.

## Installation

1. Clone or copy this folder.
2. Open Godot, choose **Import**, and select `project.godot`.
3. Let the initial import finish. The first open regenerates `.godot/`, which is not
   committed.
4. Press **F5** (or the play button) to run. The main scene is
   `scenes/game/Boot.tscn`.

The window opens at 432×768 for convenience on desktop; the game itself is authored
against a **1080×1920** portrait viewport and scales to any aspect ratio via
`canvas_items` stretch with `expand`, so wide or tall phones both work without
letterboxing.

## Running the game

- **F5** runs from `Boot`, which loads the content database and drops you at the main
  menu.
- On a first run you land on Neon Ruins with Nova, and a three-page tutorial overlay
  appears once.
- On desktop, **WASD / arrow keys** also move the player, **Space** fires the
  ultimate, and **Escape** pauses — handy for testing without a touchscreen.

## Controls

| Input | Action |
| --- | --- |
| Drag anywhere on the lower ~60% of the screen | Move. The stick appears under your thumb ("dynamic" mode) |
| `ULT` button (bottom right) | Fire the hero ultimate once its ring is full |
| `II` button (top right) | Pause |
| WASD / arrows *(desktop)* | Move |
| Space *(desktop)* | Ultimate |
| Escape *(desktop)* | Pause |

Everything is reachable with one thumb. In **Settings** the stick can be switched to
the right side, or pinned to a fixed position instead of following your thumb.

There is no attack button by design: weapons fire on their own cooldowns and pick
their own targets, so the only decision you make moment to moment is where to stand.

## Project structure

```
scenes/
  menus/     MainMenu, HeroSelect, LevelSelect, MetaLab, Settings
  game/      Boot, GameScene (the run itself)
  player/    Player.tscn
  enemies/   Enemy.tscn, Boss.tscn
  combat/    Projectile.tscn, DamageZone.tscn, EnemyProjectile.tscn
  powers/    Companion, SawBlade, DrillBody, ThrownBottle, LaserStrike
  ui/        HUD, UpgradePanel, PauseMenu, Results, RevivePrompt, Tutorial
  levels/    Hazard.tscn
  fx/        DamageNumber, HitSpark, Burst
  pickups/   XPShard, Pickup
scripts/
  autoload/  DevTools, SaveManager, ContentDB, AudioManager, PoolManager,
             RunManager, GameManager
  systems/   EnemyDirector, WaveDirector, ProjectileSystem, EffectSpawner,
             HazardSystem, UpgradeSystem, HeroPassives, PowerLoadout,
             TipBook, PerfMonitor
  components/ HealthComponent, PlayerStats
  data/      HeroData, PowerData, UpgradeData, EnemyData, WaveData, LevelData,
             RelicData      (the Resource types content is authored in)
  player/    Player, PlayerVisual, UltimateController
  enemies/   Enemy, Boss
  powers/    PowerManager, PowerBase
             behaviors/  one script per power
             entities/   the things those behaviours spawn
  combat/    Projectile, DamageZone, EnemyProjectile
  levels/    BackgroundRenderer, Hazard
  ui/        UITheme, MenuScreen, OverlayPanel, IconRect, VirtualJoystick,
             PowerArt, PowerCardArt, PowerSlot, + screens
  fx/        DamageNumber, HitSpark, Burst
  pickups/   XPShard, Pickup
  util/      Layers, Palette, MathUtil, Draw2D
resources/
  heroes/ powers/ upgrades/ enemies/ levels/ relics/     (generated .tres)
assets/
  icons/     icon.svg
data/        (reserved for shipped JSON; the save file lives in user://)
tools/       content generator, soak harness
```

### Autoloads

Loaded in this order (order matters — later ones read earlier ones):

| Autoload | Responsibility |
| --- | --- |
| `DevTools` | Command-line flags for automated testing. Inert in a normal launch. |
| `SaveManager` | JSON persistence of unlocks, meta upgrades, relics and settings |
| `ContentDB` | Loads every `.tres` under `resources/` once and indexes it by id |
| `AudioManager` | Synthesises all SFX/music at boot; owns the Music and SFX buses |
| `PoolManager` | Generic scene pool for enemies, projectiles, shards and effects |
| `RunManager` | One run's seeded RNG, clock, XP, difficulty scaling and rewards |
| `GameManager` | Game states, scene routing, pause reference-counting, revives |

`ContentDB` is the one autoload beyond the five originally specified. It exists so
that adding content is purely additive: drop a new `.tres` into `resources/` and it is
picked up, with nothing to register by hand.

## How the game is put together

**The run.** `GameScene` is a wiring hub and nothing more. It spawns the player, hands
`LevelData` to each system, and routes signals between the simulation and the UI. The
behaviour lives in the systems it owns, so any one of them can be read or replaced on
its own.

**Enemies.** `EnemyDirector` owns every live enemy. Enemies deliberately do *not* run
their own `_physics_process`; the director steps them in a single loop, maintains a
spatial hash over their positions, and uses it for crowd separation and for the
"nearest enemy" queries that homing weapons and the auto-aim depend on. Enemies are
`monitorable` but not `monitoring` — projectiles and the player's hurtbox look for
enemies, never the other way around.

**Powers.** A power is a `PowerData` resource plus one behaviour script from
`scripts/powers/behaviors/`. `PowerBase` owns cooldowns, stat scaling, crit rolls and
the per-level curves, so a behaviour only implements what makes it different —
`_on_setup()`, `_on_level_changed()`, and an optional `_on_reached_max_level()` hook for
powers whose top level changes their rules (the Drone starts aiming; the Spinners stop
retracting). Passive Abilities share the same resource type with no behaviour at all:
they are pure `stat_flats` / `stat_multipliers` bundles applied to `PlayerStats`.

**The six-slot rule.** `PowerLoadout` holds what has been picked and enforces the cap.
Once six entries are owned, `can_offer()` rejects anything new, so a level-up can only
deepen what you already have. There is no swap path by design.

**Projectiles and zones.** Every moving hitbox in the game is one pooled
`Projectile.tscn` (linear, homing, orbiting, bouncing, returning, spiralling — plus
explode/chain/slow/freeze on hit), and every area-of-effect is one pooled
`DamageZone.tscn` (aura, field, flame, thorns, rift, beacon, shock). Keeping the scene
count low is what keeps the pool warm.

**Damage.** Everything routes through `Enemy.apply_hit(...)`, which applies a
per-source hit interval measured in **game time** (`RunManager.elapsed`), not
wall-clock — persistent weapons like auras and orbiting drones depend on that, and
wall-clock time would keep ticking while the game is paused.

**Upgrades.** `UpgradeSystem` builds the level-up offers as plain dictionaries, so the
panel never branches on resource types. It asks `PowerLoadout.can_offer()` for every
candidate, which is the single place the six-slot cap is enforced.

**Difficulty.** There is no wave script to run out of. `RunManager` scales enemy health
and damage from the elapsed clock, and past the end of a level's authored waves the
`WaveDirector` keeps drawing from that sector's pool with rising density. Bosses recur
on an interval rather than appearing once.

## Content and how to change it

All content is authored in readable GDScript under `tools/gen/` and compiled into
`.tres` resources by a build step. Editing numbers there and re-running keeps balance
changes reviewable in a diff instead of buried in resource files:

```bash
godot --headless --path . --script res://tools/generate_content.gd
```

| File | Content |
| --- | --- |
| `tools/gen/GenHeroes.gd` | The five operatives, their stats, passives and ultimates |
| `tools/gen/GenPowers.gd` | Seven Powers and five Passive Abilities, with level curves |
| `tools/gen/GenUpgrades.gd` | Eight Research Lab (meta) upgrades |
| `tools/gen/GenEnemies.gd` | 28 enemy archetypes (five per sector, plus mid-boss and boss) |
| `tools/gen/GenLevels.gd` | Four sectors: palette, hazards, wave script, boss timings |
| `tools/gen/GenRelics.gd` | Eight relics |

You can also edit the generated `.tres` files directly in the Godot inspector; just be
aware that re-running the generator overwrites them.

### Heroes

| Hero | Role | Passive | Ultimate |
| --- | --- | --- | --- |
| **Nova** | Plasma engineer | Overclock — faster weapon cycles, wider effects | **Drone Halo** — five plasma drones orbit and shred |
| **Bramble** | Bio-guardian | Deep Roots — continuous regeneration, deeper pool | **Thorn Maze** — a lattice of thorn patches that cut and slow |
| **Rift** | Dimensional scout | Phase Step — faster, shrugs off a slice of damage | **Rift Walk** — blinks into the crowd leaving damaging tears |
| **Aegis** | Shield soldier | Bulwark Plating — heavy armour, slower | **Bulwark** — invulnerable, reflects every hit back |
| **Ember** | Firecaster | Kindling — much larger areas, harder crits | **Firewall** — a growing wall of flame rolls outward |

### Powers

Every power runs to level 5. The last level is always a rule change rather than another
number, so maxing something feels different rather than just bigger.

| Power | What it does | At max level |
| --- | --- | --- |
| **Drone** | A gun drone orbits you and sprays bullets outward in a ring | Bullets stop spraying and track enemies |
| **Domain** | A force field grinds down everything standing inside it | Each level widens the field and hits harder |
| **Molotov Cocktail** | Lobs bottles that leave patches of burning ground | 2 bottles → 6 |
| **Drill** | Drills ricochet around the screen, boring through the swarm | 2 drills → 5, each hitting harder |
| **Healing Drone** | Drops healing circles near you; stand in one to regenerate | Wider circles, dropped more often |
| **Laser** | Orbital strikes rake the ground around you in rotating patterns | 3 beams → 5, far heavier damage |
| **Spinners** | Saw blades orbit you, cutting in bursts and retracting between them | 2 blades → 6, and they never stop spinning |

### Passive Abilities

No behaviour of their own — they bend the numbers every power reads.

| Passive | Effect |
| --- | --- |
| **Overclock Core** | Shorter cooldowns, faster projectiles |
| **Alloy Plating** | More maximum health and armour |
| **Kinetic Boots** | Faster movement, flat damage reduction |
| **Resonance Lens** | More damage, larger areas, higher crit chance |
| **Salvage Magnet** | Wider pickup radius, more experience |

### Sectors

| Sector | Unlocks next at | Hazard | Boss |
| --- | --- | --- | --- |
| **Neon Ruins** | survive 7:00 | Electric floor | Sentinel Warden (robot) |
| **Ash Wastes** | survive 8:00 | Fire vents | Ashbrand (armoured beast) |
| **Flooded Vault** | survive 9:00 | Slowing water | Mutated Sentinel |
| **Moonfall Ridge** | — | Gravity anomalies | Celestial Parasite |

A sector is never "cleared" — surviving to its `unlock_time` unlocks the next one, and
the run then carries on for as long as you last. Waves overlap on purpose: every entry
in a level's script is live between its `start_time` and `end_time`, so late in a run
three or four scripts feed the field at once, and past the last entry the director
keeps drawing from the pool at steadily rising density.

## Save data

One JSON file, written to Godot's per-user data directory:

- Windows: `%APPDATA%\Godot\app_userdata\Last Light- Swarmfall\lastlight_save.json`
- Linux: `~/.local/share/godot/app_userdata/Last Light- Swarmfall/`
- Android: the app's private data directory

It holds credits, research samples, unlocked heroes/sectors/relics, equipped relics,
permanent upgrade levels, best survival times and all settings. Writes are debounced and
the previous file is kept as `lastlight_save.bak.json`; unknown or missing keys fall back
to defaults, so older saves keep working when fields are added.

**Resuming a run.** Because a run has no end, closing the app mid-run must not throw it
away. `SaveManager` snapshots the live run into an `active_run` block — clock, XP and
level, the power loadout and its levels, the hero and sector — periodically during play
and again on `NOTIFICATION_WM_CLOSE_REQUEST`, `NOTIFICATION_APPLICATION_PAUSED` (the
Android case) and `NOTIFICATION_WM_GO_BACK_REQUEST`. The main menu offers **Resume** when
that block is present, and clears it when the run finally ends.

**Settings → Erase all progress** resets it.

## Development tooling

Flags go after a bare `--` so Godot passes them through to the game
(`DevTools.gd` reads them; a normal launch is unaffected):

```bash
# Automated soak run: an autopilot plays, picks upgrades and prints a summary
godot --headless --path . --fixed-fps 60 --quit-after 60000 -- --smoke

# Same, but pick the hero, sector and RNG seed
godot --headless --path . --fixed-fps 60 --quit-after 60000 -- \
	  --smoke --hero=ember --level=flooded_vault --seed=1234

# Log frame time, live enemies, pooled objects and draw calls every 5 seconds
godot --path . -- --perf

# Boot straight into a screen: menu, hero, level, lab, settings, game
godot --path . -- --screen=lab

# Save PNG screenshots of the running game into user://
godot --path . -- --shot --screen=game --no-tutorial

# Autopilot movement but leave the choices to a human (useful for inspecting UI)
godot --path . -- --pilot
```

`tools/soak.ps1` sweeps combinations and reports a win rate — use it to judge balance
changes, because a single run is dominated by RNG:

```powershell
pwsh tools/soak.ps1 -Heroes all -Levels all -Seeds 3
```

Drop a Godot binary in `tools/` or pass `-Godot <path>`.

### Balance snapshot

Measured with the automated pilot on a fresh profile (no Research Lab investment,
no relics), three seeds per sector:

| Sector | Fresh account | With `--meta=4` |
| --- | --- | --- |
| Neon Ruins | 3/3 clear | — |
| Ash Wastes | 3/3 clear | — |
| Flooded Vault | 2/2 clear | — |
| Moonfall Ridge | 0/3 — reaches ~10:50 of 13:00 | 2/2 clear |

All five heroes clear Neon Ruins on a fresh profile with comparable results
(level 27–32, 4 600–6 400 kills), so no starting weapon is a trap.

Moonfall Ridge is deliberately the wall: a no-investment run gets roughly 85% of the
way, and a few levels of lab research closes the gap. That is the progression gate
working, not a difficulty bug.

## Performance notes

The target is a steady 60 fps on a mid-range phone with 150–250 enemies alive.

- **Pooling.** Enemies, projectiles, damage zones, XP shards, pickups, damage numbers,
  sparks and bursts are all recycled. Pooled nodes are created once under a fixed
  parent and are *never reparented*: adding or removing a `CollisionObject2D` during a
  physics callback is illegal in Godot, and projectiles are released from inside
  `area_entered`. Recycling toggles visibility and processing instead, and monitoring
  flags are changed with `set_deferred`. Pools top themselves up during the idle frame
  so `acquire()` almost never has to allocate.
- **One update loop for the swarm.** Enemies have no per-node `_physics_process`.
- **Cheap neighbour queries.** A spatial hash rebuilt once per physics frame backs
  separation, target selection and every radius query, so cost does not grow with the
  total swarm size.
- **Separation is frame-skipped** (every 2–4 frames depending on quality) with a
  matching strength boost — visually identical, a fraction of the cost.
- **No particle nodes.** Hits, deaths and explosions are `_draw` calls with a hard cap
  on how many can be live at once; at low quality small non-crit damage numbers are
  skipped entirely.
- **Quality setting** (Settings screen) scales the enemy budget, the effect budget and
  the separation frame-skip, and caps the frame rate on low/medium.
- **Renderer** is `gl_compatibility` (OpenGL ES 3.0), which is the right default for
  the low end.

Frame timings are only meaningful in a real windowed/device run — under
`--headless --fixed-fps` the reported frame time is the fixed step, not real work. On
device, `adb logcat -s godot` shows the `--perf` lines.

## Android export

1. **Install the prerequisites**: Android SDK (platform 34 + build tools), JDK 17.
2. In Godot: **Editor → Editor Settings → Export → Android** — set the Android SDK
   path and the JDK path.
3. Generate a debug keystore if you do not have one:

   ```bash
   keytool -keyalg RSA -genkeypair -alias androiddebugkey \
	 -keypass android -keystore debug.keystore -storepass android \
	 -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
   ```

   Point **Editor Settings → Export → Android → Debug Keystore** at it.
4. **Project → Install Android Build Template…** — only needed if you want a Gradle
   build (custom plugins, extra permissions). The stock template is otherwise fine.
5. **Project → Export…**. Copy `export_presets.template.cfg` to `export_presets.cfg`
   first if you want the settings below pre-filled, then **Add… → Android**.

   The settings that matter:

   | Setting | Value |
   | --- | --- |
   | Architectures | `arm64-v8a` (add `armeabi-v7a` only for very old devices) |
   | Package → Unique Name | your own reverse-DNS id, e.g. `com.yourstudio.swarmfall` |
   | Screen → Immersive Mode | on |
   | Permissions | Vibrate only — the game needs no network access |
   | Export format | APK for testing, AAB for the Play Store |

6. **Export Project** (or **Remote Debug → Deploy to device** with USB debugging on).

Orientation is already locked to portrait by
`display/window/handheld/orientation=1` in `project.godot`, and
`config/quit_on_go_back=false` means the Android back button does not close the app.

Excluding `tools/*` from the export (the template does this) keeps the content
generator and soak harness out of the shipped package.

## iOS export

1. macOS with Xcode and a valid signing identity.
2. In Godot: **Project → Export… → Add… → iOS**.
3. Set **Bundle Identifier**, **App Store Team ID** and **Signature**.
4. Under Orientation leave only **Portrait** ticked.
5. **Export Project** produces an Xcode project; build, sign and run it from Xcode.

## Known gaps

Things a shipping build would still want, listed honestly:

- **Not tested on real hardware.** All verification here was headless plus windowed
  desktop runs. The frame-rate targets above are design budgets, not measurements from
  a phone.
- **No localisation.** All strings are inline English.
- **Audio is functional, not final.** The synthesised loops do their job but are a
  placeholder for composed music.
- **Balance is tuned against an automated pilot**, which kites better than a new
  player and worse than an expert. See the [balance snapshot](#balance-snapshot) for
  what that actually measures.
- **No analytics, ads, IAP, or cloud save** — the meta economy is entirely local.
