extends PlatformBase
class_name MovingPlatform

enum MotionProfile { LINEAR, SINE, EASE_IN_OUT, BOUNCE }
enum MoveAxis { HORIZONTAL, VERTICAL, DIAGONAL, PATH }
enum SurfaceMode { MOVING, CONVEYOR }

@export_category("Movement")
@export var surface_mode: SurfaceMode = SurfaceMode.MOVING
@export var move_axis: MoveAxis = MoveAxis.HORIZONTAL
@export var move_distance: float = 200.0
@export var move_speed: float = 80.0
@export var motion_profile: MotionProfile = MotionProfile.SINE
@export var pause_at_endpoints: float = 0.3
@export var start_delay: float = 0.0
@export var diagonal_angle: float = 45.0

@export_category("Conveyor")
@export var conveyor_speed: float = 120.0
@export var conveyor_direction: Vector2 = Vector2.RIGHT
@export var belt_animation_speed: float = 3.0
@export var reversible: bool = false
@export var reverse_interval: float = 4.0
@export var reverse_ramp_time: float = 0.5

@export_category("Path Mode")
@export var waypoints: Array[Vector2] = []
@export var loop_path: bool = true

@export_category("Visual")
@export var show_path_preview: bool = true
@export var path_color: Color = Color(1.0, 1.0, 1.0, 0.15)
@export var arrow_color: Color = Color(1.0, 1.0, 1.0, 0.3)

var _progress: float = 0.0
var _direction: int = 1
var _pause_timer: float = 0.0
var _delay_timer: float = 0.0
var _current_waypoint_idx: int = 0
var _velocity: Vector2 = Vector2.ZERO
var _previous_position: Vector2
var _balls_on_platform: Array[RigidBody2D] = []
var _belt_offset: float = 0.0
var _reverse_timer: float = 0.0
var _current_direction: Vector2 = Vector2.RIGHT
var _speed_scale: float = 1.0
var _target_speed_scale: float = 1.0


func _platform_ready() -> void:
	platform_type = PlatformType.MOVING
	platform_color = Color(0.45, 0.65, 0.85, 1.0)
	outline_color = Color(0.3, 0.45, 0.7, 1.0)
	particle_color = Color(0.5, 0.7, 0.95, 0.5)
	_delay_timer = start_delay
	_previous_position = global_position
	_current_direction = conveyor_direction.normalized()
	if _current_direction.is_zero_approx():
		_current_direction = Vector2.RIGHT
	_speed_scale = 1.0
	_target_speed_scale = 1.0
	
	# If no waypoints provided, generate from axis/distance
	if surface_mode == SurfaceMode.MOVING and waypoints.is_empty() and move_axis != MoveAxis.PATH:
		_generate_waypoints_from_axis()


func _generate_waypoints_from_axis() -> void:
	waypoints.clear()
	waypoints.append(Vector2.ZERO)
	match move_axis:
		MoveAxis.HORIZONTAL:
			waypoints.append(Vector2(move_distance, 0))
		MoveAxis.VERTICAL:
			waypoints.append(Vector2(0, move_distance))
		MoveAxis.DIAGONAL:
			var rad := deg_to_rad(diagonal_angle)
			waypoints.append(Vector2(cos(rad), sin(rad)) * move_distance)

func _platform_physics_process(delta: float) -> void:
	if surface_mode == SurfaceMode.CONVEYOR:
		_process_conveyor(delta)
		return

	# Start delay
	if _delay_timer > 0.0:
		_delay_timer -= delta
		return
	# Endpoint pause
	if _pause_timer > 0.0:
		_pause_timer -= delta
		_velocity = Vector2.ZERO
		_carry_balls(delta)
		return
	if waypoints.size() < 2:
		return
	# Advance progress
	var to_idx_calc: int = _current_waypoint_idx + _direction
	if to_idx_calc < 0 or to_idx_calc >= waypoints.size():
		to_idx_calc = _current_waypoint_idx
	var segment_length := waypoints[_current_waypoint_idx].distance_to(
		waypoints[to_idx_calc]
	)
	if segment_length < 0.01:
		segment_length = 1.0
	_progress += (move_speed * delta) / segment_length
	
	# Handle segment completion
	if _progress >= 1.0:
		_progress -= 1.0 # Keep fractional progress
		_current_waypoint_idx += _direction
		if _current_waypoint_idx >= waypoints.size() - 1:
			if loop_path and waypoints.size() > 2:
				_current_waypoint_idx = 0
			else:
				# Reached the end: reverse direction instead of jumping back to index 0
				_direction = -1
				_current_waypoint_idx = waypoints.size() - 1
				_pause_timer = pause_at_endpoints
		elif _current_waypoint_idx < 0:
			# Reached the start: go forward instead of jumping back to end
			_direction = 1
			_current_waypoint_idx = 0
			_pause_timer = pause_at_endpoints
	
	# Calculate position
	var from_idx: int = _current_waypoint_idx
	var to_idx: int = _current_waypoint_idx + _direction
	# Clamp indices to valid ranges so it stays exactly at the endpoint while paused or turning
	if to_idx >= waypoints.size():
		to_idx = waypoints.size() - 1
	elif to_idx < 0:
		to_idx = 0
	
	var from_pos: Vector2 = _original_position + waypoints[from_idx]
	var to_pos: Vector2 = _original_position + waypoints[to_idx]
	var t := _apply_motion_profile(_progress)
	var new_pos := from_pos.lerp(to_pos, t)
	_velocity = (new_pos - global_position) / maxf(delta, 0.001)
	global_position = new_pos
	_carry_balls(delta)

func _process_conveyor(delta: float) -> void:
	_belt_offset += belt_animation_speed * delta * conveyor_speed * 0.01 * _speed_scale
	if _belt_offset > 1.0:
		_belt_offset -= 1.0
	elif _belt_offset < 0.0:
		_belt_offset += 1.0
	if reversible:
		_reverse_timer += delta
		if _reverse_timer >= reverse_interval:
			_reverse_timer = 0.0
			_target_speed_scale = -_target_speed_scale
	var ramp_step := delta / maxf(reverse_ramp_time, 0.01)
	_speed_scale = move_toward(_speed_scale, _target_speed_scale, ramp_step * 2.0)
	_velocity = get_platform_velocity()
	_carry_balls(delta)

func _carry_balls(delta: float) -> void:
	var platform_top_y := global_position.y - (platform_size.y * 0.5)
	var hold_y := platform_top_y - 20.0
	for ball in _balls_on_platform:
		if not is_instance_valid(ball):
			continue
		if ball.global_position.y > platform_top_y + 24.0:
			continue
		ball.sleeping = false
		var ball_velocity := ball.linear_velocity
		if not _velocity.is_zero_approx():
			ball.global_position += _velocity * delta
			ball_velocity.x = _velocity.x
			if abs(_velocity.y) > 0.01:
				ball_velocity.y = maxf(ball_velocity.y, _velocity.y)
		else:
			ball_velocity.x = 0.0
			if abs(ball.global_position.y - hold_y) > 0.5:
				ball.global_position.y = lerpf(ball.global_position.y, hold_y, minf(delta * 20.0, 1.0))
			ball_velocity.y = minf(ball_velocity.y, 0.0)
		ball.linear_velocity = ball_velocity

func _apply_motion_profile(t: float) -> float:
	match motion_profile:
		MotionProfile.LINEAR:
			return t
		MotionProfile.SINE:
			return (1.0 - cos(t * PI)) / 2.0
		MotionProfile.EASE_IN_OUT:
			if t < 0.5:
				return 2.0 * t * t
			else:
				return 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0
		MotionProfile.BOUNCE:
			var bounce_t: float = abs(sin(t * PI))
			return bounce_t
	return t

func _draw_platform_details(rect: Rect2) -> void:
	# Direction arrows on surface
	var arrow_y := rect.position.y + rect.size.y / 2.0
	var arrow_size := 4.0
	var center_x := rect.position.x + rect.size.x / 2.0
	
	# Left arrow
	draw_line(
		Vector2(center_x - 15, arrow_y),
		Vector2(center_x - 15 - arrow_size, arrow_y),
		arrow_color, 2.0
	)
	draw_line(
		Vector2(center_x - 15 - arrow_size, arrow_y),
		Vector2(center_x - 15 - arrow_size + 3, arrow_y - 3),
		arrow_color, 2.0
	)
	# Right arrow
	draw_line(
		Vector2(center_x + 15, arrow_y),
		Vector2(center_x + 15 + arrow_size, arrow_y),
		arrow_color, 2.0
	)
	draw_line(
		Vector2(center_x + 15 + arrow_size, arrow_y),
		Vector2(center_x + 15 + arrow_size - 3, arrow_y - 3),
		arrow_color, 2.0
	)
	
	# Path preview dots
	if show_path_preview and waypoints.size() >= 2:
		if surface_mode == SurfaceMode.CONVEYOR:
			return
		for i in range(waypoints.size()):
			var wp: Vector2 = waypoints[i] - (global_position - _original_position)
			draw_circle(wp, 3.0, path_color)
			if i < waypoints.size() - 1:
				var next_wp: Vector2 = waypoints[i + 1] - (global_position - _original_position)
				# Dotted line between waypoints
				var dist := wp.distance_to(next_wp)
				var dots := int(dist / 8.0)
				for d in range(dots):
					var dt := float(d) / float(maxf(dots, 1))
					var dot_pos := wp.lerp(next_wp, dt)
					draw_circle(dot_pos, 1.5, path_color)

func _on_ball_landed(ball: RigidBody2D) -> void:
	if ball and not _balls_on_platform.has(ball):
		_balls_on_platform.append(ball)
		if _velocity.length() > 5.0:
			ball.apply_central_impulse(_velocity * 0.15)

func _on_ball_left(ball: RigidBody2D) -> void:
	_balls_on_platform.erase(ball)

func get_platform_velocity() -> Vector2:
	if surface_mode == SurfaceMode.CONVEYOR:
		return _current_direction * conveyor_speed * _speed_scale
	return _velocity

func get_belt_velocity() -> Vector2:
	return get_platform_velocity()