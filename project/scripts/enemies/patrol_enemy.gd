extends EnemyBase
class_name PatrolEnemy

## ═══════════════════════════════════════════════════════════════════════════════
## PatrolEnemy — Standard walking enemy with platform awareness
## ═══════════════════════════════════════════════════════════════════════════════
##
## Patrols back and forth on platforms. Turns at edges and walls.
## Can be configured with different sizes, speeds, and colors via exports.

@export_category("Patrol Behavior")
@export var idle_pause_time: float = 1.5
@export var turn_speed: float = 6.0
@export var aggro_on_sight: bool = true
@export var return_after_chase: bool = true

var _idle_timer: float = 0.0
var _turn_anim: float = 0.0
var _is_turning: bool = false
var _walk_particles: Array[Dictionary] = []
var _angry_pulse: float = 0.0


func _on_enemy_ready() -> void:
	enemy_type = EnemyType.WALKER
	if body_color == Color(0.85, 0.25, 0.2):
		body_color = Color(0.78, 0.22, 0.18)


func _process_patrol(delta: float) -> void:
	if _is_turning:
		_turn_anim -= delta * turn_speed
		velocity.x = 0
		if _turn_anim <= 0:
			_is_turning = false
		return
	
	var dir := 1.0 if facing == FacingDirection.RIGHT else -1.0
	velocity.x = dir * move_speed
	
	# Patrol boundary check
	var dist := global_position.x - _patrol_origin.x
	if abs(dist) >= patrol_distance:
		_start_turn()
	
	# Wall check
	if is_on_wall():
		_start_turn()
	
	_check_edge_ahead(delta)
	
	# Walk dust particles
	if is_on_floor() and randf() < 0.1:
		_spawn_walk_dust()


func _process_idle(delta: float) -> void:
	velocity.x = 0
	_idle_timer += delta
	if _idle_timer >= idle_pause_time:
		_idle_timer = 0.0
		state = EnemyState.PATROL


func _process_chase(delta: float) -> void:
	if not _target_ball or not is_instance_valid(_target_ball):
		if return_after_chase:
			state = EnemyState.PATROL
		else:
			state = EnemyState.IDLE
		return
	
	_angry_pulse += delta * 6.0
	
	var dir_to := sign(_target_ball.global_position.x - global_position.x)
	var new_facing := FacingDirection.RIGHT if dir_to > 0 else FacingDirection.LEFT
	if new_facing != facing:
		facing = new_facing
	
	velocity.x = dir_to * chase_speed
	
	# Distance check
	var dist := global_position.distance_to(_target_ball.global_position)
	if dist > detection_range * 1.5:
		_target_ball = null
		state = EnemyState.PATROL


func _start_turn() -> void:
	_is_turning = true
	_turn_anim = 0.3
	_flip_direction()
	state = EnemyState.IDLE
	_idle_timer = 0.0


func _spawn_walk_dust() -> void:
	var dir := 1.0 if facing == FacingDirection.RIGHT else -1.0
	_walk_particles.append({
		"x": -dir * body_size.x * 0.3,
		"y": body_size.y / 2.0,
		"vx": -dir * randf_range(10, 30),
		"vy": -randf_range(5, 15),
		"time": 0.0,
		"size": randf_range(2, 4),
	})
	if _walk_particles.size() > 8:
		_walk_particles.pop_front()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	# Update walk particles
	var i := _walk_particles.size() - 1
	while i >= 0:
		_walk_particles[i]["time"] += delta
		_walk_particles[i]["x"] += _walk_particles[i]["vx"] * delta
		_walk_particles[i]["y"] += _walk_particles[i]["vy"] * delta
		if _walk_particles[i]["time"] > 0.5:
			_walk_particles.remove_at(i)
		i -= 1


func _draw() -> void:
	super._draw()
	
	if state == EnemyState.DYING or state == EnemyState.DEAD:
		return
	
	# Walk dust
	for p in _walk_particles:
		var alpha := 1.0 - (p["time"] / 0.5)
		var c := Color(0.6, 0.55, 0.5, alpha * 0.4)
		draw_circle(Vector2(p["x"], p["y"]), p["size"] * (1.0 - p["time"]), c)
	
	# Chase anger indicator
	if state == EnemyState.CHASE:
		var anger_alpha := (sin(_angry_pulse) * 0.5 + 0.5) * 0.3
		draw_circle(Vector2.ZERO, body_size.x * 0.8, Color(1.0, 0.2, 0.1, anger_alpha))
		
		# Exclamation mark
		var ex_y := -body_size.y - 8
		draw_line(Vector2(0, ex_y - 8), Vector2(0, ex_y), Color(1, 0.3, 0.1), 2.0)
		draw_circle(Vector2(0, ex_y + 3), 1.5, Color(1, 0.3, 0.1))
