extends PlatformBase
class_name IcePlatform

@export_category("Ice Properties")
@export var friction_multiplier: float = 0.15
@export var slide_boost: float = 1.3
@export var frost_amount: int = 12
@export var sparkle_rate: float = 2.0

var _frost_positions: Array[Vector2] = []
var _sparkle_timer: float = 0.0
var _sparkle_positions: Array[Dictionary] = []
var _original_physics_material: PhysicsMaterial

func _platform_ready() -> void:
	platform_type = PlatformType.ICE
	platform_color = Color(0.7, 0.88, 0.95, 0.9)
	outline_color = Color(0.5, 0.72, 0.85, 0.8)
	particle_color = Color(0.8, 0.92, 1.0, 0.5)
	highlight_color = Color(1.0, 1.0, 1.0, 0.3)
	glow_intensity = 0.15
	glow_color = Color(0.7, 0.9, 1.0, 0.2)
	var ice_material := PhysicsMaterial.new()
	ice_material.friction = friction_multiplier
	ice_material.bounce = 0.1
	physics_material_override = ice_material
	_generate_frost_positions()

func _generate_frost_positions() -> void:
	_frost_positions.clear()
	var half := platform_size / 2.0
	for i in range(frost_amount):
		_frost_positions.append(Vector2(
			randf_range(-half.x + 5, half.x - 5),
			randf_range(-half.y + 3, half.y - 3)
		))

func _platform_process(delta: float) -> void:

	_sparkle_timer += delta
	if _sparkle_timer >= 1.0 / sparkle_rate:
		_sparkle_timer = 0.0
		_add_sparkle()

	var to_remove: Array[int] = []
	for i in range(_sparkle_positions.size()):
		_sparkle_positions[i]["life"] = (_sparkle_positions[i]["life"] as float) - delta
		if (_sparkle_positions[i]["life"] as float) <= 0.0:
			to_remove.append(i)
	for i in range(to_remove.size() - 1, -1, -1):
		_sparkle_positions.remove_at(to_remove[i])

func _add_sparkle() -> void:
	var half := platform_size / 2.0
	_sparkle_positions.append({
		"pos": Vector2(
			randf_range(-half.x + 3, half.x - 3),
			randf_range(-half.y + 2, half.y - 2)
		),
		"life": randf_range(0.3, 0.8),
		"max_life": 0.6,
		"size": randf_range(1.5, 3.5),
	})

func _on_ball_landed(ball: RigidBody2D) -> void:
	if ball:
		var dir := ball.linear_velocity.normalized()
		if dir.length() > 0.1:
			ball.apply_central_impulse(dir * slide_boost * 30.0)

func _draw_platform_details(rect: Rect2) -> void:
	var sheen_color := Color(1.0, 1.0, 1.0, 0.08)
	for i in range(5):
		var offset := i * 18.0 - 20.0
		draw_line(
			Vector2(rect.position.x + offset, rect.position.y),
			Vector2(rect.position.x + offset + rect.size.y, rect.position.y + rect.size.y),
			sheen_color, 2.0
		)
	var frost_color := Color(0.85, 0.95, 1.0, 0.25)
	for pos in _frost_positions:
		_draw_frost_crystal(pos, frost_color)
	for sparkle in _sparkle_positions:
		var life_ratio := (sparkle["life"] as float) / 0.6
		var sp := sparkle["pos"] as Vector2
		var sz := (sparkle["size"] as float) * life_ratio
		var sc := Color(1.0, 1.0, 1.0, life_ratio * 0.7)

		draw_line(sp + Vector2(-sz, 0), sp + Vector2(sz, 0), sc, 1.0)
		draw_line(sp + Vector2(0, -sz), sp + Vector2(0, sz), sc, 1.0)

		var dsz := sz * 0.6
		draw_line(sp + Vector2(-dsz, -dsz), sp + Vector2(dsz, dsz), sc, 0.5)
		draw_line(sp + Vector2(dsz, -dsz), sp + Vector2(-dsz, dsz), sc, 0.5)

func _draw_frost_crystal(pos: Vector2, color: Color) -> void:
	var size := 3.0
	for angle in [0.0, 60.0, 120.0]:
		var rad := deg_to_rad(angle)
		var dir := Vector2(cos(rad), sin(rad)) * size
		draw_line(pos - dir, pos + dir, color, 1.0)
		var branch := dir * 0.6
		var perp := Vector2(-dir.y, dir.x).normalized() * size * 0.3
		draw_line(pos + branch, pos + branch + perp, color, 0.5)
		draw_line(pos + branch, pos + branch - perp, color, 0.5)
