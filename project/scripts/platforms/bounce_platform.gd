extends PlatformBase
class_name BouncePlatform

## ═══════════════════════════════════════════════════════════════════════════════
## BouncePlatform — Launches the ball upward with extra force on contact
## ═══════════════════════════════════════════════════════════════════════════════
##
## Features animated spring compression, power ring visual,
## sound effects, and configurable bounce force.

# ─── Signals ─────────────────────────────────────────────────────────────────
signal ball_bounced(ball: RigidBody2D, force: float)

# ─── Exports ─────────────────────────────────────────────────────────────────
@export_category("Bounce Settings")
@export var bounce_force: float = 800.0
@export var bounce_direction: Vector2 = Vector2.UP
@export var bounce_variation: float = 0.1
@export var charge_time: float = 0.0  ## Hold to charge, 0 = instant
@export var max_charge_multiplier: float = 2.0
@export var cooldown: float = 0.1

# ─── Internal ────────────────────────────────────────────────────────────────
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
	
	# Higher bounce physics material
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


func _draw_platform_details(rect: Rect2) -> void:
	# Spring coils
	_draw_spring(rect)
	
	# Power indicator
	_draw_power_indicator(rect)
	
	# Launch ring effect
	if _ring_scale > 0.0:
		var ring_alpha := (1.0 - _ring_scale / 2.0) * 0.5
		var ring_color := Color(1.0, 0.5, 0.3, ring_alpha)
		var ring_radius := platform_size.x / 2.0 * _ring_scale
		draw_arc(Vector2(0, -platform_size.y / 2.0), ring_radius, 0, TAU, 24, ring_color, 2.0)
	
	# Flash overlay
	if _launch_flash > 0.0:
		var flash_color := Color(1.0, 0.8, 0.6, _launch_flash * 0.3)
		draw_rect(rect, flash_color, true)


func _draw_spring(rect: Rect2) -> void:
	var spring_color := Color(1.0, 1.0, 1.0, 0.3)
	var center_x := rect.position.x + rect.size.x / 2.0
	var spring_height := rect.size.y * (1.0 - _compression * 0.3)
	var coil_height := spring_height / float(_spring_segments)
	var spring_width := rect.size.x * 0.3
	
	var top_y := rect.position.y + (rect.size.y - spring_height) / 2.0
	
	for i in range(_spring_segments):
		var y1 := top_y + i * coil_height
		var y2 := top_y + (i + 1) * coil_height
		var x_offset := spring_width * (1.0 if i % 2 == 0 else -1.0)
		
		draw_line(
			Vector2(center_x - x_offset, y1),
			Vector2(center_x + x_offset, y2),
			spring_color, 1.5
		)


func _draw_power_indicator(rect: Rect2) -> void:
	# Arrow pointing in bounce direction
	var arrow_center := Vector2(
		rect.position.x + rect.size.x / 2.0,
		rect.position.y + rect.size.y / 2.0
	)
	var arr_size := 6.0
	var arr_color := Color(1.0, 1.0, 1.0, 0.4 + _compression * 0.4)
	var dir := bounce_direction.normalized()
	
	# Triangle arrow
	var tip := arrow_center - dir * arr_size
	var left := arrow_center + dir * arr_size + Vector2(-dir.y, dir.x) * arr_size * 0.5
	var right := arrow_center + dir * arr_size - Vector2(-dir.y, dir.x) * arr_size * 0.5
	
	draw_line(tip, left, arr_color, 1.5)
	draw_line(left, right, arr_color, 1.5)
	draw_line(right, tip, arr_color, 1.5)
