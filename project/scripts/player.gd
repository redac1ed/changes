extends RigidBody2D

## Polished pull-and-shoot ball controller with full animation system.
## Click near the ball, drag to aim, release to launch.
## Includes: squash/stretch, trail, trajectory preview, power ring, particles.

@export_group("Power")
@export var max_power: float = 1600.0
@export var drag_radius: float = 100.0
@export var drag_sensitivity: float = 1.5

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
		drag_current = get_global_mouse_position()


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
	drag_current = mpos
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
