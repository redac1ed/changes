extends PlatformBase
class_name WeightedPlatform

## ═══════════════════════════════════════════════════════════════════════════════
## WeightedPlatform — Tilts based on where the ball sits on its surface
## ═══════════════════════════════════════════════════════════════════════════════
##
## Simulates a see-saw / teeter-totter. The platform pivots around
## its center, tilting toward whichever side has more weight (the ball).
## Can be balanced by careful positioning.

# ─── Exports ─────────────────────────────────────────────────────────────────
@export_category("Weight Settings")
@export var max_tilt_angle: float = 25.0
@export var tilt_speed: float = 3.0
@export var return_speed: float = 1.5
@export var pivot_friction: float = 0.85
@export var show_pivot: bool = true
@export var pivot_color: Color = Color(0.4, 0.4, 0.45, 0.8)

# ─── Internal ────────────────────────────────────────────────────────────────
var _current_angle: float = 0.0
var _target_angle: float = 0.0
var _angular_velocity: float = 0.0
var _ball_offset_x: float = 0.0
var _pivot_size: float = 8.0


func _platform_ready() -> void:
	platform_type = PlatformType.WEIGHTED
	platform_color = Color(0.6, 0.55, 0.7, 1.0)
	outline_color = Color(0.4, 0.35, 0.55, 1.0)
	particle_color = Color(0.65, 0.6, 0.75, 0.5)


func _platform_physics_process(delta: float) -> void:
	if _is_ball_on_platform:
		# Calculate tilt based on ball's horizontal offset from center
		var normalized_offset := _ball_offset_x / (platform_size.x * 0.5)
		normalized_offset = clampf(normalized_offset, -1.0, 1.0)
		_target_angle = normalized_offset * deg_to_rad(max_tilt_angle)
	else:
		# Return to neutral
		_target_angle = 0.0
	
	# Smooth tilt with physics-like response
	var speed := tilt_speed if _is_ball_on_platform else return_speed
	_angular_velocity += (_target_angle - _current_angle) * speed * delta * 60.0
	_angular_velocity *= pivot_friction
	_current_angle += _angular_velocity * delta
	
	rotation = _current_angle


func _on_ball_landed(ball: RigidBody2D) -> void:
	_ball_offset_x = ball.global_position.x - global_position.x


func _platform_process(_delta: float) -> void:
	# Track ball position continuously while it's on the platform
	if _is_ball_on_platform:
		# Find the ball via detection area
		for body in _detection_area.get_overlapping_bodies():
			if body is RigidBody2D:
				_ball_offset_x = body.global_position.x - global_position.x
				break


func _draw_platform_details(rect: Rect2) -> void:
	if show_pivot:
		_draw_pivot(rect)
	_draw_balance_indicator(rect)


func _draw_pivot(rect: Rect2) -> void:
	# Triangle pivot below platform center
	var center_x := rect.position.x + rect.size.x / 2.0
	var bottom_y := rect.position.y + rect.size.y
	
	var p1 := Vector2(center_x, bottom_y)
	var p2 := Vector2(center_x - _pivot_size, bottom_y + _pivot_size)
	var p3 := Vector2(center_x + _pivot_size, bottom_y + _pivot_size)
	
	draw_colored_polygon(PackedVector2Array([p1, p2, p3]), pivot_color)
	
	# Pivot dot
	draw_circle(Vector2(center_x, bottom_y + 2), 2.0, Color(1.0, 1.0, 1.0, 0.4))


func _draw_balance_indicator(rect: Rect2) -> void:
	# Small level indicator line
	var center := Vector2(
		rect.position.x + rect.size.x / 2.0,
		rect.position.y + rect.size.y / 2.0
	)
	var indicator_len := 12.0
	var level_color: Color
	
	if abs(_current_angle) < deg_to_rad(2.0):
		level_color = Color(0.3, 1.0, 0.3, 0.5)  # Green = balanced
	elif abs(_current_angle) < deg_to_rad(10.0):
		level_color = Color(1.0, 1.0, 0.3, 0.5)  # Yellow = tilting
	else:
		level_color = Color(1.0, 0.3, 0.3, 0.5)  # Red = extreme tilt
	
	# Level bubble (counteracts platform rotation to stay world-aligned)
	var bubble_center := center
	var bubble_x := -sin(_current_angle) * indicator_len
	draw_circle(
		Vector2(bubble_center.x + bubble_x, bubble_center.y),
		3.0, level_color
	)
	
	# Trough
	draw_line(
		Vector2(center.x - indicator_len, center.y),
		Vector2(center.x + indicator_len, center.y),
		Color(1.0, 1.0, 1.0, 0.2), 1.0
	)
