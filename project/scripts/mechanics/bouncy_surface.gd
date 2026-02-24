extends StaticBody2D

## Bouncy Surface - A platform with enhanced bounce properties
## Can be used as bouncy clouds, trampolines, or springboards

@export_group("Bounce Properties")
@export var bounce_multiplier: float = 1.8  # How much to amplify the bounce
@export var min_bounce_velocity: float = 200.0  # Minimum exit velocity
@export var max_bounce_velocity: float = 1200.0  # Maximum exit velocity
@export var bounce_direction_bias: Vector2 = Vector2.ZERO  # Adds directional bias to bounces

@export_group("Visual Settings")
@export var surface_color: Color = Color(0.9, 0.95, 1.0, 0.8)
@export var glow_color: Color = Color(0.7, 0.9, 1.0, 0.4)
@export var animate_squash: bool = true
@export var idle_bounce: bool = true

# --- Internal State ---
var _time: float = 0.0
var _squash: float = 0.0  # -1 to 1, 0 = normal
var _last_bounce_time: float = -10.0

signal ball_bounced(ball: Node2D, velocity: Vector2)


func _ready() -> void:
	# Set up physics
	if not physics_material_override:
		physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = bounce_multiplier
	physics_material_override.friction = 0.1


func _process(delta: float) -> void:
	_time += delta
	
	# Animate squash recovery
	_squash = move_toward(_squash, 0.0, delta * 8.0)
	
	# Idle animation
	if idle_bounce:
		var idle := sin(_time * 2.0) * 0.05
		_squash += idle
	
	# Apply visual squash to shape
	_apply_squash()
	
	queue_redraw()


func _apply_squash() -> void:
	var visual := get_node_or_null("Visual") as ColorRect
	if visual:
		visual.scale.y = 1.0 - _squash * 0.3
		visual.scale.x = 1.0 + _squash * 0.15
		visual.position.y = _squash * 5.0


func _draw() -> void:
	var shape := get_node_or_null("CollisionShape2D")
	if not shape or not shape.shape:
		return
	
	if shape.shape is RectangleShape2D:
		var rect_size: Vector2 = shape.shape.size
		_draw_bouncy_rect(rect_size)
	elif shape.shape is CircleShape2D:
		var radius: float = shape.shape.radius
		_draw_bouncy_circle(radius)


func _draw_bouncy_rect(rect_size: Vector2) -> void:
	var squash_scale := Vector2(1.0 + _squash * 0.15, 1.0 - _squash * 0.3)
	var adjusted_size := rect_size * squash_scale
	var rect := Rect2(-adjusted_size / 2, adjusted_size)
	
	# Glow layers
	for i in range(3):
		var glow_size := adjusted_size + Vector2(i * 6, i * 6)
		var glow_rect := Rect2(-glow_size / 2, glow_size)
		var alpha := glow_color.a * (1.0 - i * 0.25)
		draw_rect(glow_rect, Color(glow_color.r, glow_color.g, glow_color.b, alpha))
	
	# Main surface
	draw_rect(rect, surface_color)
	
	# Highlight line at top
	var highlight_y := -adjusted_size.y / 2 + 3
	draw_line(
		Vector2(-adjusted_size.x / 2 + 5, highlight_y),
		Vector2(adjusted_size.x / 2 - 5, highlight_y),
		Color(1, 1, 1, 0.5), 2.0
	)
	
	# Spring coil pattern
	_draw_spring_pattern(adjusted_size)


func _draw_spring_pattern(size: Vector2) -> void:
	var coil_count := int(size.x / 30)
	var coil_width := size.x / coil_count
	var coil_height := size.y * 0.4
	
	for i in range(coil_count):
		var x := -size.x / 2 + coil_width * (i + 0.5)
		var compression := 1.0 - _squash * 0.5
		
		# Draw coil
		var points := PackedVector2Array()
		for j in range(9):
			var t := float(j) / 8.0
			var py := (t - 0.5) * coil_height * compression
			var px := sin(t * TAU * 2) * 5
			points.append(Vector2(x + px, py))
		
		for j in range(points.size() - 1):
			draw_line(points[j], points[j + 1], Color(0.6, 0.7, 0.8, 0.4), 1.5)


func _draw_bouncy_circle(radius: float) -> void:
	var squash_scale := 1.0 - _squash * 0.2
	var adjusted_radius := radius * squash_scale
	
	# Glow
	for i in range(3):
		var r := adjusted_radius + i * 4
		var alpha := glow_color.a * (1.0 - i * 0.25)
		draw_circle(Vector2.ZERO, r, Color(glow_color.r, glow_color.g, glow_color.b, alpha))
	
	# Main circle
	draw_circle(Vector2.ZERO, adjusted_radius, surface_color)
	
	# Highlight
	draw_circle(Vector2(-adjusted_radius * 0.3, -adjusted_radius * 0.3), adjusted_radius * 0.3, Color(1, 1, 1, 0.4))


# Call this from the ball's collision handler
func on_ball_collision(ball: RigidBody2D) -> void:
	var incoming_velocity := ball.linear_velocity
	var speed := incoming_velocity.length()
	
	if speed < 50:
		return
	
	# Calculate bounce velocity
	var normal := (ball.global_position - global_position).normalized()
	var reflected := incoming_velocity.bounce(normal)
	
	# Apply bounce multiplier
	var bounce_speed := clampf(speed * bounce_multiplier, min_bounce_velocity, max_bounce_velocity)
	var final_velocity := reflected.normalized() * bounce_speed
	
	# Add directional bias
	if bounce_direction_bias.length() > 0:
		final_velocity += bounce_direction_bias
	
	ball.linear_velocity = final_velocity
	
	# Trigger squash animation
	_squash = clampf(speed / 500.0, 0.3, 1.0)
	_last_bounce_time = _time
	
	ball_bounced.emit(ball, final_velocity)
	
	# Spawn bounce particles
	_spawn_bounce_particles(ball.global_position)


func _spawn_bounce_particles(pos: Vector2) -> void:
	var particles := CPUParticles2D.new()
	particles.position = to_local(pos)
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 15
	particles.lifetime = 0.4
	particles.direction = Vector2(0, -1)
	particles.spread = 60.0
	particles.initial_velocity_min = 60.0
	particles.initial_velocity_max = 150.0
	particles.gravity = Vector2(0, 200)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 4.0
	particles.color = Color(0.9, 0.95, 1.0, 0.6)
	particles.finished.connect(particles.queue_free)
	add_child(particles)


# ═══════════════════════════════════════════════════════════════════════════
# EXTENDED BOUNCE MECHANIC SYSTEM
# ═══════════════════════════════════════════════════════════════════════════

func set_bounce_multiplier(mult: float) -> void:
	"""Dynamically change bounce multiplier"""
	bounce_multiplier = clampf(mult, 0.5, 3.0)


func set_elastic_mode(enabled: bool) -> void:
	"""Enable/disable elastic bouncing (absorbs energy vs restores it)"""
	if enabled:
		set_bounce_multiplier(1.2)
	else:
		set_bounce_multiplier(0.8)


func get_last_bounce_velocity() -> Vector2:
	"""Get the velocity of the last ball that bounced"""
	return Vector2.ZERO  # Can be extended to track


func is_recently_bounced() -> bool:
	"""Check if surface bounced something recently (within 0.1s)"""
	return (_time - _last_bounce_time) < 0.1


func reset_animation() -> void:
	"""Reset all animation states"""
	_squash = 0.0
	_last_bounce_time = -10.0


# ═══════════════════════════════════════════════════════════════════════════
# SPECIAL BOUNCE TYPES
# ═══════════════════════════════════════════════════════════════════════════

func apply_trampoline_bounce(ball: RigidBody2D) -> void:
	"""Specialized bounce for trampoline-like behavior (rigid upward force)"""
	var bounce_force := 1500.0  # Fixed upward bounce force
	var horizontal_carry := ball.linear_velocity.x * 0.5  # Preserve some horizontal momentum
	ball.linear_velocity = Vector2(horizontal_carry, -bounce_force)
	_squash = 0.8
	_spawn_bounce_particles(ball.global_position)


func apply_springboard_bounce(ball: RigidBody2D, direction: Vector2 = Vector2.UP) -> void:
	"""Springboard bounce in a specific direction"""
	var force := 1800.0
	ball.linear_velocity = direction.normalized() * force
	_squash = 0.95
	_spawn_bounce_particles(ball.global_position)


func apply_soft_bounce(ball: RigidBody2D) -> void:
	"""Gentle bounce (cloud-like)"""
	var current_speed: float = ball.linear_velocity.length()
	var reduced_speed: float = max(current_speed * 0.4, 100.0)
	var normal: Vector2 = (ball.global_position - global_position).normalized()
	ball.linear_velocity = normal * reduced_speed
	_squash = 0.3
	_spawn_bounce_particles(ball.global_position)


func apply_explosive_bounce(ball: RigidBody2D) -> void:
	"""Maximum power bounce (rocket-like)"""
	var current_speed: float = ball.linear_velocity.length()
	var boosted_speed: float = min(current_speed * 2.5, 2000.0)
	var normal: Vector2 = (ball.global_position - global_position).normalized()
	ball.linear_velocity = normal * boosted_speed
	_squash = 1.0
	
	# Extra particles for explosive effect
	for _i in range(3):
		_spawn_bounce_particles(ball.global_position)


func get_bounce_quality() -> float:
	"""Return bounce quality metric (0-1) for feedback"""
	var time_since_bounce := _time - _last_bounce_time
	var quality := 1.0 - clampf(time_since_bounce / 2.0, 0.0, 1.0)
	return quality
