extends Area2D
class_name TrapBase

## ═══════════════════════════════════════════════════════════════════════════════
## TrapBase — Foundation class for all hazards/traps
## ═══════════════════════════════════════════════════════════════════════════════
##
## Provides shared functionality for spike strips, saw blades, fire jets,
## and other hazards. Handles ball detection, death triggering, visual
## feedback, and respawn management.

# ─── Signals ─────────────────────────────────────────────────────────────────
signal ball_killed(ball: RigidBody2D)
signal trap_activated()
signal trap_deactivated()

# ─── Enums ───────────────────────────────────────────────────────────────────
enum TrapType {
	SPIKE,       ## Static sharp points
	SAW_BLADE,   ## Rotating circular blade
	FIRE_JET,    ## Periodic fire burst
	LASER,       ## Continuous beam
	CRUSHER,     ## Vertical or horizontal press
	ACID_POOL,   ## Dissolving liquid
}

# ─── Exports ─────────────────────────────────────────────────────────────────
@export_category("Trap Properties")
@export var trap_type: TrapType = TrapType.SPIKE
@export var trap_size: Vector2 = Vector2(64, 24)
@export var damage_color: Color = Color(0.95, 0.2, 0.15, 1.0)
@export var body_color: Color = Color(0.5, 0.5, 0.55, 1.0)
@export var is_lethal: bool = true
@export var is_active: bool = true
@export var activation_delay: float = 0.0

@export_category("Death Effect")
@export var death_particle_count: int = 16
@export var screen_shake_intensity: float = 8.0
@export var respawn_delay: float = 0.8
@export var death_slowmo_duration: float = 0.15
@export var death_slowmo_scale: float = 0.3

# ─── Internal ────────────────────────────────────────────────────────────────
var _collision_shape: CollisionShape2D
var _time_elapsed: float = 0.0
var _death_particles: CPUParticles2D
var _flash_timer: float = 0.0
var _activation_timer: float = 0.0
var _warning_alpha: float = 0.0


func _ready() -> void:
	_setup_collision()
	_setup_death_particles()
	
	collision_layer = 0
	collision_mask = 1  # Detect ball
	
	body_entered.connect(_on_body_entered)
	
	if activation_delay > 0:
		is_active = false
		_activation_timer = activation_delay
	
	_trap_ready()


func _process(delta: float) -> void:
	_time_elapsed += delta
	
	# Activation delay
	if _activation_timer > 0:
		_activation_timer -= delta
		if _activation_timer <= 0:
			is_active = true
			trap_activated.emit()
	
	# Flash decay
	if _flash_timer > 0:
		_flash_timer -= delta
	
	_trap_process(delta)
	queue_redraw()


func _setup_collision() -> void:
	_collision_shape = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = trap_size
	_collision_shape.shape = shape
	add_child(_collision_shape)


func _setup_death_particles() -> void:
	_death_particles = CPUParticles2D.new()
	_death_particles.emitting = false
	_death_particles.one_shot = true
	_death_particles.amount = death_particle_count
	_death_particles.lifetime = 0.6
	_death_particles.explosiveness = 0.9
	_death_particles.direction = Vector2.UP
	_death_particles.spread = 180.0
	_death_particles.gravity = Vector2(0, 400)
	_death_particles.initial_velocity_min = 100.0
	_death_particles.initial_velocity_max = 250.0
	_death_particles.scale_amount_min = 2.0
	_death_particles.scale_amount_max = 4.0
	_death_particles.color = damage_color
	add_child(_death_particles)


func _on_body_entered(body: Node2D) -> void:
	if not is_active:
		return
	if body is RigidBody2D:
		_kill_ball(body)


func _kill_ball(ball: RigidBody2D) -> void:
	# Death particles
	_death_particles.restart()
	_death_particles.emitting = true
	_flash_timer = 0.3
	
	# Slow-motion effect
	if death_slowmo_duration > 0:
		Engine.time_scale = death_slowmo_scale
		await get_tree().create_timer(death_slowmo_duration * death_slowmo_scale).timeout
		Engine.time_scale = 1.0
	
	ball_killed.emit(ball)
	
	# Find spawn point and respawn
	var level := _find_level_root()
	if level:
		var spawn: Node = level.get_node_or_null("BallSpawn")
		if spawn:
			# Death tween on ball
			var tw := create_tween()
			tw.tween_property(ball, "scale", Vector2.ZERO, 0.15)
			tw.parallel().tween_property(ball, "modulate:a", 0.0, 0.15)
			await tw.finished
			
			# Respawn
			ball.linear_velocity = Vector2.ZERO
			ball.angular_velocity = 0.0
			ball.global_position = spawn.global_position
			ball.scale = Vector2.ONE
			ball.modulate.a = 1.0
			
			# Respawn tween
			var tw2 := create_tween()
			tw2.tween_property(ball, "scale", Vector2(1.2, 1.2), 0.1)
			tw2.tween_property(ball, "scale", Vector2.ONE, 0.1)


func _find_level_root() -> Node:
	var node: Node = get_parent()
	while node:
		if node.has_node("BallSpawn"):
			return node
		node = node.get_parent()
	return null


# ─── Drawing ─────────────────────────────────────────────────────────────────

func _draw() -> void:
	if not is_active:
		_draw_inactive()
		return
	
	match trap_type:
		TrapType.SPIKE:
			_draw_spikes()
		TrapType.SAW_BLADE:
			_draw_saw_blade()
		TrapType.FIRE_JET:
			_draw_fire_jet()
		TrapType.LASER:
			_draw_laser()
		TrapType.CRUSHER:
			_draw_crusher()
		TrapType.ACID_POOL:
			_draw_acid_pool()
	
	# Flash overlay on kill
	if _flash_timer > 0:
		var flash_alpha := _flash_timer / 0.3
		draw_rect(
			Rect2(-trap_size / 2.0, trap_size),
			Color(1.0, 0.3, 0.2, flash_alpha * 0.4), true
		)


func _draw_inactive() -> void:
	var half := trap_size / 2.0
	var rect := Rect2(-half, trap_size)
	draw_rect(rect, Color(body_color.r, body_color.g, body_color.b, 0.3), true)
	draw_rect(rect, Color(0.5, 0.5, 0.5, 0.2), false, 1.0)


func _draw_spikes() -> void:
	var half := trap_size / 2.0
	
	# Base
	var base_height := trap_size.y * 0.35
	var base_rect := Rect2(
		Vector2(-half.x, half.y - base_height),
		Vector2(trap_size.x, base_height)
	)
	draw_rect(base_rect, body_color, true)
	draw_rect(base_rect, body_color.darkened(0.2), false, 1.0)
	
	# Spike triangles
	var spike_count := int(trap_size.x / 12.0)
	var spike_width := trap_size.x / float(spike_count)
	var spike_height := trap_size.y * 0.65
	
	for i in range(spike_count):
		var spike_x := -half.x + i * spike_width
		var spike_base_y := half.y - base_height
		var spike_tip_y := -half.y
		
		var points := PackedVector2Array([
			Vector2(spike_x, spike_base_y),
			Vector2(spike_x + spike_width / 2.0, spike_tip_y),
			Vector2(spike_x + spike_width, spike_base_y),
		])
		draw_colored_polygon(points, damage_color)
		
		# Highlight on spike
		var highlight := Color(1.0, 1.0, 1.0, 0.2)
		draw_line(
			Vector2(spike_x + spike_width * 0.3, spike_base_y - spike_height * 0.3),
			Vector2(spike_x + spike_width / 2.0, spike_tip_y),
			highlight, 1.0
		)


func _draw_saw_blade() -> void:
	var radius := minf(trap_size.x, trap_size.y) / 2.0 - 2
	var center := Vector2.ZERO
	var teeth := 12
	var rot := _time_elapsed * 4.0  # Spinning
	
	# Outer ring with teeth
	for i in range(teeth):
		var angle := rot + i * (TAU / teeth)
		var next_angle := angle + (TAU / teeth) * 0.5
		
		var outer_r := radius
		var inner_r := radius * 0.75
		
		var p1 := center + Vector2(cos(angle), sin(angle)) * outer_r
		var p2 := center + Vector2(cos(next_angle), sin(next_angle)) * inner_r
		
		draw_line(center + Vector2(cos(angle), sin(angle)) * inner_r, p1, damage_color, 2.0)
		draw_line(p1, p2, damage_color, 2.0)
	
	# Inner circle
	draw_arc(center, inner_r_val(radius), 0, TAU, 24, body_color, 3.0)
	draw_circle(center, radius * 0.25, body_color)
	
	# Center bolt
	draw_circle(center, 3.0, Color(0.7, 0.7, 0.7, 0.8))


func inner_r_val(radius: float) -> float:
	return radius * 0.75


func _draw_fire_jet() -> void:
	var half := trap_size / 2.0
	
	# Nozzle
	var nozzle_rect := Rect2(
		Vector2(-half.x, 0),
		Vector2(trap_size.x, half.y)
	)
	draw_rect(nozzle_rect, body_color, true)
	
	# Fire burst (animated)
	var fire_phase := fmod(_time_elapsed, 2.0)
	if fire_phase < 1.0:  # Active phase
		var fire_height := half.y * (0.5 + sin(fire_phase * PI) * 0.5)
		var fire_width := trap_size.x * 0.6
		
		# Flame layers
		for layer in range(3):
			var layer_h := fire_height * (1.0 - layer * 0.25)
			var layer_w := fire_width * (1.0 - layer * 0.2)
			var layer_color: Color
			match layer:
				0: layer_color = damage_color
				1: layer_color = Color(1.0, 0.5, 0.1, 0.7)
				2: layer_color = Color(1.0, 0.9, 0.3, 0.5)
				_: layer_color = damage_color
			
			var flame_points := PackedVector2Array([
				Vector2(-layer_w / 2.0, 0),
				Vector2(0, -layer_h),
				Vector2(layer_w / 2.0, 0),
			])
			draw_colored_polygon(flame_points, layer_color)


func _draw_laser() -> void:
	var half := trap_size / 2.0
	
	# Emitter boxes
	var emitter_size := Vector2(8, trap_size.y)
	draw_rect(Rect2(Vector2(-half.x, -half.y), emitter_size), body_color, true)
	draw_rect(Rect2(Vector2(half.x - 8, -half.y), emitter_size), body_color, true)
	
	# Laser beam
	var beam_pulse := 0.8 + sin(_time_elapsed * 8.0) * 0.2
	var beam_color := Color(damage_color.r, damage_color.g, damage_color.b, beam_pulse)
	var beam_height := 4.0
	draw_rect(
		Rect2(Vector2(-half.x + 8, -beam_height / 2.0), Vector2(trap_size.x - 16, beam_height)),
		beam_color, true
	)
	
	# Glow around beam
	var glow := Color(damage_color.r, damage_color.g, damage_color.b, 0.15 * beam_pulse)
	draw_rect(
		Rect2(Vector2(-half.x + 8, -beam_height * 2), Vector2(trap_size.x - 16, beam_height * 4)),
		glow, true
	)
	
	# Emitter lights
	draw_circle(Vector2(-half.x + 4, 0), 2.0, damage_color)
	draw_circle(Vector2(half.x - 4, 0), 2.0, damage_color)


func _draw_crusher() -> void:
	var half := trap_size / 2.0
	
	# Heavy block
	draw_rect(Rect2(-half, trap_size), body_color, true)
	draw_rect(Rect2(-half, trap_size), body_color.darkened(0.2), false, 2.0)
	
	# Danger stripes
	var stripe_count := int(trap_size.x / 10)
	for i in range(stripe_count):
		if i % 2 == 0:
			var stripe_x := -half.x + i * 10
			draw_rect(
				Rect2(Vector2(stripe_x, half.y - 6), Vector2(10, 6)),
				damage_color, true
			)
	
	# Impact spikes at bottom
	var spike_count := int(trap_size.x / 16)
	for i in range(spike_count):
		var sx := -half.x + i * 16 + 8
		draw_line(
			Vector2(sx, half.y),
			Vector2(sx, half.y + 5),
			damage_color, 2.0
		)


func _draw_acid_pool() -> void:
	var half := trap_size / 2.0
	
	# Pool body
	var pool_color := Color(0.3, 0.8, 0.2, 0.8)
	draw_rect(Rect2(-half, trap_size), pool_color, true)
	
	# Surface bubbles
	var bubble_count := int(trap_size.x / 20)
	for i in range(bubble_count):
		var bx := -half.x + (i + 0.5) * (trap_size.x / bubble_count)
		var by := -half.y + sin(_time_elapsed * 2.0 + i * 1.5) * 3.0
		var br := 2.0 + sin(_time_elapsed * 3.0 + i) * 1.0
		draw_circle(Vector2(bx, by), br, Color(0.4, 0.9, 0.3, 0.6))
	
	# Surface line
	draw_line(
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Color(0.5, 1.0, 0.3, 0.9), 2.0
	)


# ─── Virtual Methods ────────────────────────────────────────────────────────

func _trap_ready() -> void:
	pass

func _trap_process(_delta: float) -> void:
	pass

# ─── Public API ──────────────────────────────────────────────────────────────

func activate() -> void:
	is_active = true
	trap_activated.emit()

func deactivate() -> void:
	is_active = false
	trap_deactivated.emit()

func set_trap_size(new_size: Vector2) -> void:
	trap_size = new_size
	if _collision_shape and _collision_shape.shape is RectangleShape2D:
		(_collision_shape.shape as RectangleShape2D).size = new_size
