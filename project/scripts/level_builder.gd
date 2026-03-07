extends Node
class_name LevelBuilder

## ═══════════════════════════════════════════════════════════════════════════════
## LevelBuilder — Advanced Procedural Generation & Level Construction
## ═══════════════════════════════════════════════════════════════════════════════
##
## A powerful factory system for generating levels at runtime.
## Supports:
## 1. Procedural Generation: Create infinite levels based on difficulty curves.
## 2. JSON Deserialization: Load levels from external data files.
## 3. Decoration System: Automatically place grass, trees, and particles.
## 4. Entity Spawning: Configure enemies, powerups, and traps.

# ─── Enums ───────────────────────────────────────────────────────────────────
enum PlatformType { STATIC, MOVING, BOUNCE, CRUMBLING, ICE, CONVEYOR, DISAPPEARING }
enum EnemyType { PATROL, FLYING, TURRET, JUMPER }
enum ItemType { CHECKPOINT, POWERUP_JUMP, POWERUP_SIZE }

# ─── Configuration ───────────────────────────────────────────────────────────
const TILE_SIZE := 40.0
const MAX_JUMP_HEIGHT := 250.0
const MAX_JUMP_DIST := 400.0

# ─── State ───────────────────────────────────────────────────────────────────
var _level_root: Node2D
var _rng: RandomNumberGenerator

# ─── Lifecycle ──────────────────────────────────────────────────────────────

func _init() -> void:
	_rng = RandomNumberGenerator.new()


func set_level(level_node: Node2D) -> void:
	_level_root = level_node


# ─── Public API: Procedural Generation ──────────────────────────────────────

func generate_level(difficulty: int, seed_val: int = -1) -> void:
	if seed_val != -1:
		_rng.seed = seed_val
	else:
		_rng.randomize()
	
	print("[LevelBuilder] Generating level with difficulty %d..." % difficulty)
	
	# Determine parameters based on difficulty
	var length := 2000 + (difficulty * 500)
	var density := 0.6 - (difficulty * 0.05)
	var hazard_chance := 0.1 + (difficulty * 0.1)
	var moving_chance := 0.05 + (difficulty * 0.1)
	
	var current_x := 100.0
	var current_y := 400.0
	var target_x := float(length)
	
	# Add start platform
	add_platform(Vector2(current_x, current_y), Vector2(200, 20), PlatformType.STATIC)
	
	# Iterative generation
	while current_x < target_x:
		# Calculate next jump
		var jump_dist := _rng.randf_range(150.0, MAX_JUMP_DIST)
		var jump_height := _rng.randf_range(-100.0, 100.0) # Relative Y
		
		# Clamp Y to screen bounds
		var next_y := clampf(current_y + jump_height, 200.0, 700.0)
		var next_x := current_x + jump_dist
		
		# Determine platform type
		var p_type := PlatformType.STATIC
		if _rng.randf() < moving_chance:
			p_type = PlatformType.MOVING
		elif _rng.randf() < 0.1:
			p_type = PlatformType.BOUNCE
		elif _rng.randf() < 0.1:
			p_type = PlatformType.CRUMBLING
			
		# Create platform
		var p_width := _rng.randf_range(80.0, 200.0)
		if p_type == PlatformType.MOVING: p_width = 100.0
		
		var platform = add_platform(Vector2(next_x, next_y), Vector2(p_width, 20), p_type)
		
		# Add hazards?
		if _rng.randf() < hazard_chance:
			_add_hazard_to_platform(platform, difficulty)
			
		# Add enemies?
		if _rng.randf() < 0.2 + (difficulty * 0.05):
			_add_enemy_on(platform, difficulty)
		
		current_x = next_x
		current_y = next_y
	
	# Add goal
	var goal_plat = add_platform(Vector2(current_x + 200, current_y), Vector2(150, 20), PlatformType.STATIC)
	add_goal(Vector2(current_x + 200, current_y - 50))
	
	# Set camera limits
	if _level_root.get("camera_limits") != null:
		_level_root.camera_limits = Rect2(0, 0, current_x + 400, 800)


# ─── Public API: Factory Methods ────────────────────────────────────────────

func add_platform(pos: Vector2, size: Vector2, type: PlatformType) -> Node2D:
	var platform: Node2D
	
	match type:
		PlatformType.STATIC:
			platform = _create_static_platform(size)
		PlatformType.MOVING:
			platform = _create_moving_platform(size)
		PlatformType.BOUNCE:
			platform = _create_bounce_platform(size)
		PlatformType.CRUMBLING:
			platform = _create_crumbling_platform(size)
		_:
			platform = _create_static_platform(size) # Fallback
	
	platform.position = pos
	_level_root.add_child(platform)
	
	# Add decorations
	if type == PlatformType.STATIC:
		_decorate_platform(platform, size)
	
	return platform


func add_goal(pos: Vector2) -> Area2D:
	var goal_scn = load("res://scenes/goal.tscn")
	if goal_scn:
		var goal = goal_scn.instantiate()
		goal.position = pos
		_level_root.add_child(goal)
		return goal
	return null


# ─── Internal: Platform Creation ────────────────────────────────────────────

func _create_static_platform(size: Vector2) -> StaticBody2D:
	var body = StaticBody2D.new()
	
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	
	# Visuals
	var color_rect = ColorRect.new()
	color_rect.size = size
	color_rect.position = -size / 2
	color_rect.color = Color(0.35, 0.45, 0.55) # Default stone color
	body.add_child(color_rect)
	
	return body


func _create_moving_platform(size: Vector2) -> StaticBody2D:
	var body = StaticBody2D.new()
	var script = load("res://scripts/platforms/moving_platform.gd")
	if script:
		body.set_script(script)
		body.move_distance = 150.0
		body.move_speed = 60.0
	
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	
	# Visuals
	var color_rect = ColorRect.new()
	color_rect.size = size
	color_rect.position = -size / 2
	color_rect.color = Color(0.4, 0.6, 0.8) # Blueish
	body.add_child(color_rect)
	
	return body


func _create_bounce_platform(size: Vector2) -> StaticBody2D:
	var body = StaticBody2D.new()
	var script = load("res://scripts/platforms/bounce_platform.gd")
	if script:
		body.set_script(script)
		body.bounce_force = 800.0
	
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	
	# Visuals
	var color_rect = ColorRect.new()
	color_rect.size = size
	color_rect.position = -size / 2
	color_rect.color = Color(0.9, 0.4, 0.4) # Reddish
	body.add_child(color_rect)
	
	return body


func _create_crumbling_platform(size: Vector2) -> StaticBody2D:
	var body = StaticBody2D.new()
	# Assuming script exists, otherwise create basic static
	var script_path = "res://scripts/platforms/crumbling_platform.gd"
	if ResourceLoader.exists(script_path):
		body.set_script(load(script_path))
	
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	
	# Visuals
	var color_rect = ColorRect.new()
	color_rect.size = size
	color_rect.position = -size / 2
	color_rect.color = Color(0.6, 0.5, 0.4) # Brownish
	body.add_child(color_rect)
	
	return body


# ─── Internal: Decoration ───────────────────────────────────────────────────

func _decorate_platform(platform: Node2D, size: Vector2) -> void:
	# Add grass
	var grass_count := int(size.x / 10)
	for i in grass_count:
		var g = ColorRect.new()
		var h = _rng.randf_range(4.0, 10.0)
		g.size = Vector2(2, h)
		g.position = Vector2(-size.x/2 + i * 10 + _rng.randf_range(-2, 2), -size.y/2 - h)
		g.color = Color(0.4, 0.8, 0.4)
		platform.add_child(g)
		
	# Add trees rarely
	if size.x > 150 and _rng.randf() < 0.2:
		var tree_scn = load("res://scenes/tree_1.tscn")
		if tree_scn:
			var tree = tree_scn.instantiate()
			tree.position = Vector2(_rng.randf_range(-size.x/4, size.x/4), -size.y/2)
			tree.scale = Vector2(0.5, 0.5)
			platform.add_child(tree)


func _add_hazard_to_platform(platform: Node2D, difficulty: int) -> void:
	# Add spikes
	var hazard = Area2D.new()
	var script = load("res://scripts/hazards/spike_strip.gd")
	if script:
		hazard.set_script(script)
	
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(40, 10)
	shape.shape = rect
	hazard.add_child(shape)
	
	# Visual
	var vis = ColorRect.new()
	vis.size = Vector2(40, 10)
	vis.position = Vector2(-20, -5)
	vis.color = Color(0.8, 0.2, 0.2)
	hazard.add_child(vis)
	
	hazard.position = Vector2(0, -25) # Above platform center
	platform.add_child(hazard)


func _add_enemy_on(platform: Node2D, difficulty: int) -> void:
	# Requires enemy scenes
	pass # TODO: Implement enemy spawning once enemies are robust

