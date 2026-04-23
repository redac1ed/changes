extends PlatformBase
class_name OneWayPlatform

@export_category("One-Way Settings")
@export var pass_through_margin: float = 8.0
@export var show_arrows: bool = true
@export var arrow_spacing: float = 20.0
@export var dashed_edge: bool = true

func _platform_ready() -> void:
	platform_type = PlatformType.ONE_WAY
	platform_color = Color(0.6, 0.75, 0.9, 0.85)
	outline_color = Color(0.4, 0.55, 0.75, 0.7)
	particle_color = Color(0.7, 0.85, 1.0, 0.4)
	use_shadow = false
	if _collision_shape:
		_collision_shape.one_way_collision = true
		_collision_shape.one_way_collision_margin = pass_through_margin

func _draw_platform_details(rect: Rect2) -> void:
	if dashed_edge:
		var dash_length := 8.0
		var gap_length := 5.0
		var x := rect.position.x
		var bottom_y := rect.position.y + rect.size.y
		var dash_color := Color(outline_color.r, outline_color.g, outline_color.b, 0.4)
		while x < rect.position.x + rect.size.x - dash_length:
			draw_line(
				Vector2(x, bottom_y),
				Vector2(x + dash_length, bottom_y),
				dash_color, 1.0
			)
			x += dash_length + gap_length
	if show_arrows:
		var arrow_count := int(rect.size.x / arrow_spacing)
		var arr_color := Color(1.0, 1.0, 1.0, 0.2)
		var center_y := rect.position.y + rect.size.y / 2.0
		for i in range(arrow_count):
			var ax: float = rect.position.x + arrow_spacing * 0.5 + i * arrow_spacing
			draw_line(
				Vector2(ax - 3, center_y + 2),
				Vector2(ax, center_y - 2),
				arr_color, 1.5
			)
			draw_line(
				Vector2(ax, center_y - 2),
				Vector2(ax + 3, center_y + 2),
				arr_color, 1.5
			)
	var pulse := 0.85 + sin(_time_elapsed * 1.5) * 0.1
	modulate.a = pulse
