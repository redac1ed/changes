extends Node

const POOL_SIZE := 32
const MAX_ACTIVE_PARTICLES := 128

enum EffectType {
	IMPACT_SMALL,
	IMPACT_LARGE,
	EXPLOSION,
	SPARKLE,
	TRAIL,
	CONFETTI,
	DUST,
	WATER_SPLASH
}

var _pools: Dictionary = {} # Key: EffectType, Value: Array[Node2D]
var _active_particles: Array[Node2D] = []

func _ready() -> void:
	print("[ParticleManager] Initializing particle pools...")
	_initialize_pools()

func _process(delta: float) -> void:
	pass

func play(type: EffectType, position: Vector2, color: Color = Color.WHITE, direction: Vector2 = Vector2.UP) -> void:
	if not _pools.has(type):
		return
	var pool: Array = _pools[type]
	var p: CPUParticles2D = null
	for candidate in pool:
		if not candidate.emitting:
			p = candidate
			break
	if not p:
		if pool.size() < MAX_ACTIVE_PARTICLES:
			p = _create_particle_node(type)
			add_child(p)
			pool.append(p)
		else:
			return
	p.global_position = position
	p.color = color
	p.direction = direction
	p.restart()
	p.emitting = true

func create_trail(target: Node2D, color: Color = Color.WHITE) -> Line2D:
	var trail = Line2D.new()
	trail.width = 10.0
	trail.default_color = color
	trail.gradient = Gradient.new()
	trail.gradient.set_color(0, color)
	trail.gradient.set_color(1, Color(color.r, color.g, color.b, 0.0))
	var script = GDScript.new()
	script.source_code = """
extends Line2D
var target: Node2D
var length: int = 15

func _process(delta):
	if target and is_instance_valid(target):
		add_point(target.global_position)
		if points.size() > length:
			remove_point(0)
	else:
		if points.size() > 0:
			remove_point(0)
		else:
			queue_free()
"""
	trail.set_script(script)
	trail.set("target", target)
	
	get_parent().add_child(trail)
	return trail

func _initialize_pools() -> void:
	for type in EffectType.values():
		_pools[type] = []
		for i in range(5): 
			var p = _create_particle_node(type)
			add_child(p)
			_pools[type].append(p)

func _create_particle_node(type: int) -> CPUParticles2D:
	var p = CPUParticles2D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false 
	match type:
		EffectType.IMPACT_SMALL:
			p.amount = 8
			p.lifetime = 0.3
			p.spread = 180.0
			p.gravity = Vector2(0, 0)
			p.initial_velocity_min = 50.0
			p.initial_velocity_max = 100.0
			p.scale_amount_min = 2.0
			p.scale_amount_max = 4.0
		EffectType.IMPACT_LARGE:
			p.amount = 20
			p.lifetime = 0.5
			p.spread = 180.0
			p.gravity = Vector2(0, 50)
			p.initial_velocity_min = 100.0
			p.initial_velocity_max = 200.0
			p.scale_amount_min = 3.0
			p.scale_amount_max = 6.0
		EffectType.EXPLOSION:
			p.amount = 40
			p.lifetime = 0.8
			p.spread = 360.0
			p.gravity = Vector2(0, 0)
			p.initial_velocity_min = 150.0
			p.initial_velocity_max = 300.0
			p.scale_amount_min = 5.0
			p.scale_amount_max = 10.0
			p.color_ramp = Gradient.new()
			p.color_ramp.add_point(0.0, Color(1, 1, 0)) # Yellow
			p.color_ramp.add_point(0.5, Color(1, 0, 0)) # Red
			p.color_ramp.add_point(1.0, Color(0.2, 0.2, 0.2, 0)) # Smoke
		EffectType.SPARKLE:
			p.amount = 5
			p.lifetime = 0.6
			p.spread = 180.0
			p.gravity = Vector2(0, -20)
			p.initial_velocity_min = 20.0
			p.initial_velocity_max = 40.0
			p.angular_velocity_min = 100.0
			p.angular_velocity_max = 200.0
		EffectType.CONFETTI:
			p.amount = 30
			p.lifetime = 2.0
			p.spread = 60.0
			p.direction = Vector2.UP
			p.gravity = Vector2(0, 150)
			p.initial_velocity_min = 200.0
			p.initial_velocity_max = 400.0
			p.angular_velocity_min = -100.0
			p.angular_velocity_max = 100.0
			p.scale_amount_min = 3.0
			p.scale_amount_max = 5.0
			p.hue_variation_min = 0.0
			p.hue_variation_max = 1.0 # Rainbow
	return p
