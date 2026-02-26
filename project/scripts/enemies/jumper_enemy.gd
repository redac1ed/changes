extends EnemyBase
class_name JumperEnemy

## ═══════════════════════════════════════════════════════════════════════════════
## JumperEnemy — Hops around unpredictably
## ═══════════════════════════════════════════════════════════════════════════════
##
## Waits for a moment, then launches itself into the air.
## Can be dangerous to approach from above if timing is wrong.

@export_category("Jumper Settings")
@export var jump_force: float = 400.0
@export var jump_interval_min: float = 1.0
@export var jump_interval_max: float = 3.0
@export var jump_horizontal_speed: float = 100.0

var _jump_timer: float = 0.0
var _is_grounded: bool = false

func _ready() -> void:
	super._ready()
	_reset_jump_timer()
	body_color = Color(0.4, 0.8, 0.2) # Greenish for jumping
	enemy_type = EnemyType.BOUNCER


func _process_state(delta: float) -> void:
	# Override base behavior
	if state == EnemyState.DEAD or state == EnemyState.DYING:
		return
	
	_is_grounded = is_on_floor()
	
	match state:
		EnemyState.IDLE:
			velocity.x = move_toward(velocity.x, 0, delta * 400.0)
			_jump_timer -= delta
			if _jump_timer <= 0:
				_jump()
				
		EnemyState.CHASE:
			# Aggressive jumping if player is near
			velocity.x = move_toward(velocity.x, 0, delta * 400.0)
			_jump_timer -= delta * 1.5 # Faster jumps
			if _jump_timer <= 0:
				_jump_towards_player()


func _physics_process(delta: float) -> void:
	# Apply gravity
	velocity.y += gravity_force * delta
	move_and_slide()
	
	# Transition to IDLE if landed
	if is_on_floor() and velocity.y >= 0:
		if state == EnemyState.PATROL: # Using PATROL as "In Air" state effectively
			state = EnemyState.IDLE
			velocity.x = 0
	else:
		if state == EnemyState.IDLE:
			state = EnemyState.PATROL # In air


func _jump() -> void:
	if not is_on_floor(): return
	
	velocity.y = -jump_force
	# Random direction
	var dir = 1 if randf() > 0.5 else -1
	velocity.x = dir * jump_horizontal_speed
	
	_reset_jump_timer()
	
	# Squish effect
	var tw = create_tween()
	scale = Vector2(1.3, 0.7)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_ELASTIC)


func _jump_towards_player() -> void:
	if not is_on_floor(): return
	if not _target_player: return
	
	velocity.y = -jump_force * 1.2 # Higher jump
	
	var dir = sign(_target_player.global_position.x - global_position.x)
	velocity.x = dir * jump_horizontal_speed * 1.5
	
	_reset_jump_timer()


func _reset_jump_timer() -> void:
	_jump_timer = randf_range(jump_interval_min, jump_interval_max)
