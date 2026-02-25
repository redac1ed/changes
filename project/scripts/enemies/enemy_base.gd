extends CharacterBody2D
class_name EnemyBase

## ═══════════════════════════════════════════════════════════════════════════════
## EnemyBase — Foundation class for all enemy types
## ═══════════════════════════════════════════════════════════════════════════════
##
## Provides patrol, detection, states, damage dealing, and visual rendering.
## Subclasses override specific behaviors via virtual methods.
## Ball kills enemies by bouncing on them (from above).

# ─── Signals ─────────────────────────────────────────────────────────────────
signal enemy_killed(enemy: EnemyBase, points: int)
signal enemy_hit_ball(ball: RigidBody2D)

# ─── Enums ───────────────────────────────────────────────────────────────────
enum EnemyState { IDLE, PATROL, CHASE, ATTACK, STUNNED, DYING, DEAD }
enum EnemyType { WALKER, FLYER, BOUNCER, TURRET, CHARGER }
enum FacingDirection { LEFT, RIGHT }

# ─── Exports ─────────────────────────────────────────────────────────────────
@export_category("Enemy Properties")
@export var enemy_type: EnemyType = EnemyType.WALKER
@export var health: int = 1
@export var max_health: int = 1
@export var damage: int = 1
@export var points_value: int = 100
@export var is_invincible: bool = false

@export_category("Movement")
@export var move_speed: float = 60.0
@export var gravity_force: float = 500.0
@export var patrol_distance: float = 120.0
@export var detection_range: float = 200.0
@export var chase_speed: float = 100.0

@export_category("Visuals")
@export var body_size: Vector2 = Vector2(24, 24)
@export var body_color: Color = Color(0.85, 0.25, 0.2)
@export var eye_color: Color = Color(1.0, 1.0, 1.0)
@export var outline_color: Color = Color(0.15, 0.05, 0.05)
@export var stun_color: Color = Color(1.0, 1.0, 0.5)

# ─── Internal ────────────────────────────────────────────────────────────────
var state: EnemyState = EnemyState.PATROL
var facing: FacingDirection = FacingDirection.RIGHT
var _time_elapsed: float = 0.0
var _patrol_origin: Vector2
var _patrol_timer: float = 0.0
var _stun_timer: float = 0.0
var _death_timer: float = 0.0
var _flash_timer: float = 0.0
var _target_ball: RigidBody2D = null
var _collision_shape: CollisionShape2D
var _detection_area: Area2D
var _hitbox_area: Area2D
var _squash_scale: Vector2 = Vector2.ONE
var _anim_frame: float = 0.0
var _death_particles: Array[Dictionary] = []


func _ready() -> void:
	_patrol_origin = global_position
	
	# Collision shape
	_collision_shape = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = body_size
	_collision_shape.shape = shape
	add_child(_collision_shape)
	
	# Configure CharacterBody2D
	motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	floor_snap_length = 8.0
	
	# Detection area
	_detection_area = Area2D.new()
	var det_shape := CollisionShape2D.new()
	var det_circle := CircleShape2D.new()
	det_circle.radius = detection_range
	det_shape.shape = det_circle
	_detection_area.add_child(det_shape)
	_detection_area.collision_layer = 0
	_detection_area.collision_mask = 1
	_detection_area.body_entered.connect(_on_detection_entered)
	_detection_area.body_exited.connect(_on_detection_exited)
	add_child(_detection_area)
	
	# Hitbox (for damaging the ball)
	_hitbox_area = Area2D.new()
	var hit_shape := CollisionShape2D.new()
	var hit_rect := RectangleShape2D.new()
	hit_rect.size = body_size * 0.9
	hit_shape.shape = hit_rect
	_hitbox_area.add_child(hit_shape)
	_hitbox_area.collision_layer = 0
	_hitbox_area.collision_mask = 1
	_hitbox_area.body_entered.connect(_on_hitbox_entered)
	add_child(_hitbox_area)
	
	# Set collision layers
	collision_layer = 4  # Enemy layer
	collision_mask = 1 | 2  # World + Player
	
	_on_enemy_ready()


func _on_enemy_ready() -> void:
	# Virtual — subclasses override for additional setup
	pass


func _physics_process(delta: float) -> void:
	_time_elapsed += delta
	_anim_frame += delta * 4.0
	
	# Apply gravity for grounded enemies
	if enemy_type != EnemyType.FLYER:
		if not is_on_floor():
			velocity.y += gravity_force * delta
	
	# Flash timer
	if _flash_timer > 0:
		_flash_timer -= delta
	
	# Squash/stretch interpolation
	_squash_scale = _squash_scale.lerp(Vector2.ONE, delta * 8.0)
	
	# State machine
	match state:
		EnemyState.IDLE:
			_process_idle(delta)
		EnemyState.PATROL:
			_process_patrol(delta)
		EnemyState.CHASE:
			_process_chase(delta)
		EnemyState.ATTACK:
			_process_attack(delta)
		EnemyState.STUNNED:
			_process_stunned(delta)
		EnemyState.DYING:
			_process_dying(delta)
		EnemyState.DEAD:
			return
	
	if state != EnemyState.DYING and state != EnemyState.DEAD:
		move_and_slide()
	
	# Update death particles
	var i := _death_particles.size() - 1
	while i >= 0:
		_death_particles[i]["time"] += delta
		_death_particles[i]["x"] += _death_particles[i]["vx"] * delta
		_death_particles[i]["y"] += _death_particles[i]["vy"] * delta
		_death_particles[i]["vy"] += 200.0 * delta
		if _death_particles[i]["time"] > 1.0:
			_death_particles.remove_at(i)
		i -= 1
	
	queue_redraw()


# ─── State Processors ───────────────────────────────────────────────────────

func _process_idle(delta: float) -> void:
	velocity.x = 0
	_patrol_timer += delta
	if _patrol_timer > 2.0:
		state = EnemyState.PATROL
		_patrol_timer = 0.0


func _process_patrol(delta: float) -> void:
	var dir := 1.0 if facing == FacingDirection.RIGHT else -1.0
	velocity.x = dir * move_speed
	
	# Check patrol boundaries
	var dist_from_origin := global_position.x - _patrol_origin.x
	if abs(dist_from_origin) >= patrol_distance:
		_flip_direction()
	
	# Check for wall/edge
	if is_on_wall():
		_flip_direction()
	
	_check_edge_ahead(delta)


func _process_chase(delta: float) -> void:
	if not _target_ball or not is_instance_valid(_target_ball):
		state = EnemyState.PATROL
		return
	
	var dir_to_ball: float = sign(_target_ball.global_position.x - global_position.x)
	facing = FacingDirection.RIGHT if dir_to_ball > 0 else FacingDirection.LEFT
	velocity.x = dir_to_ball * chase_speed
	
	# Distance check
	var dist := global_position.distance_to(_target_ball.global_position)
	if dist > detection_range * 1.5:
		state = EnemyState.PATROL
		_target_ball = null


func _process_attack(_delta: float) -> void:
	# Virtual — subclasses override
	velocity.x = 0


func _process_stunned(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 200 * delta)
	_stun_timer -= delta
	if _stun_timer <= 0:
		state = EnemyState.PATROL


func _process_dying(delta: float) -> void:
	_death_timer += delta
	if _death_timer > 0.8:
		state = EnemyState.DEAD
		queue_free()


func _check_edge_ahead(_delta: float) -> void:
	# Raycast to check for floor ahead
	if enemy_type == EnemyType.FLYER:
		return
	
	var dir := 1.0 if facing == FacingDirection.RIGHT else -1.0
	var ray_origin := global_position + Vector2(dir * body_size.x * 0.6, 0)
	var ray_end := ray_origin + Vector2(0, body_size.y + 10)
	
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(ray_origin, ray_end, 1)
	var result := space.intersect_ray(query)
	
	if result.is_empty():
		_flip_direction()


func _flip_direction() -> void:
	facing = FacingDirection.LEFT if facing == FacingDirection.RIGHT else FacingDirection.RIGHT
	_patrol_timer = 0.0


# ─── Detection Callbacks ────────────────────────────────────────────────────

func _on_detection_entered(body: Node2D) -> void:
	if body is RigidBody2D:
		_target_ball = body
		if state == EnemyState.PATROL or state == EnemyState.IDLE:
			state = EnemyState.CHASE


func _on_detection_exited(body: Node2D) -> void:
	if body == _target_ball:
		_target_ball = null
		if state == EnemyState.CHASE:
			state = EnemyState.PATROL


func _on_hitbox_entered(body: Node2D) -> void:
	if body is RigidBody2D and state != EnemyState.STUNNED and state != EnemyState.DYING:
		var ball: RigidBody2D = body
		
		# Check if ball is coming from above (stomp kill)
		var relative_vel := ball.linear_velocity.y
		var ball_above := ball.global_position.y < global_position.y - body_size.y * 0.3
		
		if ball_above and relative_vel > 50:
			_take_damage(1, ball)
			# Bounce ball up
			ball.linear_velocity.y = -300
			ball.linear_velocity.x *= 0.8
		else:
			# Ball gets hurt — push it away
			_deal_damage_to_ball(ball)


func _take_damage(amount: int, _source: Node2D = null) -> void:
	if is_invincible or state == EnemyState.DYING:
		return
	
	health -= amount
	_flash_timer = 0.3
	_squash_scale = Vector2(1.3, 0.7)
	
	if health <= 0:
		_die()
	else:
		state = EnemyState.STUNNED
		_stun_timer = 1.0
		velocity.x = 0


func _deal_damage_to_ball(ball: RigidBody2D) -> void:
	var push_dir := (ball.global_position - global_position).normalized()
	ball.apply_central_impulse(push_dir * 400)
	enemy_hit_ball.emit(ball)
	_squash_scale = Vector2(0.8, 1.2)


func _die() -> void:
	state = EnemyState.DYING
	_death_timer = 0.0
	
	# Disable collision
	_collision_shape.set_deferred("disabled", true)
	_hitbox_area.set_deferred("monitoring", false)
	
	# Death particles
	for _i in range(12):
		var angle := randf() * TAU
		var speed := randf_range(60, 180)
		_death_particles.append({
			"x": 0.0, "y": 0.0,
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed - 80,
			"time": 0.0,
			"size": randf_range(3, 7),
			"color": body_color.lightened(randf() * 0.3),
		})
	
	enemy_killed.emit(self, points_value)
	
	# Score popup
	if GameState:
		GameState.total_score += points_value


# ─── Drawing ─────────────────────────────────────────────────────────────────

func _draw() -> void:
	if state == EnemyState.DEAD:
		return
	
	# Death particles
	for p in _death_particles:
		var alpha: float = 1.0 - p["time"]
		var c: Color = p["color"]
		c.a = alpha
		draw_rect(Rect2(p["x"] - p["size"] / 2, p["y"] - p["size"] / 2, p["size"], p["size"]), c, true)
	
	if state == EnemyState.DYING:
		var death_alpha := 1.0 - (_death_timer / 0.8)
		var death_scale := 1.0 + _death_timer * 0.5
		modulate.a = death_alpha
		scale = Vector2(death_scale, death_scale)
		return
	
	# Flash effect
	var draw_color := body_color
	if _flash_timer > 0:
		draw_color = draw_color.lerp(Color.WHITE, _flash_timer * 2.0)
	if state == EnemyState.STUNNED:
		var blink := sin(_time_elapsed * 20.0) > 0
		if blink:
			draw_color = stun_color
	
	var dir := 1.0 if facing == FacingDirection.RIGHT else -1.0
	var hw := body_size.x / 2.0
	var hh := body_size.y / 2.0
	
	# Draw based on enemy type
	match enemy_type:
		EnemyType.WALKER:
			_draw_walker(draw_color, dir, hw, hh)
		EnemyType.FLYER:
			_draw_flyer(draw_color, dir, hw, hh)
		EnemyType.BOUNCER:
			_draw_bouncer(draw_color, dir, hw, hh)
		EnemyType.TURRET:
			_draw_turret(draw_color, dir, hw, hh)
		EnemyType.CHARGER:
			_draw_charger(draw_color, dir, hw, hh)


func _draw_walker(color: Color, dir: float, hw: float, hh: float) -> void:
	# Shadow
	draw_filled_ellipse(Vector2(0, hh + 2), Vector2(hw * 0.8, 3), Color(0, 0, 0, 0.2))
	
	# Body (rounded rectangle approximation)
	var body_rect := Rect2(-hw, -hh, hw * 2, hh * 2)
	draw_rect(body_rect, color, true)
	draw_rect(body_rect, outline_color, false, 2.0)
	
	# Eyes
	var eye_offset := dir * 4.0
	draw_circle(Vector2(eye_offset - 4, -hh * 0.3), 4.0, eye_color)
	draw_circle(Vector2(eye_offset + 4, -hh * 0.3), 4.0, eye_color)
	# Pupils
	draw_circle(Vector2(eye_offset - 4 + dir * 1.5, -hh * 0.3), 2.0, Color.BLACK)
	draw_circle(Vector2(eye_offset + 4 + dir * 1.5, -hh * 0.3), 2.0, Color.BLACK)
	
	# Feet (animated)
	var walk_cycle := sin(_anim_frame * 2.0)
	draw_rect(Rect2(-hw + 2, hh - 2, 6, 4 + walk_cycle * 2), color.darkened(0.3), true)
	draw_rect(Rect2(hw - 8, hh - 2, 6, 4 - walk_cycle * 2), color.darkened(0.3), true)


func _draw_flyer(color: Color, dir: float, hw: float, hh: float) -> void:
	# Float offset
	var float_y := sin(_time_elapsed * 3.0) * 4.0
	
	# Wings
	var wing_angle := sin(_time_elapsed * 8.0) * 0.3
	var wing_y := float_y - 2
	draw_line(Vector2(-hw, wing_y), Vector2(-hw - 10, wing_y - 8 + wing_angle * 10), color.lightened(0.3), 3.0)
	draw_line(Vector2(hw, wing_y), Vector2(hw + 10, wing_y - 8 - wing_angle * 10), color.lightened(0.3), 3.0)
	
	# Body (circle)
	draw_circle(Vector2(0, float_y), hw * 0.8, color)
	draw_arc(Vector2(0, float_y), hw * 0.8, 0, TAU, 16, outline_color, 2.0)
	
	# Eyes
	draw_circle(Vector2(dir * 3 - 3, float_y - 2), 3.0, eye_color)
	draw_circle(Vector2(dir * 3 + 3, float_y - 2), 3.0, eye_color)
	draw_circle(Vector2(dir * 3 - 3 + dir, float_y - 2), 1.5, Color.BLACK)
	draw_circle(Vector2(dir * 3 + 3 + dir, float_y - 2), 1.5, Color.BLACK)


func _draw_bouncer(color: Color, dir: float, hw: float, hh: float) -> void:
	# Spring base
	draw_rect(Rect2(-hw, hh - 4, hw * 2, 4), color.darkened(0.4), true)
	
	# Bouncy body (circle)
	var bounce: float = abs(sin(_anim_frame * 3.0)) * 3.0
	draw_circle(Vector2(0, -bounce), hw * 0.9, color)
	draw_arc(Vector2(0, -bounce), hw * 0.9, 0, TAU, 16, outline_color, 2.0)
	
	# Angry eyes
	draw_circle(Vector2(dir * 3 - 4, -bounce - 3), 3.5, eye_color)
	draw_circle(Vector2(dir * 3 + 4, -bounce - 3), 3.5, eye_color)
	draw_circle(Vector2(dir * 3 - 4 + dir, -bounce - 3), 2.0, Color(0.8, 0.1, 0.1))
	draw_circle(Vector2(dir * 3 + 4 + dir, -bounce - 3), 2.0, Color(0.8, 0.1, 0.1))
	
	# Angry eyebrows
	draw_line(Vector2(-7, -bounce - 8), Vector2(-2, -bounce - 6), outline_color, 2.0)
	draw_line(Vector2(7, -bounce - 8), Vector2(2, -bounce - 6), outline_color, 2.0)


func _draw_turret(color: Color, dir: float, _hw: float, hh: float) -> void:
	# Base
	var base_w := body_size.x * 0.7
	draw_rect(Rect2(-base_w, hh - 8, base_w * 2, 8), color.darkened(0.3), true)
	
	# Turret body
	draw_circle(Vector2(0, 0), body_size.x * 0.45, color)
	draw_arc(Vector2(0, 0), body_size.x * 0.45, 0, TAU, 16, outline_color, 2.0)
	
	# Barrel
	var barrel_len := body_size.x * 0.6
	var barrel_dir := Vector2(dir, 0)
	if _target_ball and is_instance_valid(_target_ball):
		barrel_dir = (_target_ball.global_position - global_position).normalized()
	draw_line(Vector2.ZERO, barrel_dir * barrel_len, color.darkened(0.2), 6.0)
	draw_line(Vector2.ZERO, barrel_dir * barrel_len, color.lightened(0.1), 3.0)
	
	# Eye (single)
	draw_circle(Vector2(0, -2), 5.0, eye_color)
	draw_circle(Vector2(dir * 1.5, -2), 2.5, Color(1.0, 0.3, 0.1))


func _draw_charger(color: Color, dir: float, hw: float, hh: float) -> void:
	# Shadow
	draw_filled_ellipse(Vector2(0, hh + 2), Vector2(hw, 3), Color(0, 0, 0, 0.2))
	
	# Angled body
	var points := PackedVector2Array()
	points.append(Vector2(-hw, hh))         # bottom left
	points.append(Vector2(-hw * 0.7, -hh))  # top left
	points.append(Vector2(hw * 0.7, -hh))   # top right
	points.append(Vector2(hw, hh))           # bottom right
	draw_colored_polygon(points, color)
	draw_polyline(points, outline_color, 2.0)
	
	# Horn
	var horn_x := dir * hw * 0.7
	draw_line(Vector2(horn_x, -hh), Vector2(horn_x + dir * 12, -hh - 8), eye_color.darkened(0.1), 3.0)
	
	# Eyes (fierce)
	draw_circle(Vector2(dir * 3 - 3, -hh * 0.3), 3.5, eye_color)
	draw_circle(Vector2(dir * 3 + 3, -hh * 0.3), 3.5, eye_color)
	draw_circle(Vector2(dir * 3 - 3 + dir * 1.5, -hh * 0.3), 2.0, Color(0.9, 0.15, 0.05))
	draw_circle(Vector2(dir * 3 + 3 + dir * 1.5, -hh * 0.3), 2.0, Color(0.9, 0.15, 0.05))


func draw_filled_ellipse(center: Vector2, extents: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	var segments := 12
	for i in range(segments + 1):
		var angle := float(i) / segments * TAU
		points.append(center + Vector2(cos(angle) * extents.x, sin(angle) * extents.y))
	draw_colored_polygon(points, color)


# ─── Factory Methods ─────────────────────────────────────────────────────────

static func create_walker(pos: Vector2) -> EnemyBase:
	var e := EnemyBase.new()
	e.enemy_type = EnemyType.WALKER
	e.position = pos
	e.body_color = Color(0.85, 0.25, 0.2)
	e.move_speed = 50.0
	e.patrol_distance = 100.0
	e.points_value = 100
	return e


static func create_flyer(pos: Vector2) -> EnemyBase:
	var e := EnemyBase.new()
	e.enemy_type = EnemyType.FLYER
	e.position = pos
	e.body_color = Color(0.6, 0.3, 0.85)
	e.body_size = Vector2(20, 20)
	e.move_speed = 40.0
	e.gravity_force = 0.0
	e.patrol_distance = 80.0
	e.points_value = 150
	return e


static func create_bouncer(pos: Vector2) -> EnemyBase:
	var e := EnemyBase.new()
	e.enemy_type = EnemyType.BOUNCER
	e.position = pos
	e.body_color = Color(0.2, 0.75, 0.3)
	e.move_speed = 30.0
	e.patrol_distance = 60.0
	e.points_value = 200
	e.health = 2
	e.max_health = 2
	return e


static func create_turret(pos: Vector2) -> EnemyBase:
	var e := EnemyBase.new()
	e.enemy_type = EnemyType.TURRET
	e.position = pos
	e.body_color = Color(0.5, 0.5, 0.55)
	e.move_speed = 0.0
	e.detection_range = 300.0
	e.points_value = 250
	e.health = 3
	e.max_health = 3
	return e


static func create_charger(pos: Vector2) -> EnemyBase:
	var e := EnemyBase.new()
	e.enemy_type = EnemyType.CHARGER
	e.position = pos
	e.body_color = Color(0.9, 0.5, 0.15)
	e.body_size = Vector2(28, 22)
	e.move_speed = 40.0
	e.chase_speed = 180.0
	e.patrol_distance = 100.0
	e.detection_range = 250.0
	e.points_value = 300
	return e
