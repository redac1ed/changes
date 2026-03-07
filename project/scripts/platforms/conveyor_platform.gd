extends PlatformBase
class_name ConveyorPlatform

@export_category("Conveyor Settings")
@export var conveyor_speed: float = 120.0
@export var conveyor_direction: Vector2 = Vector2.RIGHT
@export var belt_animation_speed: float = 3.0
@export var reversible: bool = false
@export var reverse_interval: float = 4.0

var _belt_offset: float = 0.0
var _reverse_timer: float = 0.0
var _current_direction: Vector2
var _balls_on_belt: Array[RigidBody2D] = []

func _platform_ready() -> void:
	platform_type = PlatformType.CONVEYOR
	platform_color = Color(0.5, 0.5, 0.55, 1.0)
	outline_color = Color(0.35, 0.35, 0.4, 1.0)
	particle_color = Color(0.6, 0.6, 0.65, 0.5)
	_current_direction = conveyor_direction.normalized()

func _platform_physics_process(delta: float) -> void:
	# Animate belt
	_belt_offset += belt_animation_speed * delta * conveyor_speed * 0.01
	if _belt_offset > 1.0:
		_belt_offset -= 1.0
	
	# Reverse timer
	if reversible:
		_reverse_timer += delta
		if _reverse_timer >= reverse_interval:
			_reverse_timer = 0.0
			_current_direction = -_current_direction
	
	# Apply force to all balls on belt
	for ball in _balls_on_belt:
		if is_instance_valid(ball):
			var force := _current_direction * conveyor_speed
			ball.apply_central_force(force)

func _on_ball_landed(ball: RigidBody2D) -> void:
	if not _balls_on_belt.has(ball):
		_balls_on_belt.append(ball)

func _on_ball_left(ball: RigidBody2D) -> void:
	_balls_on_belt.erase(ball)

func _draw_platform_details(rect: Rect2) -> void:
	# Belt track lines
	var track_color := Color(0.4, 0.4, 0.45, 0.5)
	var top_track_y := rect.position.y + 3
	var bottom_track_y := rect.position.y + rect.size.y - 3
	draw_line(
		Vector2(rect.position.x + 2, top_track_y),
		Vector2(rect.position.x + rect.size.x - 2, top_track_y),
		track_color, 1.0
	)
	draw_line(
		Vector2(rect.position.x + 2, bottom_track_y),
		Vector2(rect.position.x + rect.size.x - 2, bottom_track_y),
		track_color, 1.0
	)
	
	# Animated chevrons showing direction
	var chevron_color := Color(1.0, 1.0, 1.0, 0.3)
	var spacing := 16.0
	var chevron_count := int(rect.size.x / spacing) + 2
	var center_y := rect.position.y + rect.size.y / 2.0
	for i in range(chevron_count):
		var base_x: float = rect.position.x + i * spacing
		# Apply scrolling offset
		if _current_direction.x >= 0:
			base_x += _belt_offset * spacing
		else:
			base_x -= _belt_offset * spacing
		# Wrap around
		base_x = rect.position.x + fmod(base_x - rect.position.x, rect.size.x)
		if base_x < rect.position.x or base_x > rect.position.x + rect.size.x - 4:
			continue
		# Draw chevron pointing in conveyor direction
		var ch_size := 4.0
		if _current_direction.x >= 0:
			draw_line(Vector2(base_x - ch_size, center_y - ch_size), Vector2(base_x, center_y), chevron_color, 1.5)
			draw_line(Vector2(base_x, center_y), Vector2(base_x - ch_size, center_y + ch_size), chevron_color, 1.5)
		else:
			draw_line(Vector2(base_x + ch_size, center_y - ch_size), Vector2(base_x, center_y), chevron_color, 1.5)
			draw_line(Vector2(base_x, center_y), Vector2(base_x + ch_size, center_y + ch_size), chevron_color, 1.5)
	
	# Roller circles at ends
	var roller_color := Color(0.3, 0.3, 0.35, 0.6)
	var roller_r := rect.size.y / 2.0 - 2
	draw_circle(Vector2(rect.position.x + roller_r + 2, center_y), roller_r, roller_color)
	draw_circle(Vector2(rect.position.x + rect.size.x - roller_r - 2, center_y), roller_r, roller_color)
	
	# Roller spokes
	var spoke_color := Color(0.5, 0.5, 0.55, 0.4)
	var spoke_angle := _belt_offset * TAU
	for end_x in [rect.position.x + roller_r + 2, rect.position.x + rect.size.x - roller_r - 2]:
		for spoke in range(4):
			var a := spoke_angle + spoke * PI / 2.0
			draw_line(
				Vector2(end_x, center_y),
				Vector2(end_x + cos(a) * roller_r * 0.8, center_y + sin(a) * roller_r * 0.8),
				spoke_color, 1.0
			)