extends EnemyBase
class_name FlyingEnemy

## ═══════════════════════════════════════════════════════════════════════════════
## FlyingEnemy — Aerial enemy that floats and swoops
## ═══════════════════════════════════════════════════════════════════════════════
##
## Moves in a sine-wave pattern through the air. Swoops toward ball
## when in range. Harder to hit because it's usually above the ball.

@export_category("Flight")
@export var hover_amplitude: float = 20.0
@export var hover_frequency: float = 2.0
@export var swoop_speed: float = 200.0
@export var swoop_cooldown: float = 3.0

var _hover_base_y: float = 0.0
var _swoop_timer: float = 0.0
var _is_swooping: bool = false
var _swoop_target: Vector2
var _swoop_return: Vector2
var _wing_flap: float = 0.0
var _trail_particles: Array[Dictionary] = []


func _on_enemy_ready() -> void:
	enemy_type = EnemyType.FLYER
	gravity_force = 0.0
	_hover_base_y = global_position.y
	body_color = Color(0.55, 0.28, 0.82)
	body_size = Vector2(22, 18)
	points_value = 150


func _process_patrol(delta: float) -> void:
	var dir := 1.0 if facing == FacingDirection.RIGHT else -1.0
	velocity.x = dir * move_speed
	
	# Sine wave hover
	var target_y := _hover_base_y + sin(_time_elapsed * hover_frequency) * hover_amplitude
	velocity.y = (target_y - global_position.y) * 3.0
	
	# Patrol boundary
	var dist := global_position.x - _patrol_origin.x
	if abs(dist) >= patrol_distance:
		_flip_direction()
	
	_wing_flap += delta * 12.0
	
	# Trail
	if randf() < 0.15:
		_trail_particles.append({
			"x": global_position.x, "y": global_position.y + 6,
			"time": 0.0, "size": randf_range(2, 4),
		})


func _process_chase(delta: float) -> void:
	if not _target_ball or not is_instance_valid(_target_ball):
		state = EnemyState.PATROL
		return
	
	_wing_flap += delta * 16.0
	_swoop_timer += delta
	
	if _is_swooping:
		var dir_to := (_swoop_target - global_position).normalized()
		velocity = dir_to * swoop_speed
		
		if global_position.distance_to(_swoop_target) < 20:
			_is_swooping = false
			_swoop_timer = 0.0
			# Return to hover height
			velocity.y = -100
	else:
		# Hover above ball
		var hover_pos := _target_ball.global_position + Vector2(0, -60)
		var dir_to := (hover_pos - global_position).normalized()
		velocity = dir_to * chase_speed * 0.6
		
		# Initiate swoop
		if _swoop_timer >= swoop_cooldown:
			_is_swooping = true
			_swoop_target = _target_ball.global_position
			_swoop_return = global_position
	
	var dist := global_position.distance_to(_target_ball.global_position)
	if dist > detection_range * 2.0:
		_target_ball = null
		_is_swooping = false
		state = EnemyState.PATROL


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	# Update trail
	var i := _trail_particles.size() - 1
	while i >= 0:
		_trail_particles[i]["time"] += delta
		if _trail_particles[i]["time"] > 0.6:
			_trail_particles.remove_at(i)
		i -= 1
	
	if _trail_particles.size() > 12:
		_trail_particles = _trail_particles.slice(_trail_particles.size() - 12)


func _draw() -> void:
	if state == EnemyState.DEAD:
		return
	
	# Death particles from base
	for p in _death_particles:
		var alpha: float = 1.0 - p["time"]
		var c: Color = p["color"]
		c.a = alpha
		draw_rect(Rect2(p["x"] - p["size"] / 2, p["y"] - p["size"] / 2, p["size"], p["size"]), c, true)
	
	if state == EnemyState.DYING:
		return
	
	var draw_color := body_color
	if _flash_timer > 0:
		draw_color = draw_color.lerp(Color.WHITE, _flash_timer * 2.0)
	
	var dir := 1.0 if facing == FacingDirection.RIGHT else -1.0
	var r := body_size.x * 0.45
	
	# Shadow on ground (if close enough)
	# Not drawing shadow for flyers to keep it simple
	
	# Wing animation
	var wing_up := sin(_wing_flap) * 8.0
	var wing_color := draw_color.lightened(0.25)
	
	# Left wing
	var lw := PackedVector2Array()
	lw.append(Vector2(-4, 0))
	lw.append(Vector2(-r - 10, -wing_up - 4))
	lw.append(Vector2(-r - 6, 2))
	draw_colored_polygon(lw, wing_color)
	
	# Right wing
	var rw := PackedVector2Array()
	rw.append(Vector2(4, 0))
	rw.append(Vector2(r + 10, wing_up - 4))
	rw.append(Vector2(r + 6, 2))
	draw_colored_polygon(rw, wing_color)
	
	# Body
	draw_circle(Vector2.ZERO, r, draw_color)
	draw_arc(Vector2.ZERO, r, 0, TAU, 16, outline_color, 1.5)
	
	# Eyes
	var eye_x := dir * 3
	draw_circle(Vector2(eye_x - 3, -2), 3.0, eye_color)
	draw_circle(Vector2(eye_x + 3, -2), 3.0, eye_color)
	draw_circle(Vector2(eye_x - 3 + dir, -2), 1.5, Color(0.4, 0.1, 0.6))
	draw_circle(Vector2(eye_x + 3 + dir, -2), 1.5, Color(0.4, 0.1, 0.6))
	
	# Swoop indicator
	if _is_swooping:
		var speed_lines := 3
		for sl in range(speed_lines):
			var ly := -6.0 + sl * 6.0
			var lx := -dir * (r + 4 + sl * 3)
			draw_line(Vector2(lx, ly), Vector2(lx - dir * 8, ly), Color(1, 1, 1, 0.4), 1.5)
