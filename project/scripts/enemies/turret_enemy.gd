extends EnemyBase
class_name TurretEnemy

## ═══════════════════════════════════════════════════════════════════════════════
## TurretEnemy — Stationary turret that fires projectiles at the ball
## ═══════════════════════════════════════════════════════════════════════════════
##
## Does not move. Rotates barrel toward detected ball and fires
## projectile bursts at regular intervals. Projectiles are drawn
## as energy shots.

@export_category("Turret Settings")
@export var fire_rate: float = 2.0
@export var projectile_speed: float = 250.0
@export var projectile_damage: int = 1
@export var max_projectiles: int = 5
@export var barrel_length: float = 18.0
@export var projectile_color: Color = Color(1.0, 0.4, 0.15)
@export var projectile_size: float = 4.0

var _fire_timer: float = 0.0
var _barrel_angle: float = 0.0
var _target_angle: float = 0.0
var _projectiles: Array[Dictionary] = []
var _muzzle_flash: float = 0.0
var _detection_sweep: float = 0.0


func _on_enemy_ready() -> void:
	enemy_type = EnemyType.TURRET
	move_speed = 0.0
	body_color = Color(0.45, 0.45, 0.5)
	body_size = Vector2(28, 28)
	points_value = 250
	health = 3
	max_health = 3
	detection_range = 320.0


func _process_idle(_delta: float) -> void:
	# Turrets don't patrol, just scan
	_detection_sweep += _time_elapsed * 0.5
	velocity = Vector2.ZERO


func _process_patrol(delta: float) -> void:
	# Turrets treat patrol as idle scan
	velocity = Vector2.ZERO
	_detection_sweep += delta


func _process_chase(delta: float) -> void:
	velocity = Vector2.ZERO
	
	if not _target_ball or not is_instance_valid(_target_ball):
		state = EnemyState.PATROL
		return
	
	# Aim at ball
	var dir := (_target_ball.global_position - global_position).normalized()
	_target_angle = atan2(dir.y, dir.x)
	
	# Smooth barrel rotation
	var diff := _target_angle - _barrel_angle
	while diff > PI:
		diff -= TAU
	while diff < -PI:
		diff += TAU
	_barrel_angle += diff * 5.0 * delta
	
	# Fire
	_fire_timer += delta
	if _fire_timer >= fire_rate:
		_fire_timer = 0.0
		_fire_projectile()
	
	# Lose target
	var dist := global_position.distance_to(_target_ball.global_position)
	if dist > detection_range * 1.5:
		_target_ball = null
		state = EnemyState.PATROL


func _fire_projectile() -> void:
	if _projectiles.size() >= max_projectiles:
		return
	
	var muzzle := Vector2(cos(_barrel_angle), sin(_barrel_angle)) * barrel_length
	_projectiles.append({
		"x": muzzle.x,
		"y": muzzle.y,
		"vx": cos(_barrel_angle) * projectile_speed,
		"vy": sin(_barrel_angle) * projectile_speed,
		"time": 0.0,
	})
	_muzzle_flash = 0.3


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	# Muzzle flash decay
	if _muzzle_flash > 0:
		_muzzle_flash -= delta * 3.0
	
	# Update projectiles
	var i := _projectiles.size() - 1
	while i >= 0:
		var proj := _projectiles[i]
		proj["time"] += delta
		proj["x"] += proj["vx"] * delta
		proj["y"] += proj["vy"] * delta
		
		# Check if projectile hit ball
		if _target_ball and is_instance_valid(_target_ball):
			var proj_world := global_position + Vector2(proj["x"], proj["y"])
			if proj_world.distance_to(_target_ball.global_position) < 20:
				_deal_damage_to_ball(_target_ball)
				_projectiles.remove_at(i)
				i -= 1
				continue
		
		# Remove if too old or too far
		if proj["time"] > 4.0 or Vector2(proj["x"], proj["y"]).length() > 600:
			_projectiles.remove_at(i)
		
		i -= 1


func _draw() -> void:
	if state == EnemyState.DEAD:
		return
	
	# Death particles
	for p in _death_particles:
		var alpha: float = 1.0 - p["time"]
		var c: Color = p["color"]
		c.a = alpha
		draw_rect(Rect2(p["x"] - p["size"] / 2, p["y"] - p["size"] / 2, p["size"], p["size"]), c, true)
	
	if state == EnemyState.DYING:
		return
	
	var draw_color := body_color
	if _flash_timer > 0:
		draw_color = draw_color.lerp(Color.WHITE, _flash_timer * 2.0)
	
	var r := body_size.x * 0.5
	
	# Base platform
	draw_rect(Rect2(-r * 0.8, r - 4, r * 1.6, 6), draw_color.darkened(0.4), true)
	draw_rect(Rect2(-r * 0.6, r - 8, r * 1.2, 4), draw_color.darkened(0.3), true)
	
	# Body dome
	draw_arc(Vector2.ZERO, r, PI, TAU, 16, draw_color, r * 0.4)
	draw_circle(Vector2.ZERO, r * 0.85, draw_color)
	draw_arc(Vector2.ZERO, r * 0.85, 0, TAU, 16, outline_color, 2.0)
	
	# Health indicator ring segments
	for i in range(max_health):
		var seg_start := PI + float(i) / max_health * PI
		var seg_end := PI + float(i + 1) / max_health * PI - 0.1
		var seg_color := Color(0.3, 0.9, 0.3) if i < health else Color(0.4, 0.15, 0.1)
		draw_arc(Vector2.ZERO, r + 3, seg_start, seg_end, 8, seg_color, 2.5)
	
	# Barrel
	var barrel_end := Vector2(cos(_barrel_angle), sin(_barrel_angle)) * barrel_length
	draw_line(Vector2.ZERO, barrel_end, draw_color.darkened(0.2), 7.0)
	draw_line(Vector2.ZERO, barrel_end, draw_color.lightened(0.15), 4.0)
	
	# Barrel tip
	draw_circle(barrel_end, 3.5, draw_color.lightened(0.2))
	
	# Muzzle flash
	if _muzzle_flash > 0:
		var flash_r := 8.0 * _muzzle_flash
		var flash_c := Color(1.0, 0.7, 0.2, _muzzle_flash)
		draw_circle(barrel_end, flash_r, flash_c)
	
	# Eye
	draw_circle(Vector2(0, -3), 5.0, eye_color)
	var pupil_dir := Vector2(cos(_barrel_angle), sin(_barrel_angle)) * 2.0
	draw_circle(pupil_dir + Vector2(0, -3), 2.5, Color(1.0, 0.2, 0.1))
	
	# Detection range indicator (subtle)
	if state == EnemyState.PATROL:
		var sweep := sin(_detection_sweep) * 0.5 + 0.5
		var scan_angle := -PI / 2 + sweep * PI - PI / 2
		draw_line(
			Vector2.ZERO,
			Vector2(cos(scan_angle), sin(scan_angle)) * detection_range * 0.3,
			Color(1, 0.4, 0.2, 0.15), 1.0
		)
	
	# Projectiles
	for proj in _projectiles:
		var px: float = proj["x"]
		var py: float = proj["y"]
		var alpha: float = 1.0 - min(proj["time"] / 3.0, 0.8)
		
		# Glow
		draw_circle(Vector2(px, py), projectile_size + 2.0, Color(projectile_color.r, projectile_color.g, projectile_color.b, alpha * 0.3))
		# Core
		draw_circle(Vector2(px, py), projectile_size, Color(projectile_color.r, projectile_color.g, projectile_color.b, alpha))
		# Bright center
		draw_circle(Vector2(px, py), projectile_size * 0.4, Color(1.0, 0.95, 0.8, alpha))
		
		# Trail
		var trail_len := 3
		for t in range(trail_len):
			var trail_alpha: float = alpha * (1.0 - float(t) / trail_len) * 0.5
			var trail_x: float = px - proj["vx"] * 0.01 * (t + 1)
			var trail_y: float = py - proj["vy"] * 0.01 * (t + 1)
			draw_circle(Vector2(trail_x, trail_y), projectile_size * 0.6, Color(projectile_color.r, projectile_color.g, projectile_color.b, trail_alpha))
