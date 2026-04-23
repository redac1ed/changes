extends PlatformBase
class_name FallingPlatform

signal platform_fell()
signal platform_respawned()

@export_category("Falling Behavior")
@export var shake_duration: float = 0.5
@export var fall_speed: float = 600.0
@export var fall_acceleration: float = 1200.0
@export var respawn_delay: float = 3.0
@export var respawn_fade_duration: float = 0.5
@export var respawn_retract_duration: float = 0.8
@export var max_fall_distance: float = 800.0
@export var shake_intensity: float = 3.0

enum FallState { IDLE, SHAKING, FALLING, WAITING, RESPAWNING }
var _fall_state: FallState = FallState.IDLE
var _shake_timer: float = 0.0
var _fall_velocity: float = 0.0
var _respawn_timer: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO
var _respawn_alpha: float = 1.0
var _respawn_progress: float = 0.0
var _fall_distance: float = 0.0
var _fallen_position: Vector2 = Vector2.ZERO
var _warning_particles: CPUParticles2D

func _platform_ready() -> void:
	platform_type = PlatformType.FALLING
	platform_color = Color(0.85, 0.55, 0.3, 1.0)
	outline_color = Color(0.65, 0.35, 0.15, 1.0)
	particle_color = Color(0.9, 0.6, 0.3, 0.6)

	_setup_warning_particles()

func _setup_warning_particles() -> void:
	_warning_particles = CPUParticles2D.new()
	_warning_particles.emitting = false
	_warning_particles.amount = 6
	_warning_particles.lifetime = 0.3
	_warning_particles.one_shot = false
	_warning_particles.direction = Vector2.DOWN
	_warning_particles.spread = 20.0
	_warning_particles.gravity = Vector2(0, 300)
	_warning_particles.initial_velocity_min = 10.0
	_warning_particles.initial_velocity_max = 40.0
	_warning_particles.scale_amount_min = 1.0
	_warning_particles.scale_amount_max = 2.5
	_warning_particles.color = Color(0.9, 0.6, 0.3, 0.4)
	_warning_particles.position = Vector2(0, platform_size.y / 2.0)
	add_child(_warning_particles)

func _platform_process(delta: float) -> void:
	match _fall_state:
		FallState.SHAKING:
			_process_shaking(delta)
		FallState.FALLING:
			_process_falling(delta)
		FallState.WAITING:
			_process_waiting(delta)
		FallState.RESPAWNING:
			_process_respawning(delta)

func _process_shaking(delta: float) -> void:
	_shake_timer -= delta

	var shake_progress := 1.0 - (_shake_timer / shake_duration)
	var intensity := shake_intensity * (0.5 + shake_progress * 0.5)
	_shake_offset = Vector2(
		randf_range(-intensity, intensity),
		0.0
	)
	position = _original_position + _shake_offset

	_warning_particles.emitting = true

	if shake_progress > 0.6:
		_flash_timer = 0.05

	if _shake_timer <= 0.0:
		_start_falling()

func _start_falling() -> void:
	_fall_state = FallState.FALLING
	_fall_velocity = 0.0
	_fall_distance = 0.0
	_shake_offset = Vector2.ZERO
	_warning_particles.emitting = false
	platform_fell.emit()

func _process_falling(delta: float) -> void:
	_fall_velocity += fall_acceleration * delta
	_fall_velocity = minf(_fall_velocity, fall_speed)

	position.y += _fall_velocity * delta
	_fall_distance += _fall_velocity * delta

	_respawn_alpha = clampf(1.0 - (_fall_distance / max_fall_distance), 0.0, 1.0)
	modulate.a = _respawn_alpha

	if _fall_distance >= max_fall_distance:
		_start_waiting()

func _start_waiting() -> void:
	_fall_state = FallState.WAITING
	_respawn_timer = respawn_delay
	_fallen_position = position
	visible = false
	_collision_shape.disabled = true

func _process_waiting(delta: float) -> void:
	_respawn_timer -= delta
	if _respawn_timer <= 0.0:
		_start_respawning()

func _start_respawning() -> void:
	_fall_state = FallState.RESPAWNING
	position = _fallen_position
	visible = true
	modulate.a = 0.0
	_respawn_alpha = 0.0
	_respawn_progress = 0.0

func _process_respawning(delta: float) -> void:
	_respawn_progress += delta / maxf(respawn_retract_duration, 0.001)
	var t := clampf(_respawn_progress, 0.0, 1.0)
	position = _fallen_position.lerp(_original_position, t)

	_respawn_alpha += delta / maxf(respawn_fade_duration, 0.001)
	modulate.a = clampf(_respawn_alpha, 0.0, 1.0)

	if _respawn_alpha >= 1.0 and t >= 1.0:
		_fall_state = FallState.IDLE
		position = _original_position
		_collision_shape.disabled = false
		modulate.a = 1.0
		platform_respawned.emit()

func _on_ball_landed(_ball: RigidBody2D) -> void:
	if _fall_state == FallState.IDLE:
		_fall_state = FallState.SHAKING
		_shake_timer = shake_duration

func _draw_platform_details(rect: Rect2) -> void:

	var crack_color := Color(outline_color.r, outline_color.g, outline_color.b, 0.4)

	draw_line(
		Vector2(rect.position.x + rect.size.x * 0.3, rect.position.y + 2),
		Vector2(rect.position.x + rect.size.x * 0.35, rect.position.y + rect.size.y * 0.5),
		crack_color, 1.0
	)
	draw_line(
		Vector2(rect.position.x + rect.size.x * 0.35, rect.position.y + rect.size.y * 0.5),
		Vector2(rect.position.x + rect.size.x * 0.4, rect.position.y + rect.size.y - 2),
		crack_color, 1.0
	)

	draw_line(
		Vector2(rect.position.x + rect.size.x * 0.7, rect.position.y + 2),
		Vector2(rect.position.x + rect.size.x * 0.65, rect.position.y + rect.size.y * 0.6),
		crack_color, 1.0
	)

	if _fall_state == FallState.SHAKING:
		var warn_x := rect.position.x + rect.size.x / 2.0
		var warn_y := rect.position.y - 14.0
		draw_string(
			ThemeDB.fallback_font, Vector2(warn_x - 3, warn_y),
			"!", HORIZONTAL_ALIGNMENT_CENTER, -1, ThemeDB.fallback_font_size, Color(1.0, 0.3, 0.2, 0.9)
		)

func reset() -> void:
	_fall_state = FallState.IDLE
	position = _original_position
	_fallen_position = _original_position
	visible = true
	modulate.a = 1.0
	_respawn_progress = 1.0
	_collision_shape.disabled = false
	_shake_offset = Vector2.ZERO
	_warning_particles.emitting = false
