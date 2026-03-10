extends PlatformBase
class_name BouncePlatform

signal ball_bounced(ball: RigidBody2D, force: float)

@export_category("Bounce Settings")
@export var bounce_force: float = 800.0
@export var bounce_direction: Vector2 = Vector2.UP
@export var bounce_variation: float = 0.1
@export var charge_time: float = 0.0  ## Hold to charge, 0 = instant
@export var max_charge_multiplier: float = 2.0
@export var cooldown: float = 0.1

var _compression: float = 0.0
var _spring_segments: int = 6
var _cooldown_timer: float = 0.0
var _launch_flash: float = 0.0
var _ring_scale: float = 0.0

func _platform_ready() -> void:
	platform_type = PlatformType.BOUNCE
	platform_color = Color(0.95, 0.4, 0.35, 1.0)
	outline_color = Color(0.75, 0.25, 0.2, 1.0)
	particle_color = Color(1.0, 0.5, 0.3, 0.7)
	glow_intensity = 0.2
	glow_color = Color(1.0, 0.4, 0.3, 0.3)
	var bounce_mat := PhysicsMaterial.new()
	bounce_mat.bounce = 0.9
	bounce_mat.friction = 0.8
	physics_material_override = bounce_mat


func _platform_process(delta: float) -> void:
	# Spring recovery
	if _compression > 0.0:
		_compression = maxf(0.0, _compression - delta * 8.0)
	# Cooldown
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
	# Launch flash decay
	if _launch_flash > 0.0:
		_launch_flash -= delta * 4.0
	# Ring expansion
	if _ring_scale > 0.0:
		_ring_scale += delta * 6.0
		if _ring_scale > 2.0:
			_ring_scale = 0.0

func _on_ball_landed(ball: RigidBody2D) -> void:
	if _cooldown_timer > 0.0:
		return
	# Compress spring
	_compression = 1.0
	_cooldown_timer = cooldown
	_launch_flash = 1.0
	_ring_scale = 0.1
	# Apply bounce force
	var dir := bounce_direction.normalized()
	var variation := Vector2(
		randf_range(-bounce_variation, bounce_variation),
		randf_range(-bounce_variation, bounce_variation)
	)
	var final_dir := (dir + variation).normalized()
	# Cancel downward velocity first, then apply bounce
	if ball.linear_velocity.y > 0:
		ball.linear_velocity.y = 0
	ball.apply_central_impulse(final_dir * bounce_force)
	
	ball_bounced.emit(ball, bounce_force)
	# Squash effect
	_squash_scale = Vector2(1.15, 0.85)
	# Particles burst
	if _particles:
		_particles.direction = dir
		_particles.spread = 30.0
		_particles.initial_velocity_min = 80.0
		_particles.initial_velocity_max = 200.0
		_particles.amount = 12
		_particles.restart()
		_particles.emitting = true
