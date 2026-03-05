extends RigidBody2D

## Polished pull-and-shoot ball controller with full animation system.
## Click near the ball, drag to aim, release to launch.
## Includes: squash/stretch, trail, trajectory preview, power ring, particles.

@export_group("Power")
@export var max_power: float = 1600.0
@export var drag_radius: float = 60.0
@export var drag_sensitivity: float = 5

@export_group("Ball Appearance")
@export var ball_radius: float = 20.0
@export var ball_color: Color = Color(0.95, 0.88, 0.72)
@export var highlight_color: Color = Color(1.0, 0.97, 0.92)
@export var outline_color: Color = Color(0.6, 0.52, 0.38)

@export_group("World Bounds")
@export var world_bounds: Rect2 = Rect2(0, 0, 1200, 800)

# --- State ---
var is_dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var drag_offset: Vector2 = Vector2.ZERO
var drag_current: Vector2 = Vector2.ZERO
var shot_count: int = 0
# True when drag was started while ball was still moving
var _drag_slow_mode: bool = false

# --- Animation ---
var _squash: Vector2 = Vector2.ONE
var _idle_time: float = 0.0
var _flash: float = 0.0
var _prev_speed: float = 0.0

# --- Trail ---
const TRAIL_LENGTH: int = 40
const TRAIL_MIN_DIST: float = 4.0
const REST_THRESHOLD: float = 12.0

# --- Signals ---
signal shot_fired(count: int)
signal impact_occurred(strength: float)


func _ready() -> void:
	add_to_group("ball")
	lock_rotation = true
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.bounce = 0.6
	physics_material_override.friction = 0.3
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_collision)
	print("[Player] Ready at %s | drag_radius=%s | world_bounds=%s" % [str(global_position), drag_radius, str(world_bounds)])


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Heavy deceleration while dragging a moving ball
	if is_dragging and _drag_slow_mode:
		state.linear_velocity *= 0.80
		if state.linear_velocity.length() < REST_THRESHOLD:
			state.linear_velocity = Vector2.ZERO
			_drag_slow_mode = false
			call_deferred("set", "freeze", true)

	# Cap velocity to prevent tunneling through walls
	var vel := state.linear_velocity
	var max_speed := 2500.0
	if vel.length() > max_speed:
		state.linear_velocity = vel.normalized() * max_speed
	
	# Hard boundary enforcement (safety net if physics walls fail)
	if world_bounds.size != Vector2.ZERO:
		var pos := state.transform.origin
		var changed := false
		var margin := ball_radius + 2.0
		
		if pos.x < world_bounds.position.x + margin:
			pos.x = world_bounds.position.x + margin
			state.linear_velocity.x = abs(state.linear_velocity.x) * 0.5
			changed = true
		elif pos.x > world_bounds.end.x - margin:
			pos.x = world_bounds.end.x - margin
			state.linear_velocity.x = -abs(state.linear_velocity.x) * 0.5
			changed = true
		
		if pos.y < world_bounds.position.y + margin:
			pos.y = world_bounds.position.y + margin
			state.linear_velocity.y = abs(state.linear_velocity.y) * 0.5
			changed = true
		elif pos.y > world_bounds.end.y - margin:
			pos.y = world_bounds.end.y - margin
			state.linear_velocity.y = -abs(state.linear_velocity.y) * 0.5
			changed = true
		
		if changed:
			state.transform.origin = pos


func _process(delta: float) -> void:
	# Idle pulse timer
	if _is_resting() and not is_dragging:
		_idle_time += delta
	else:
		_idle_time = 0.0

	# Decay flash
	_flash = move_toward(_flash, 0.0, delta * 4.0)

	# Lerp squash back to normal
	_squash = _squash.lerp(Vector2.ONE, delta * 12.0)

	# Update trail
	_update_trail()

	# Trail particles follow speed
	var trail_p = get_node_or_null("TrailParticles") as CPUParticles2D
	if trail_p:
		trail_p.emitting = linear_velocity.length() > 60.0

	_prev_speed = linear_velocity.length()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_drag(get_global_mouse_position())
		else:
			_end_drag()

	elif event is InputEventMouseMotion and is_dragging:
		drag_offset += event.relative
		drag_current = drag_start + drag_offset


# ===========================================================================
#  DRAWING
# ===========================================================================

func _draw() -> void:
	# Trajectory and power ring drawn behind the ball
	if is_dragging:
		_draw_trajectory()
		_draw_power_ring()
		_draw_aim_line()

	# --- Ball with squash/stretch ---
	draw_set_transform(Vector2.ZERO, 0.0, _squash)

	# Drop shadow
	draw_circle(Vector2(3, 4), ball_radius, Color(0, 0, 0, 0.12))

	# Outline
	draw_circle(Vector2.ZERO, ball_radius + 1.5, outline_color)

	# Main body
	draw_circle(Vector2.ZERO, ball_radius, ball_color)

	# Inner highlight (upper-left)
	draw_circle(Vector2(-3, -4), ball_radius * 0.55, highlight_color)

	# Specular dot
	draw_circle(Vector2(-6, -8), ball_radius * 0.2, Color(1, 1, 1, 0.55))

	# Idle glow pulse
	if _idle_time > 0.3 and _is_resting():
		var pulse := (sin(_idle_time * 3.0) + 1.0) * 0.5
		draw_circle(
			Vector2.ZERO,
			ball_radius + 5.0 + pulse * 5.0,
			Color(1, 0.95, 0.85, pulse * 0.12)
		)

	# Impact / launch flash
	if _flash > 0:
		draw_circle(Vector2.ZERO, ball_radius + 3.0, Color(1, 1, 1, _flash * 0.4))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_trajectory() -> void:
	var drag_vec := drag_start - drag_current
	var power := clampf(drag_vec.length() * drag_sensitivity, 0.0, max_power)
	if power < 10.0:
		return

	var dir := drag_vec.normalized()
	var vel := dir * power
	var grav := Vector2(0, ProjectSettings.get_setting(
		"physics/2d/default_gravity", 980.0))

	# Draw physics-accurate parabolic dots
	for i in range(1, 32):
		var t := i * 0.035
		var pos := vel * t + 0.5 * grav * t * t
		var alpha := (1.0 - float(i) / 32.0) * 0.45
		var sz := 2.8 * (1.0 - float(i) / 32.0 * 0.5)
		draw_circle(pos, sz, Color(1, 1, 1, alpha))


func _draw_aim_line() -> void:
	var drag_vec := drag_start - drag_current
	var power := clampf(drag_vec.length() * drag_sensitivity, 0.0, max_power)
	if power < 10.0:
		return
	var dir := drag_vec.normalized()
	# Short solid aim line from ball center
	var line_len := clampf(power * 0.08, 10.0, 60.0)
	draw_line(Vector2.ZERO, dir * line_len, Color(1, 1, 1, 0.5), 2.0, true)


func _draw_power_ring() -> void:
	var drag_vec := drag_start - drag_current
	var power := clampf(drag_vec.length() * drag_sensitivity, 0.0, max_power)
	var ratio := power / max_power
	if ratio < 0.02:
		return

	# Color ramp: green → yellow → red
	var col: Color
	if ratio < 0.5:
		col = Color(0.3, 0.9, 0.4).lerp(Color(1.0, 0.9, 0.2), ratio * 2.0)
	else:
		col = Color(1.0, 0.9, 0.2).lerp(Color(1.0, 0.3, 0.2), (ratio - 0.5) * 2.0)
	col.a = 0.65

	var arc := ratio * TAU
	var r := ball_radius + 11.0
	var segs := int(36 * ratio) + 2
	var prev := Vector2(cos(-PI / 2.0), sin(-PI / 2.0)) * r
	for i in range(1, segs):
		var angle := -PI / 2.0 + arc * float(i) / float(segs - 1)
		var next := Vector2(cos(angle), sin(angle)) * r
		draw_line(prev, next, col, 2.5, true)
		prev = next

	# Tick marks at 25%, 50%, 75%
	for pct in [0.25, 0.5, 0.75]:
		if ratio >= pct:
			var a: float = -PI / 2.0 + pct * TAU
			var p1: Vector2 = Vector2(cos(a), sin(a)) * (r - 3.0)
			var p2: Vector2 = Vector2(cos(a), sin(a)) * (r + 3.0)
			draw_line(p1, p2, Color(1, 1, 1, 0.4), 1.5)


# ===========================================================================
#  DRAG MECHANICS
# ===========================================================================

func _start_drag(mpos: Vector2) -> void:
	var dist := global_position.distance_to(mpos)
	print("[Player] _start_drag: mouse_world=%s ball=%s dist=%.1f radius=%s resting=%s" % [str(mpos), str(global_position), dist, drag_radius, _is_resting()])
	if dist > drag_radius:
		print("[Player] Drag rejected — too far (%.1f > %s)" % [dist, drag_radius])
		return
	is_dragging = true
	drag_start = mpos
	drag_offset = Vector2.ZERO
	drag_current = drag_start

	# Setting the mouse to capture beyond the window
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if _is_resting():
		# Ball is already still — freeze and aim like normal
		_drag_slow_mode = false
		freeze = true
	else:
		# Ball is moving — don't freeze yet, bleed off velocity in _integrate_forces
		_drag_slow_mode = true
	# Grab squash
	_squash = Vector2(1.1, 0.9)


func _end_drag() -> void:
	if not is_dragging:
		return

	# Stop the mouse capture
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	is_dragging = false
	_drag_slow_mode = false
	freeze = false

	var drag_vec := drag_start - drag_current
	var power := clampf(drag_vec.length() * drag_sensitivity, 0.0, max_power)
	var dir := drag_vec.normalized()

	if power < 10.0:
		return

	print("[Player] SHOT #%d — dir=%s power=%.1f impulse=%s" % [shot_count + 1, str(dir), power, str(dir * power)])
	apply_central_impulse(dir * power)
	shot_count += 1
	shot_fired.emit(shot_count)

	# Launch squash
	_squash = Vector2(0.7, 1.35)
	_flash = 0.7

	# Launch particles burst
	var lp = get_node_or_null("LaunchParticles") as CPUParticles2D
	if lp:
		lp.direction = dir
		lp.restart()
		lp.emitting = true


# ===========================================================================
#  TRAIL
# ===========================================================================

func _update_trail() -> void:
	var trail := get_node_or_null("Trail") as Line2D
	if not trail:
		return

	if linear_velocity.length() > 25.0:
		var gp := global_position
		if trail.get_point_count() == 0 or \
				gp.distance_to(trail.get_point_position(0)) > TRAIL_MIN_DIST:
			trail.add_point(gp, 0)

	while trail.get_point_count() > TRAIL_LENGTH:
		trail.remove_point(trail.get_point_count() - 1)

	# Fade out trail when resting
	if _is_resting() and trail.get_point_count() > 0:
		trail.remove_point(trail.get_point_count() - 1)


# ===========================================================================
#  COLLISION
# ===========================================================================

func _on_collision(body: Node) -> void:
	if _prev_speed < 80.0:
		return

	# Direction-aware squash
	var vel := linear_velocity.normalized()
	var strength := clampf(_prev_speed / 500.0, 0.2, 1.0)
	if abs(vel.y) > abs(vel.x):
		_squash = Vector2.ONE.lerp(Vector2(1.3, 0.75), strength)
	else:
		_squash = Vector2.ONE.lerp(Vector2(0.75, 1.3), strength)

	_flash = clampf(_prev_speed / 600.0, 0.15, 0.8)

	# Impact particles
	var ip = get_node_or_null("ImpactParticles") as CPUParticles2D
	if ip:
		ip.restart()
		ip.emitting = true

	impact_occurred.emit(_prev_speed)


func _is_resting() -> bool:
	return linear_velocity.length() < REST_THRESHOLD or freeze


# ═══════════════════════════════════════════════════════════════════════════
# TRAJECTORY PREDICTION SYSTEM
# ═══════════════════════════════════════════════════════════════════════════

func get_trajectory_path(initial_velocity: Vector2, max_points: int = 60) -> PackedVector2Array:
	"""Predict ball trajectory path given initial velocity"""
	var path := PackedVector2Array()
	var pos := global_position
	var vel := initial_velocity
	var gravity := get_gravity()
	var dt := 0.016  # Approximate 60 FPS frame time
	var friction_factor := 0.99
	
	path.append(pos)
	
	for i in range(max_points):
		# Apply gravity
		vel += gravity * dt
		
		# Apply friction over time
		vel *= friction_factor
		
		# Update position
		pos += vel * dt
		
		# Stop if out of bounds or velocity negligible
		if not world_bounds.has_point(pos) or vel.length() < 5.0:
			break
		
		path.append(pos)
	
	return path


func get_trajectory_endpoints() -> Dictionary:
	"""Get start, peak, and landing points of trajectory"""
	var drag_force := (drag_current - drag_start).normalized()
	var power := (drag_current - drag_start).length() / drag_radius
	power = clampf(power, 0.0, 1.0)
	var launch_velocity := drag_force * max_power * power
	
	var path := get_trajectory_path(launch_velocity)
	
	var peak := global_position
	var peak_y := global_position.y
	var landing := global_position
	
	for point in path:
		if point.y < peak_y:
			peak = point
			peak_y = point.y
		landing = point
	
	return {
		"start": global_position,
		"peak": peak,
		"landing": landing,
		"peak_height": global_position.y - peak_y,
		"distance": global_position.distance_to(landing),
	}


func predict_landing_zone(launch_velocity: Vector2) -> Rect2:
	"""Predict rectangular zone where ball might land"""
	var path := get_trajectory_path(launch_velocity, 120)
	if path.is_empty():
		return Rect2(global_position, Vector2(100, 100))
	
	var min_x := global_position.x
	var max_x := global_position.x
	var min_y := global_position.y
	var max_y := global_position.y
	
	for point in path:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)
	
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


# ═══════════════════════════════════════════════════════════════════════════
# POWER & MOMENTUM ANALYTICS
# ═══════════════════════════════════════════════════════════════════════════

func get_current_power() -> float:
	"""Get current drag power as 0-1"""
	if not is_dragging:
		return 0.0
	return (drag_current - drag_start).length() / drag_radius


func get_momentum() -> float:
	"""Return current kinetic energy indicator"""
	return linear_velocity.length()


func get_momentum_ratio() -> float:
	"""Return momentum as ratio to max_power"""
	return get_momentum() / max_power


func get_impact_force() -> float:
	"""Calculate impact force from last collision"""
	return _prev_speed


func get_shot_statistics() -> Dictionary:
	"""Return comprehensive shot statistics"""
	return {
		"shot_count": shot_count,
		"current_velocity": linear_velocity.length(),
		"max_velocity": max_power,
		"momentum_ratio": get_momentum_ratio(),
		"impact_force": get_impact_force(),
		"is_moving": not _is_resting(),
		"is_dragging": is_dragging,
	}


func get_velocity_direction() -> Vector2:
	"""Get normalized velocity direction"""
	var vel := linear_velocity
	if vel.length() < 0.1:
		return Vector2.ZERO
	return vel.normalized()


func get_velocity_angle() -> float:
	"""Get velocity angle in degrees (0 = right, 90 = up)"""
	return rad_to_deg(get_velocity_direction().angle())


# ═══════════════════════════════════════════════════════════════════════════
# ADVANCED PHYSICS HELPERS
# ═══════════════════════════════════════════════════════════════════════════

func apply_force_impulse(direction: Vector2, magnitude: float) -> void:
	"""Apply instant velocity boost in direction"""
	linear_velocity += direction.normalized() * magnitude


func apply_directional_boost(angle_degrees: float, magnitude: float) -> void:
	"""Boost ball in specific angle"""
	var direction := Vector2(cos(deg_to_rad(angle_degrees)), -sin(deg_to_rad(angle_degrees)))
	apply_force_impulse(direction, magnitude)


func clamp_velocity(max_speed: float) -> void:
	"""Limit maximum velocity"""
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed


func apply_damping(damping_factor: float) -> void:
	"""Apply velocity damping (0.9 = 10% reduction per frame)"""
	linear_velocity *= damping_factor


func reverse_velocity() -> void:
	"""Reverse direction of ball"""
	linear_velocity = -linear_velocity


func reflect_off_surface(surface_normal: Vector2) -> void:
	"""Bounce ball off surface with proper reflection"""
	linear_velocity = linear_velocity.reflect(surface_normal)


func set_velocity_toward_target(target: Vector2, speed: float) -> void:
	"""Aim ball toward specific target at speed"""
	var direction := (target - global_position).normalized()
	linear_velocity = direction * speed


# ═══════════════════════════════════════════════════════════════════════════
# VISUAL FEEDBACK ENHANCEMENTS
# ═══════════════════════════════════════════════════════════════════════════

func draw_trajectory_preview(positions: PackedVector2Array) -> void:
	"""Helper to queue redraw of trajectory"""
	queue_redraw()


func get_power_ring_scale() -> float:
	"""Get visual scale for power/charge ring"""
	return get_current_power()


func get_glow_intensity() -> float:
	"""Get glow intensity based on velocity"""
	var ratio := get_momentum_ratio()
	return 0.2 + (ratio * 0.8)  # Range 0.2 - 1.0


func get_trail_color() -> Color:
	"""Get trail color based on speed"""
	var ratio := clampf(get_momentum_ratio(), 0.0, 1.0)
	# Gradient from cool to hot as speed increases
	return Color(ratio, 0.5, 1.0 - ratio).lerp(Color.WHITE, ratio * 0.3)


# ═══════════════════════════════════════════════════════════════════════════
# STATE QUERYING
# ═══════════════════════════════════════════════════════════════════════════

func is_in_slow_mode() -> bool:
	"""Check if ball can be dragged while moving"""
	return _drag_slow_mode


func can_be_launched() -> bool:
	"""Determine if ball is in state to be launched"""
	return _is_resting() and not freeze


func get_state_info() -> Dictionary:
	"""Return comprehensive state information"""
	return {
		"position": global_position,
		"velocity": linear_velocity,
		"resting": _is_resting(),
		"frozen": freeze,
		"dragging": is_dragging,
		"slow_mode": _drag_slow_mode,
		"rotation": rotation,
		"squash": _squash,
	}
