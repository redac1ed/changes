extends Node

## Centralized particle effect manager with pooling and presets
## Provides reusable particle systems for impacts, trails, power-ups, etc.

# ═══════════════════════════════════════════════════════════════════════════
# PRESET DEFINITIONS
# ═══════════════════════════════════════════════════════════════════════════

class ParticlePreset:
	"""Preset configuration for particle effects"""
	var name: String
	var lifetime: float = 0.6
	var amount: int = 20
	var speed_min: float = 80.0
	var speed_max: float = 200.0
	var spread: float = 180.0
	var explosiveness: float = 0.8
	var gravity: Vector2 = Vector2(0, 200)
	var color: Color = Color.WHITE
	var scale_min: float = 1.0
	var scale_max: float = 3.0
	var rotation_speed: float = 0.0
	var damping: float = 0.0
	
	func _init(p_name: String) -> void:
		name = p_name


static var PRESETS: Dictionary = {
	"bounce_impact": {
		"lifetime": 0.5,
		"amount": 15,
		"speed_min": 100.0,
		"speed_max": 250.0,
		"spread": 180.0,
		"explosiveness": 0.9,
		"color": Color(1.0, 0.8, 0.4),
	},
	"goal_celebration": {
		"lifetime": 1.2,
		"amount": 40,
		"speed_min": 150.0,
		"speed_max": 350.0,
		"spread": 360.0,
		"explosiveness": 0.7,
		"color": Color(0.2, 1.0, 0.8),
		"scale_min": 2.0,
		"scale_max": 4.0,
	},
	"lava_splash": {
		"lifetime": 0.8,
		"amount": 25,
		"speed_min": 120.0,
		"speed_max": 300.0,
		"spread": 140.0,
		"explosiveness": 0.85,
		"color": Color(1.0, 0.4, 0.2),
		"gravity": Vector2(0, 400),
	},
	"water_ripple": {
		"lifetime": 1.0,
		"amount": 30,
		"speed_min": 80.0,
		"speed_max": 200.0,
		"spread": 180.0,
		"explosiveness": 0.6,
		"color": Color(0.4, 0.8, 1.0),
		"gravity": Vector2(0, -100),
		"damping": 0.98,
	},
	"wind_burst": {
		"lifetime": 0.7,
		"amount": 20,
		"speed_min": 200.0,
		"speed_max": 400.0,
		"spread": 60.0,
		"explosiveness": 0.75,
		"color": Color(0.7, 0.7, 0.9),
		"gravity": Vector2(0, -50),
	},
	"gravity_warp": {
		"lifetime": 1.5,
		"amount": 35,
		"speed_min": 60.0,
		"speed_max": 180.0,
		"spread": 360.0,
		"explosiveness": 0.5,
		"color": Color(1.0, 0.4, 1.0),
		"scale_min": 1.5,
		"scale_max": 3.0,
		"gravity": Vector2(0, 0),
	},
	"collected_star": {
		"lifetime": 0.6,
		"amount": 25,
		"speed_min": 100.0,
		"speed_max": 250.0,
		"spread": 360.0,
		"explosiveness": 0.8,
		"color": Color(1.0, 0.9, 0.3),
		"scale_min": 2.0,
		"scale_max": 5.0,
	},
	"shield_hit": {
		"lifetime": 0.4,
		"amount": 20,
		"speed_min": 150.0,
		"speed_max": 300.0,
		"spread": 180.0,
		"explosiveness": 0.9,
		"color": Color(0.4, 0.8, 1.0),
		"scale_min": 1.0,
		"scale_max": 2.5,
	},
	"power_up_glow": {
		"lifetime": 1.0,
		"amount": 30,
		"speed_min": 50.0,
		"speed_max": 150.0,
		"spread": 360.0,
		"explosiveness": 0.5,
		"color": Color(1.0, 0.5, 1.0),
		"scale_min": 1.5,
		"scale_max": 3.0,
		"gravity": Vector2(0, -80),
	},
}

# --- State ---
var _particle_pool: Dictionary = {}  # Pool of available particle emitters
var _active_particles: Array[CPUParticles2D] = []
var _pool_size: int = 20  # Reusable particles per preset


func _ready() -> void:
	print("[ParticleManager] Initializing with %d presets" % PRESETS.size())
	_initialize_pools()


func _initialize_pools() -> void:
	"""Pre-create particle emitters for pooling"""
	for preset_name in PRESETS.keys():
		var pool: Array[CPUParticles2D] = []
		
		for i in range(_pool_size):
			var particles := _create_particle_emitter(preset_name)
			pool.append(particles)
		
		_particle_pool[preset_name] = pool
	
	print("[ParticleManager] Pre-allocated pools complete")


func _create_particle_emitter(preset_name: String) -> CPUParticles2D:
	"""Create a new particle emitter with preset settings"""
	if not PRESETS.has(preset_name):
		push_error("[ParticleManager] Invalid preset: %s" % preset_name)
		return CPUParticles2D.new()
	
	var preset: Dictionary = PRESETS[preset_name]
	var particles := CPUParticles2D.new()
	
	particles.lifetime = preset.get("lifetime", 0.6)
	particles.amount = preset.get("amount", 20)
	particles.initial_velocity_min = preset.get("speed_min", 80.0)
	particles.initial_velocity_max = preset.get("speed_max", 200.0)
	particles.spread = preset.get("spread", 180.0)
	particles.explosiveness = preset.get("explosiveness", 0.8)
	particles.gravity = preset.get("gravity", Vector2(0, 200))
	particles.color = preset.get("color", Color.WHITE)
	particles.scale_amount_min = preset.get("scale_min", 1.0)
	particles.scale_amount_max = preset.get("scale_max", 3.0)
	particles.one_shot = true
	particles.emitting = false
	
	return particles


# ═══════════════════════════════════════════════════════════════════════════
# EMISSION INTERFACE
# ═══════════════════════════════════════════════════════════════════════════

func emit_at(preset: String, position: Vector2) -> void:
	"""Emit particles at specified position"""
	if not _particle_pool.has(preset):
		push_error("[ParticleManager] No pool for preset: %s" % preset)
		return
	
	var pool: Array[CPUParticles2D] = _particle_pool[preset]
	var particles: CPUParticles2D
	
	# Get from pool or create new
	if pool.is_empty():
		particles = _create_particle_emitter(preset)
	else:
		particles = pool.pop_back()
	
	# Reset and position
	particles.global_position = position
	particles.emitting = false
	particles.restart()
	particles.emitting = true
	
	# Track active
	_active_particles.append(particles)
	
	# Add to scene
	if not particles.is_inside_tree():
		get_parent().add_child(particles)
	
	# Return to pool when done
	particles.finished.connect(func():
		if particles in _active_particles:
			_active_particles.erase(particles)
		if pool.size() < _pool_size:
			pool.append(particles)
	)


func emit_burst(preset: String, position: Vector2, direction: Vector2 = Vector2.ZERO, radius: float = 0.0) -> void:
	"""Emit particles in directional burst"""
	if radius > 0:
		# Multi-point burst in radius
		var angle_step := TAU / 6.0
		for i in range(6):
			var angle := angle_step * i
			var offset := Vector2(cos(angle), sin(angle)) * radius
			emit_at(preset, position + offset)
	else:
		emit_at(preset, position)
	
	# Optional directional override
	if direction.length() > 0 and _active_particles.size() > 0:
		var last_particle := _active_particles[-1]
		# Adjust direction (CPUParticles2D doesn't have direct velocity override in 4.x)
		# Workaround: rotate emitter
		last_particle.rotation = direction.angle()


func emit_trail(preset: String, points: PackedVector2Array) -> void:
	"""Emit particles along a path (trail effect)"""
	var step: int = max(1, points.size() / 10)  # Sample 10 points max
	
	for i in range(0, points.size(), step):
		await get_tree().process_frame
		emit_at(preset, points[i])


func emit_explosion(position: Vector2, intensity: float = 1.0) -> void:
	"""Emit multiple effects in sequence for explosion-like effect"""
	var presets := ["bounce_impact", "wind_burst"]
	
	for preset in presets:
		var particles := _create_particle_emitter(preset)
		particles.global_position = position
		particles.amount = int(particles.amount * intensity)
		particles.initial_velocity_max *= sqrt(intensity)
		particles.one_shot = true
		particles.emitting = true
		get_parent().add_child(particles)
		particles.finished.connect(particles.queue_free)


# ═══════════════════════════════════════════════════════════════════════════
# ADVANCED EFFECTS
# ═══════════════════════════════════════════════════════════════════════════

func create_collision_effect(impact_position: Vector2, impact_force: float) -> void:
	"""Create dynamic collision effect based on impact force"""
	var intensity: float = clampf(impact_force / 500.0, 0.5, 3.0)
	
	# Select preset based on force
	var preset: String = "bounce_impact" if impact_force < 300 else "wind_burst"
	
	var particles := _create_particle_emitter(preset)
	particles.global_position = impact_position
	particles.amount = int(particles.amount * intensity)
	particles.initial_velocity_max *= sqrt(intensity)
	particles.explosiveness = clampf(particles.explosiveness + intensity * 0.1, 0.5, 1.0)
	particles.one_shot = true
	particles.emitting = true
	get_parent().add_child(particles)
	particles.finished.connect(particles.queue_free)


func create_movement_trail(start_pos: Vector2, end_pos: Vector2, duration: float = 0.3) -> void:
	"""Create trail between two points"""
	var distance := start_pos.distance_to(end_pos)
	var point_count := int(distance / 30.0)
	var points := PackedVector2Array()
	
	for i in range(point_count):
		var t := float(i) / point_count
		points.append(start_pos.lerp(end_pos, t))
	
	emit_trail("water_ripple", points)


func create_swirl_effect(center: Vector2, radius: float, particle_count: int = 12) -> void:
	"""Create swirling particle pattern around center"""
	for i in range(particle_count):
		var angle := float(i) / particle_count * TAU
		var pos := center + Vector2(cos(angle), sin(angle)) * radius
		emit_at("gravity_warp", pos)


func create_ring_explosion(center: Vector2, radius: float = 100.0, count: int = 16) -> void:
	"""Create ring-shaped particle explosion"""
	for i in range(count):
		var angle := float(i) / count * TAU
		var direction := Vector2(cos(angle), sin(angle))
		var pos := center + direction * radius * 0.3
		
		var particles := _create_particle_emitter("goal_celebration")
		particles.global_position = pos
		particles.one_shot = true
		particles.emitting = true
		get_parent().add_child(particles)
		particles.finished.connect(particles.queue_free)


# ═══════════════════════════════════════════════════════════════════════════
# UTILITY & QUERY METHODS
# ═══════════════════════════════════════════════════════════════════════════

func get_active_particle_count() -> int:
	"""Return number of active particle emitters"""
	return _active_particles.size()


func get_pool_stats() -> Dictionary:
	"""Return pool status for all presets"""
	var stats := {}
	for preset in _particle_pool.keys():
		var pool: Array[CPUParticles2D] = _particle_pool[preset]
		stats[preset] = {
			"available": pool.size(),
			"capacity": _pool_size,
			"utilization": 1.0 - (float(pool.size()) / _pool_size),
		}
	return stats


func clear_all_active() -> void:
	"""Stop and clear all active particles"""
	for particle in _active_particles:
		particle.emitting = false
	_active_particles.clear()
	print("[ParticleManager] Cleared all active particles")


func has_preset(preset_name: String) -> bool:
	"""Check if preset exists"""
	return PRESETS.has(preset_name)


func get_available_presets() -> PackedStringArray:
	"""Get list of all available presets"""
	return PackedStringArray(PRESETS.keys())


func add_custom_preset(name: String, config: Dictionary) -> void:
	"""Register custom particle preset at runtime"""
	PRESETS[name] = config
	_particle_pool[name] = []
	
	# Initialize pool for new preset
	for i in range(_pool_size):
		var particles := _create_particle_emitter(name)
		_particle_pool[name].append(particles)
	
	print("[ParticleManager] Added custom preset: %s" % name)


func modify_preset(name: String, property: String, value: float) -> void:
	"""Modify preset property at runtime"""
	if not PRESETS.has(name):
		push_error("[ParticleManager] Unknown preset: %s" % name)
		return
	
	PRESETS[name][property] = value
	print("[ParticleManager] Modified %s.%s = %s" % [name, property, value])
