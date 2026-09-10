extends Node
## Generic scene pool.
##
## Bullet-hell spawn rates make allocation the biggest single source of frame
## spikes on mid-range phones, so enemies, projectiles, shards, damage numbers
## and effects are all recycled here.
##
## Design note: pooled nodes are created once under a fixed parent and never
## reparented. Adding or removing a CollisionObject2D during a physics callback
## is illegal in Godot, and projectiles are released from inside area_entered,
## so recycling toggles visibility and processing instead of touching the tree.
## Monitoring flags are changed with set_deferred() for the same reason.
##
## Pooled scenes may implement:
##   func pool_reset() -> void   # called just before the node is handed out
##   func pool_sleep() -> void   # called when the node is returned

const MAX_PER_POOL := 600
## Nodes created per pool per idle frame while topping up.
const REFILL_PER_FRAME := 24

## key -> {"parent": Node, "scene": PackedScene, "free": Array[Node],
##         "active": int, "min_free": int}
var _pools: Dictionary = {}
var _warned: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Instantiating a scene with collision shapes is illegal inside a physics
## callback, and enemies die (spawning shards) from exactly there. So the pools
## are topped up here, during the idle frame, and acquire() almost never has to
## allocate.
func _process(_delta: float) -> void:
	for key in _pools:
		var pool: Dictionary = _pools[key]
		var free_list: Array = pool["free"]
		var target: int = int(pool.get("min_free", 0))
		var made := 0
		while free_list.size() < target and made < REFILL_PER_FRAME:
			var node := _create(key)
			if node == null:
				break
			_sleep_node(key, node)
			made += 1


## Autoloads outlive the scene tree, so the pool tables are dropped explicitly
## on shutdown rather than left holding references to nodes being torn down.
func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_pools.clear()
		_warned.clear()


func _key(scene: PackedScene) -> String:
	return scene.resource_path


## Binds a scene to the node its instances will live under, and pre-creates
## `prewarm` sleeping copies. Re-registering with a new parent (a new run)
## replaces the old pool.
func register(scene: PackedScene, parent: Node, prewarm: int = 0) -> void:
	if scene == null or parent == null:
		return
	var key := _key(scene)
	var pool: Dictionary = _pools.get(key, {})
	if pool.get("parent") == parent:
		return
	_pools[key] = {
		"parent": parent,
		"scene": scene,
		"free": [],
		"active": 0,
		"min_free": maxi(16, prewarm * 3 / 4),
	}
	var on_exit := _on_parent_exiting.bind(parent)
	if not parent.tree_exiting.is_connected(on_exit):
		parent.tree_exiting.connect(on_exit)
	for i in prewarm:
		var node := _create(key)
		if node == null:
			return
		_sleep_node(key, node)


func _create(key: String) -> Node:
	var pool: Dictionary = _pools.get(key, {})
	var scene: PackedScene = pool.get("scene")
	var parent: Node = pool.get("parent")
	if scene == null or parent == null or not is_instance_valid(parent):
		return null
	var node := scene.instantiate()
	node.set_meta("pool_key", key)
	node.set_meta("pooled_asleep", false)
	parent.add_child(node)
	return node


## Hands out a ready node, creating one if the pool is dry. Callers configure the
## node after this returns.
func acquire(scene: PackedScene) -> Node:
	if scene == null:
		return null
	var key := _key(scene)
	if not _pools.has(key):
		push_error("PoolManager: %s was never registered." % key)
		return null
	var pool: Dictionary = _pools[key]
	var free_list: Array = pool["free"]
	var node: Node = null
	while node == null and free_list.size() > 0:
		node = free_list.pop_back()
		if not is_instance_valid(node):
			node = null
	if node == null:
		if Engine.is_in_physics_frame():
			# Growing the pool here would touch the physics server mid-query.
			# The idle-frame top-up makes this rare; skipping one spawn is a far
			# better outcome than a broken physics state.
			_warn_once(key)
			return null
		node = _create(key)
		if node == null:
			return null
	pool["active"] = int(pool["active"]) + 1
	_wake_node(node)
	if node.has_method("pool_reset"):
		node.call("pool_reset")
	return node


## Returns a node to its pool. Safe to call more than once.
func release(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if not node.has_meta("pool_key"):
		node.queue_free()
		return
	if bool(node.get_meta("pooled_asleep", false)):
		return
	var key := String(node.get_meta("pool_key"))
	if not _pools.has(key):
		# The pool's parent has already left the tree (the run ended).
		return
	var pool: Dictionary = _pools[key]
	pool["active"] = maxi(0, int(pool["active"]) - 1)
	if node.has_method("pool_sleep"):
		node.call("pool_sleep")
	var free_list: Array = pool["free"]
	if free_list.size() >= MAX_PER_POOL:
		node.queue_free()
		return
	_sleep_node(key, node)


func _warn_once(key: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning("PoolManager: %s ran dry during a physics frame; raise its prewarm." % key)


func _wake_node(node: Node) -> void:
	node.set_meta("pooled_asleep", false)
	node.set_process(true)
	node.set_physics_process(true)
	if node is CanvasItem:
		(node as CanvasItem).visible = true


func _sleep_node(key: String, node: Node) -> void:
	node.set_meta("pooled_asleep", true)
	node.set_process(false)
	node.set_physics_process(false)
	if node is CanvasItem:
		(node as CanvasItem).visible = false
	# Park it far from play so a stale overlap cannot resolve before the
	# deferred monitoring flags land.
	if node is Node2D:
		(node as Node2D).global_position = Vector2(-1.0e6, -1.0e6)
	if not _pools.has(key):
		return
	((_pools[key] as Dictionary)["free"] as Array).append(node)


func _on_parent_exiting(parent: Node) -> void:
	# The sleeping nodes are children of `parent`, so they die with it.
	for key in _pools.keys():
		var pool: Dictionary = _pools[key]
		if pool.get("parent") == parent:
			_pools.erase(key)


func active_count(scene: PackedScene) -> int:
	if scene == null:
		return 0
	var key := _key(scene)
	if not _pools.has(key):
		return 0
	return int((_pools[key] as Dictionary)["active"])


func total_active() -> int:
	var sum := 0
	for key in _pools:
		sum += int((_pools[key] as Dictionary)["active"])
	return sum


## Releases every live node in a group - used when a run ends.
func release_group(group: StringName) -> void:
	for node in get_tree().get_nodes_in_group(group):
		release(node)


func clear_all() -> void:
	for key in _pools.keys():
		var pool: Dictionary = _pools[key]
		for node in (pool["free"] as Array):
			if is_instance_valid(node):
				node.queue_free()
		pool["free"] = []
		pool["active"] = 0
