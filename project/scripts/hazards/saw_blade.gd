extends TrapBase
class_name SawBlade

## ═══════════════════════════════════════════════════════════════════════════════
## SawBlade — Rotating circular blade, optionally moving on a path
## ═══════════════════════════════════════════════════════════════════════════════

# ─── Exports ─────────────────────────────────────────────────────────────────
@export_category("Saw Settings")
@export var blade_radius: float = 24.0
@export var spin_speed: float = 4.0
@export var teeth_count: int = 12
@export var moves: bool = false
@export var move_distance: float = 150.0
@export var move_speed: float = 60.0
@export var move_horizontal: bool = true

# ─── Internal ────────────────────────────────────────────────────────────────
var _spin_angle: float = 0.0
var _move_direction: int = 1
var _start_pos: Vector2
var _chain_particles: CPUParticles2D


func _trap_ready() -> void:
	trap_type = TrapType.SAW_BLADE
	trap_size = Vector2(blade_radius * 2, blade_radius * 2)
	_start_pos = position
	
	# Circular collision
	if _collision_shape and _collision_shape.shape:
		_collision_shape.shape = CircleShape2D.new()
		(_collision_shape.shape as CircleShape2D).radius = blade_radius - 2
	
	# Spark particles
	_chain_particles = CPUParticles2D.new()
	_chain_particles.emitting = false
	_chain_particles.one_shot = true
	_chain_particles.amount = 6
	_chain_particles.lifetime = 0.3
	_chain_particles.direction = Vector2.UP
	_chain_particles.spread = 90.0
	_chain_particles.gravity = Vector2(0, 200)
	_chain_particles.initial_velocity_min = 50.0
	_chain_particles.initial_velocity_max = 120.0
	_chain_particles.scale_amount_min = 1.0
	_chain_particles.scale_amount_max = 2.0
	_chain_particles.color = Color(1.0, 0.8, 0.3, 0.8)
	add_child(_chain_particles)


func _trap_process(delta: float) -> void:
	_spin_angle += spin_speed * delta
	
	if moves:
		_process_movement(delta)


func _process_movement(delta: float) -> void:
	var move_vec := Vector2.RIGHT if move_horizontal else Vector2.DOWN
	position += move_vec * _move_direction * move_speed * delta
	
	var dist := position.distance_to(_start_pos)
	if dist >= move_distance:
		_move_direction *= -1


func _draw() -> void:
	if not is_active:
		_draw_inactive()
		return
	
	var center := Vector2.ZERO
	
	# Shadow
	draw_circle(center + Vector2(2, 3), blade_radius, Color(0, 0, 0, 0.2))
	
	# Outer teeth ring
	for i in range(teeth_count):
		var angle := _spin_angle + i * (TAU / teeth_count)
		var next_angle := angle + (TAU / teeth_count) * 0.4
		
		var outer_p := center + Vector2(cos(angle), sin(angle)) * blade_radius
		var inner_p := center + Vector2(cos(angle), sin(angle)) * (blade_radius * 0.7)
		var next_inner := center + Vector2(cos(next_angle), sin(next_angle)) * (blade_radius * 0.7)
		
		var tooth := PackedVector2Array([inner_p, outer_p, next_inner])
		draw_colored_polygon(tooth, damage_color)
	
	# Inner disc
	draw_circle(center, blade_radius * 0.7, body_color)
	draw_arc(center, blade_radius * 0.7, 0, TAU, 24, body_color.darkened(0.15), 2.0)
	
	# Center hole
	draw_circle(center, blade_radius * 0.15, Color(0.3, 0.3, 0.35, 1.0))
	draw_circle(center, blade_radius * 0.08, Color(0.5, 0.5, 0.55, 1.0))
	
	# Highlight
	var highlight_angle := _spin_angle * 0.5
	var hl_pos := center + Vector2(cos(highlight_angle), sin(highlight_angle)) * blade_radius * 0.4
	draw_circle(hl_pos, 2.0, Color(1.0, 1.0, 1.0, 0.3))
	
	# Flash on kill
	if _flash_timer > 0:
		var flash_alpha := _flash_timer / 0.3
		draw_circle(center, blade_radius + 4, Color(1.0, 0.3, 0.2, flash_alpha * 0.3))
