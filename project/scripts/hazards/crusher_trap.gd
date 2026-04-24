extends TrapBase
class_name CrusherTrap

@export_category("Crusher Settings")
@export var crush_distance: float = 100.0
@export var slam_speed: float = 800.0
@export var raise_speed: float = 60.0
@export var wait_time_up: float = 2.0
@export var wait_time_down: float = 0.5
@export var warning_time: float = 0.6
@export var slam_shake: float = 12.0
@export var extra_length: float = 96.0

enum CrusherState { UP, WARNING, SLAMMING, DOWN, RAISING }
var _state: CrusherState = CrusherState.UP
var _state_timer: float = 0.0
var _slam_progress: float = 0.0
var _impact_particles: CPUParticles2D
var _impact_kill_window: float = 0.0

func _trap_ready() -> void:
	trap_type = TrapType.CRUSHER

	var crusher_size := Vector2(trap_size.x + extra_length, trap_size.y)
	var shape := _collision_shape.shape as RectangleShape2D
	if shape:
		shape.size = crusher_size
		trap_size = crusher_size

	_impact_particles = CPUParticles2D.new()
	_impact_particles.emitting = false
	_impact_particles.one_shot = true
	_impact_particles.amount = 12
	_impact_particles.lifetime = 0.4
	_impact_particles.explosiveness = 0.95
	_impact_particles.direction = Vector2(0, -1)
	_impact_particles.spread = 60.0
	_impact_particles.gravity = Vector2(0, 300)
	_impact_particles.initial_velocity_min = 80.0
	_impact_particles.initial_velocity_max = 180.0
	_impact_particles.scale_amount_min = 2.0
	_impact_particles.scale_amount_max = 4.0
	_impact_particles.color = Color(0.7, 0.7, 0.7, 0.6)
	_impact_particles.position = Vector2(0, trap_size.y / 2.0 + crush_distance)
	add_child(_impact_particles)
	_state_timer = wait_time_up

func _trap_process(delta: float) -> void:
	if _impact_kill_window > 0.0:
		_impact_kill_window -= delta

	_state_timer -= delta
	match _state:
		CrusherState.UP:
			if _state_timer <= 0:
				_state = CrusherState.WARNING
				_state_timer = warning_time
		CrusherState.WARNING:

			var shake := sin(_time_elapsed * 30.0) * 2.0
			position.x = _original_position_x() + shake
			if _state_timer <= 0:
				_state = CrusherState.SLAMMING
				_slam_progress = 0.0
				_impact_kill_window = 0.0
				position.x = _original_position_x()
		CrusherState.SLAMMING:
			_slam_progress += slam_speed * delta
			if _slam_progress >= crush_distance:
				_slam_progress = crush_distance
				_state = CrusherState.DOWN
				_state_timer = wait_time_down
				_on_slam_impact()
		CrusherState.DOWN:
			if _state_timer <= 0:
				_state = CrusherState.RAISING
		CrusherState.RAISING:
			_slam_progress -= raise_speed * delta
			if _slam_progress <= 0:
				_slam_progress = 0
				_state = CrusherState.UP
				_state_timer = wait_time_up

	_collision_shape.position = Vector2(0, _slam_progress)

func _on_body_entered(body: Node2D) -> void:
	if not is_active:
		return

	if _impact_kill_window <= 0.0:
		return
	if body is RigidBody2D:
		_kill_ball(body)

var _orig_x_cached: float = 0.0
var _orig_x_set: bool = false

func _original_position_x() -> float:
	if not _orig_x_set:
		_orig_x_cached = position.x
		_orig_x_set = true
	return _orig_x_cached

func _on_slam_impact() -> void:
	_impact_particles.restart()
	_impact_particles.emitting = true
	_flash_timer = 0.2
	_impact_kill_window = 0.12

	for body in get_overlapping_bodies():
		if body is RigidBody2D:
			_kill_ball(body)

	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("_on_impact"):
		cam._on_impact(slam_shake)

func _draw() -> void:
	if not is_active:
		return

	var half := trap_size / 2.0
	var offset := Vector2(0, _slam_progress)
	var block_rect := Rect2(Vector2(-half.x, -half.y) + offset, trap_size)

	draw_rect(
		Rect2(Vector2(-5, 0), Vector2(10, crush_distance)),
		Color(0.2, 0.2, 0.22, 0.45), true
	)

	var rock_points := PackedVector2Array([
		block_rect.position + Vector2(4, 1),
		block_rect.position + Vector2(block_rect.size.x - 3, 2),
		block_rect.position + Vector2(block_rect.size.x - 1, block_rect.size.y * 0.28),
		block_rect.position + Vector2(block_rect.size.x - 4, block_rect.size.y - 2),
		block_rect.position + Vector2(block_rect.size.x * 0.62, block_rect.size.y),
		block_rect.position + Vector2(3, block_rect.size.y - 1),
		block_rect.position + Vector2(0, block_rect.size.y * 0.63),
		block_rect.position + Vector2(1, 4),
	])

	var shadow_points := PackedVector2Array()
	for p in rock_points:
		shadow_points.append(p + Vector2(4, 4))
	draw_colored_polygon(shadow_points, Color(0, 0, 0, 0.28))

	var rock_color := Color(0.42, 0.4, 0.36, 1.0)
	if _state == CrusherState.WARNING:
		var flash := sin(_time_elapsed * 15.0) * 0.5 + 0.5
		rock_color = rock_color.lerp(damage_color, flash * 0.3)

	draw_colored_polygon(rock_points, rock_color)
	draw_polyline(rock_points, Color(0.24, 0.23, 0.21, 0.95), 2.2, true)

	draw_line(
		block_rect.position + Vector2(6, block_rect.size.y * 0.34),
		block_rect.position + Vector2(block_rect.size.x - 6, block_rect.size.y * 0.28),
		Color(0.50, 0.48, 0.44, 0.35), 2.0
	)
	draw_line(
		block_rect.position + Vector2(4, block_rect.size.y * 0.60),
		block_rect.position + Vector2(block_rect.size.x - 8, block_rect.size.y * 0.57),
		Color(0.35, 0.33, 0.30, 0.45), 1.8
	)

	var crack := Color(0.23, 0.22, 0.20, 0.8)
	draw_line(
		block_rect.position + Vector2(block_rect.size.x * 0.22, 6),
		block_rect.position + Vector2(block_rect.size.x * 0.44, block_rect.size.y * 0.42),
		crack, 1.8
	)
	draw_line(
		block_rect.position + Vector2(block_rect.size.x * 0.56, block_rect.size.y * 0.2),
		block_rect.position + Vector2(block_rect.size.x * 0.36, block_rect.size.y * 0.78),
		crack, 1.6
	)
	draw_line(
		block_rect.position + Vector2(block_rect.size.x * 0.62, block_rect.size.y * 0.52),
		block_rect.position + Vector2(block_rect.size.x * 0.86, block_rect.size.y * 0.8),
		crack, 1.2
	)

	var stripe_h := 7.0
	var stripe_y := block_rect.position.y + block_rect.size.y - stripe_h
	var stripe_count := int(block_rect.size.x / 12.0)
	for i in range(stripe_count):
		if i % 2 == 0:
			draw_rect(
				Rect2(
					Vector2(block_rect.position.x + i * 12.0, stripe_y),
					Vector2(12.0, stripe_h)
				),
				damage_color,
				true
			)

	if _flash_timer > 0:
		var fa := _flash_timer / 0.2
		draw_colored_polygon(rock_points, Color(1.0, 0.92, 0.75, fa * 0.22))
