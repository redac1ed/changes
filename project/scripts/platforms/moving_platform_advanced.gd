extends PlatformBase
class_name MovingPlatformAdvanced

## ═══════════════════════════════════════════════════════════════════════════════
## MovingPlatformAdvanced — Platform that oscillates between waypoints
## ═══════════════════════════════════════════════════════════════════════════════
##
## Supports linear, sine, and ease-in-out motion profiles.
## Can carry the ball along its surface using velocity transfer.
## Features: configurable speed, pause at endpoints, path preview in editor.

# ─── Enums ───────────────────────────────────────────────────────────────────
enum MotionProfile { LINEAR, SINE, EASE_IN_OUT, BOUNCE }
enum MoveAxis { HORIZONTAL, VERTICAL, DIAGONAL, PATH }

# ─── Exports ─────────────────────────────────────────────────────────────────
@export_category("Movement")
@export var move_axis: MoveAxis = MoveAxis.HORIZONTAL
@export var move_distance: float = 200.0
@export var move_speed: float = 80.0
@export var motion_profile: MotionProfile = MotionProfile.SINE
@export var pause_at_endpoints: float = 0.3
@export var start_delay: float = 0.0
@export var diagonal_angle: float = 45.0

@export_category("Path Mode")
@export var waypoints: Array[Vector2] = []
@export var loop_path: bool = true

@export_category("Visual")
@export var show_path_preview: bool = true
@export var path_color: Color = Color(1.0, 1.0, 1.0, 0.15)
@export var arrow_color: Color = Color(1.0, 1.0, 1.0, 0.3)

# ─── Internal State ──────────────────────────────────────────────────────────
var _progress: float = 0.0
var _direction: int = 1
var _pause_timer: float = 0.0
var _delay_timer: float = 0.0
var _current_waypoint_idx: int = 0
var _velocity: Vector2 = Vector2.ZERO
var _previous_position: Vector2


func _platform_ready() -> void:
	platform_type = PlatformType.MOVING
	platform_color = Color(0.45, 0.65, 0.85, 1.0)
	outline_color = Color(0.3, 0.45, 0.7, 1.0)
	particle_color = Color(0.5, 0.7, 0.95, 0.5)
	_delay_timer = start_delay
	_previous_position = global_position
	
	# If no waypoints provided, generate from axis/distance
	if waypoints.is_empty() and move_axis != MoveAxis.PATH:
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
	# Start delay
	if _delay_timer > 0.0:
		_delay_timer -= delta
		return
	
	# Endpoint pause
	if _pause_timer > 0.0:
		_pause_timer -= delta
		_velocity = Vector2.ZERO
		return
	
	if waypoints.size() < 2:
		return
	
	# Advance progress
	var segment_length := waypoints[_current_waypoint_idx].distance_to(
		waypoints[(_current_waypoint_idx + 1) % waypoints.size()]
	)
	if segment_length < 0.01:
		segment_length = 1.0
	
	_progress += (move_speed * delta) / segment_length
	
	# Handle segment completion
	if _progress >= 1.0:
		_progress = 0.0
		_current_waypoint_idx += _direction
		
		if _current_waypoint_idx >= waypoints.size() - 1:
			if loop_path and waypoints.size() > 2:
				_current_waypoint_idx = 0
			else:
				_direction = -1
				_current_waypoint_idx = waypoints.size() - 2
				_pause_timer = pause_at_endpoints
		elif _current_waypoint_idx < 0:
			_direction = 1
			_current_waypoint_idx = 0
			_pause_timer = pause_at_endpoints
	
	# Calculate position
	var from_idx: int = _current_waypoint_idx
	var to_idx: int = (from_idx + 1) % waypoints.size()
	if from_idx < 0:
		from_idx = 0
	if to_idx >= waypoints.size():
		to_idx = waypoints.size() - 1
	
	var from_pos: Vector2 = _original_position + waypoints[from_idx]
	var to_pos: Vector2 = _original_position + waypoints[to_idx]
	var t := _apply_motion_profile(_progress)
	
	var new_pos := from_pos.lerp(to_pos, t)
	_velocity = (new_pos - global_position) / maxf(delta, 0.001)
	global_position = new_pos


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
	# Transfer platform velocity to ball for realistic carrying
	if ball and _velocity.length() > 5.0:
		ball.apply_central_impulse(_velocity * 0.15)


func get_platform_velocity() -> Vector2:
	return _velocity
