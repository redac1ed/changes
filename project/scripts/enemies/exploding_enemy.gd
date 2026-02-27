extends EnemyBase
class_name ExplodingEnemy

## ═══════════════════════════════════════════════════════════════════════════════
## ExplodingEnemy — Self-destructs when near player
## ═══════════════════════════════════════════════════════════════════════════════
##
## Volatile enemy type. Does massive damage in an area upon death or timer.
## Has a pulsing warning animation before detonation.

@export_category("Explosion Settings")
@export var explosion_radius: float = 120.0
@export var explosion_damage: int = 3
@export var fuse_time: float = 2.0
@export var blast_force: float = 1000.0

var _fuse_active: bool = false
var _fuse_timer: float = 0.0
var _pulse_tween: Tween

func _ready() -> void:
	super._ready()
	body_color = Color(0.9, 0.4, 0.1)
	enemy_type = EnemyType.CHARGER
	damage = 2

func _process(delta: float) -> void:
	# super._process(delta) # Base class does not define _process
	
	if state == EnemyState.DEAD:
		return
	
	if _fuse_active:
		_fuse_timer -= delta
		if _fuse_timer <= 0:
			explode()
			return
		
		# Flash faster as timer decreases
		var flash_rate = 1.0 - (_fuse_timer / fuse_time)
		modulate = Color(1.0 + flash_rate, 1.0 - flash_rate, 1.0 - flash_rate)

	# Check player distance to start fuse
	if _target_ball and not _fuse_active:
		var dist = global_position.distance_to(_target_ball.global_position)
		if dist < detection_range * 0.6:
			start_fuse()

func start_fuse() -> void:
	if _fuse_active: return
	_fuse_active = true
	_fuse_timer = fuse_time
	state = EnemyState.ATTACK # Stops moving or changes behavior
	
	# Visual indicator
	var label = Label.new()
	label.text = "!"
	label.add_theme_color_override("font_color", Color.RED)
	label.add_theme_font_size_override("font_size", 32)
	label.position = Vector2(-10, -50)
	add_child(label)
	
	# Sound
	if AudioManager:
		AudioManager.play_sfx_at_position("fuse_hiss", global_position)

func explode() -> void:
	if state == EnemyState.DEAD: return
	die() # Base death
	
	# Spawn explosion effect
	if ParticleManager:
		ParticleManager.play(ParticleManager.EffectType.EXPLOSION, global_position)
	
	# Area damage
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = explosion_radius
	query.shape = shape
	query.transform = global_transform
	query.collision_mask = 1 + 2 # Player + Enemies?
	
	var results = space_state.intersect_shape(query)
	for result in results:
		var collider = result.collider
		if collider is RigidBody2D:
			var dir = (collider.global_position - global_position).normalized()
			collider.apply_impulse(dir * blast_force)
			# Apply damage if player has health (assuming player script supports it)
			if collider.has_method("take_damage"):
				collider.take_damage(explosion_damage)
				
	# Sound
	if AudioManager:
		AudioManager.play_sfx_at_position("explosion_large", global_position)
	
	queue_free()

func die() -> void:
	# Override base die to ensure explosion happens
	super._die()
	explode()
