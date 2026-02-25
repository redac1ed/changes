extends TrapBase
class_name CrusherTrap

## ═══════════════════════════════════════════════════════════════════════════════
## CrusherTrap — Heavy block that periodically slams down
## ═══════════════════════════════════════════════════════════════════════════════
##
## Cycles: wait at top → warning flash → slam down → hold → raise back up.
## Inspired by classic 2D platformer crushers.

# ─── Exports ─────────────────────────────────────────────────────────────────
@export_category("Crusher Settings")
@export var crush_distance: float = 120.0
@export var slam_speed: float = 800.0
@export var raise_speed: float = 60.0
@export var wait_time_up: float = 2.0
@export var wait_time_down: float = 0.5
@export var warning_time: float = 0.6
@export var slam_shake: float = 12.0

# ─── State ───────────────────────────────────────────────────────────────────
enum CrusherState { UP, WARNING, SLAMMING, DOWN, RAISING }
var _state: CrusherState = CrusherState.UP
var _state_timer: float = 0.0
var _slam_progress: float = 0.0
var _impact_particles: CPUParticles2D


func _trap_ready() -> void:
	trap_type = TrapType.CRUSHER
	
	# Impact particles
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
	_state_timer -= delta
	
	match _state:
		CrusherState.UP:
			if _state_timer <= 0:
				_state = CrusherState.WARNING
				_state_timer = warning_time
		
		CrusherState.WARNING:
			# Vibrate warning
			var shake := sin(_time_elapsed * 30.0) * 2.0
			position.x = _original_position_x() + shake
			
			if _state_timer <= 0:
				_state = CrusherState.SLAMMING
				_slam_progress = 0.0
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
	
	# Update collision position
	_collision_shape.position = Vector2(0, _slam_progress)


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
	
	# Screen shake via camera
	var cam := get_viewport().get_camera_2d()
	if cam and cam.has_method("_on_impact"):
		cam._on_impact(slam_shake)


func _draw() -> void:
	if not is_active:
		return
	
	var half := trap_size / 2.0
	var offset := Vector2(0, _slam_progress)
	
	# Mount rail
	var rail_color := Color(0.4, 0.4, 0.45, 0.5)
	draw_rect(
		Rect2(Vector2(-4, 0), Vector2(8, crush_distance)),
		rail_color, true
	)
	
	# Crusher block
	var block_rect := Rect2(
		Vector2(-half.x, -half.y) + offset,
		trap_size
	)
	
	# Shadow
	draw_rect(
		Rect2(block_rect.position + Vector2(3, 3), block_rect.size),
		Color(0, 0, 0, 0.25), true
	)
	
	# Main body
	var block_color := body_color
	if _state == CrusherState.WARNING:
		# Flash red during warning
		var flash := sin(_time_elapsed * 15.0) * 0.5 + 0.5
		block_color = body_color.lerp(damage_color, flash * 0.5)
	draw_rect(block_rect, block_color, true)
	draw_rect(block_rect, body_color.darkened(0.2), false, 2.0)
	
	# Danger stripes on bottom
	var stripe_y := block_rect.position.y + block_rect.size.y - 6
	var stripe_count := int(trap_size.x / 10)
	for i in range(stripe_count):
		if i % 2 == 0:
			draw_rect(
				Rect2(Vector2(block_rect.position.x + i * 10, stripe_y), Vector2(10, 6)),
				damage_color, true
			)
	
	# Bolts
	var bolt_color := Color(0.6, 0.6, 0.65, 0.8)
	var bolt_r := 2.5
	draw_circle(block_rect.position + Vector2(8, 8), bolt_r, bolt_color)
	draw_circle(block_rect.position + Vector2(block_rect.size.x - 8, 8), bolt_r, bolt_color)
	
	# Impact flash
	if _flash_timer > 0:
		var fa := _flash_timer / 0.2
		draw_rect(
			Rect2(block_rect.position - Vector2(4, 4), block_rect.size + Vector2(8, 8)),
			Color(1.0, 0.9, 0.6, fa * 0.3), true
		)
