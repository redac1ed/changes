extends TrapBase
class_name FireJetTrap

@export_category("Fire Jet")
@export var jet_length: float = 120.0
@export var jet_width: float = 20.0
@export var fire_duration: float = 2.0
@export var cooldown_duration: float = 2.5
@export var start_delay: float = 0.0
@export var jet_direction: Vector2 = Vector2.UP

enum JetState { IDLE, WARNING, FIRING, COOLDOWN }

var _jet_state: JetState = JetState.IDLE
var _state_timer: float = 0.0
var _fire_intensity: float = 0.0
var _flame_particles: Array[Dictionary] = []
var _smoke_particles: Array[Dictionary] = []
var _ember_particles: Array[Dictionary] = []
var _nozzle_glow: float = 0.0
var _started: bool = false
var _ignition_flash: float = 0.0

func _ready() -> void:
	super._ready()
	trap_type = TrapType.FIRE_JET
	_state_timer = -start_delay

	if _collision_shape:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(jet_width, jet_length)
		_collision_shape.shape = shape
		_collision_shape.position = jet_direction * jet_length * 0.5
		_collision_shape.rotation = atan2(jet_direction.y, jet_direction.x) + PI / 2

	monitoring = false

func _process(delta: float) -> void:
	_time_elapsed += delta

	if not _started:
		_state_timer += delta
		if _state_timer >= 0:
			_started = true
			_state_timer = 0.0
			_jet_state = JetState.WARNING
		queue_redraw()
		return

	_state_timer += delta

	if _ignition_flash > 0:
		_ignition_flash -= delta * 4.0

	match _jet_state:
		JetState.WARNING:
			_nozzle_glow = sin(_state_timer * 15.0) * 0.5 + 0.5
			if _state_timer >= 0.6:
				_jet_state = JetState.FIRING
				_state_timer = 0.0
				_ignition_flash = 1.0
				monitoring = true

		JetState.FIRING:
			_fire_intensity = min(_fire_intensity + delta * 6.0, 1.0)
			_spawn_flame_particles(delta)
			_spawn_smoke_particles(delta)
			if _state_timer >= fire_duration:
				_jet_state = JetState.COOLDOWN
				_state_timer = 0.0
				monitoring = false

		JetState.COOLDOWN:
			_fire_intensity = max(_fire_intensity - delta * 4.0, 0.0)
			_nozzle_glow = max(_nozzle_glow - delta * 3.0, 0.0)
			_spawn_ember_particles(delta)
			if _state_timer >= cooldown_duration:
				_jet_state = JetState.WARNING
				_state_timer = 0.0

	var i := _flame_particles.size() - 1
	while i >= 0:
		var p := _flame_particles[i]
		p["time"] += delta
		p["x"] += p["vx"] * delta
		p["y"] += p["vy"] * delta
		p["vy"] -= 50 * delta
		p["size"] *= 0.96
		if p["time"] > 0.6 or p["size"] < 0.8:
			_flame_particles.remove_at(i)
		i -= 1

	i = _smoke_particles.size() - 1
	while i >= 0:
		var p := _smoke_particles[i]
		p["time"] += delta
		p["x"] += p["vx"] * delta
		p["y"] += p["vy"] * delta
		p["size"] += delta * 8
		p["alpha"] -= delta * 1.5
		if p["time"] > 1.0 or p["alpha"] <= 0:
			_smoke_particles.remove_at(i)
		i -= 1

	i = _ember_particles.size() - 1
	while i >= 0:
		var p := _ember_particles[i]
		p["time"] += delta
		p["x"] += p["vx"] * delta
		p["y"] += p["vy"] * delta
		p["vy"] += 80 * delta
		p["alpha"] -= delta * 0.8
		if p["time"] > 1.5 or p["alpha"] <= 0:
			_ember_particles.remove_at(i)
		i -= 1

	queue_redraw()

func _spawn_flame_particles(delta: float) -> void:
	var count := int(50 * delta)
	for _i in range(max(count, 1)):
		var spread := randf_range(-jet_width * 0.45, jet_width * 0.45)
		var speed := randf_range(jet_length * 0.7, jet_length * 1.6)
		var perp := Vector2(-jet_direction.y, jet_direction.x)

		_flame_particles.append({
			"x": perp.x * spread * 0.2,
			"y": perp.y * spread * 0.2,
			"vx": jet_direction.x * speed + perp.x * spread * 1.5,
			"vy": jet_direction.y * speed + perp.y * spread * 1.5,
			"time": 0.0,
			"size": randf_range(5, 12),
			"hue": randf_range(-0.05, 0.12),
		})

func _spawn_smoke_particles(delta: float) -> void:
	if _fire_intensity < 0.3:
		return
	var count := int(15 * delta * _fire_intensity)
	for _i in range(max(count, 1)):
		var spread := randf_range(-jet_width * 0.3, jet_width * 0.3)
		var speed := randf_range(jet_length * 0.3, jet_length * 0.6)
		var perp := Vector2(-jet_direction.y, jet_direction.x)

		_smoke_particles.append({
			"x": perp.x * spread * 0.5 + jet_direction.x * jet_length * 0.5,
			"y": perp.y * spread * 0.5 + jet_direction.y * jet_length * 0.5,
			"vx": (jet_direction.x * speed + perp.x * spread * 0.5) * 0.3,
			"vy": (jet_direction.y * speed + perp.y * spread * 0.5) * 0.3 - 20,
			"time": 0.0,
			"size": randf_range(8, 15),
			"alpha": randf_range(0.3, 0.5),
		})

func _spawn_ember_particles(delta: float) -> void:
	var count := int(8 * delta)
	for _i in range(max(count, 1)):
		var spread := randf_range(-jet_width * 0.4, jet_width * 0.4)
		var speed := randf_range(jet_length * 0.2, jet_length * 0.5)
		var perp := Vector2(-jet_direction.y, jet_direction.x)

		_ember_particles.append({
			"x": perp.x * spread * 0.3,
			"y": perp.y * spread * 0.3,
			"vx": jet_direction.x * speed * 0.5 + randf_range(-30, 30),
			"vy": jet_direction.y * speed * 0.5 + randf_range(-80, -20),
			"time": 0.0,
			"size": randf_range(2, 4),
			"alpha": 1.0,
		})

func _draw() -> void:
	var dir := jet_direction.normalized()
	var perp := Vector2(-dir.y, dir.x)

	var nozzle_w := jet_width * 0.85
	var nozzle_h := 10.0
	var nozzle_points := PackedVector2Array()
	nozzle_points.append(-perp * nozzle_w * 0.5 + dir * 4)
	nozzle_points.append(perp * nozzle_w * 0.5 + dir * 4)
	nozzle_points.append(perp * nozzle_w * 0.35)
	nozzle_points.append(-perp * nozzle_w * 0.35)
	draw_colored_polygon(nozzle_points, Color(0.35, 0.35, 0.4))
	draw_polyline(nozzle_points, Color(0.2, 0.2, 0.25), 2.0)

	var inner_nozzle := PackedVector2Array()
	inner_nozzle.append(-perp * nozzle_w * 0.25 + dir * 2)
	inner_nozzle.append(perp * nozzle_w * 0.25 + dir * 2)
	inner_nozzle.append(perp * nozzle_w * 0.15 - dir * 3)
	inner_nozzle.append(-perp * nozzle_w * 0.15 - dir * 3)
	draw_colored_polygon(inner_nozzle, Color(0.15, 0.1, 0.05))

	if _nozzle_glow > 0 or _ignition_flash > 0:
		var glow_intensity: float = maxf(_nozzle_glow, _ignition_flash * 0.8)
		var glow_c := Color(1.0, 0.4 + _ignition_flash * 0.3, 0.1, glow_intensity * 0.7)
		draw_circle(dir * 2, nozzle_w * 0.5 * glow_intensity, glow_c)

	if _ignition_flash > 0:
		var flash_c := Color(1.0, 0.9, 0.5, _ignition_flash * 0.4)
		draw_circle(dir * 2, nozzle_w * 0.8, flash_c)

	if _fire_intensity > 0:

		var flame_len := jet_length * _fire_intensity

		var core_width := jet_width * 0.6 * _fire_intensity
		for i in range(4):
			var t := float(i) / 4.0
			var next_t := float(i + 1) / 4.0
			var width_at := core_width * (1.0 - t * 0.5)
			var next_width := core_width * (1.0 - next_t * 0.5)

			var wobble := sin(_time_elapsed * 18.0 + t * 12.0) * 4.0 * t
			var next_wobble := sin(_time_elapsed * 18.0 + next_t * 12.0) * 4.0 * next_t

			var pos := dir * t * flame_len + perp * wobble
			var next_pos := dir * next_t * flame_len + perp * next_wobble

			var c := Color(1.0, 0.97 - t * 0.3, 0.85 - t * 0.5, 0.95 - t * 0.3)
			c.a *= _fire_intensity

			var quad := PackedVector2Array()
			quad.append(pos + perp * width_at * 0.5)
			quad.append(pos - perp * width_at * 0.5)
			quad.append(next_pos - perp * next_width * 0.5)
			quad.append(next_pos + perp * next_width * 0.5)
			draw_colored_polygon(quad, c)

		var outer_width := jet_width * (1.0 - 0.3) * _fire_intensity
		for seg in range(6):
			var t := float(seg) / 6.0
			var next_t := float(seg + 1) / 6.0
			var width_at := outer_width * (1.0 - t * 0.6)
			var next_width := outer_width * (1.0 - next_t * 0.6)

			var wobble := sin(_time_elapsed * 14.0 + t * 8.0) * 5.0 * t
			var next_wobble := sin(_time_elapsed * 14.0 + next_t * 8.0) * 5.0 * next_t

			var pos := dir * t * flame_len + perp * wobble
			var next_pos := dir * next_t * flame_len + perp * next_wobble

			var c: Color
			if t < 0.3:
				c = Color(1.0, 0.65, 0.15, 0.7)
			elif t < 0.6:
				c = Color(1.0, 0.35, 0.08, 0.5)
			else:
				c = Color(0.9, 0.15, 0.02, 0.3)

			c.a *= _fire_intensity

			var quad := PackedVector2Array()
			quad.append(pos + perp * width_at * 0.5)
			quad.append(pos - perp * width_at * 0.5)
			quad.append(next_pos - perp * next_width * 0.5)
			quad.append(next_pos + perp * next_width * 0.5)
			draw_colored_polygon(quad, c)

		var glow := Color(1.0, 0.5, 0.1, _fire_intensity * 0.12)
		draw_circle(dir * flame_len * 0.25, flame_len * 0.5, glow)

		var tip_glow := Color(1.0, 0.3, 0.05, _fire_intensity * 0.08)
		draw_circle(dir * flame_len, flame_len * 0.15, tip_glow)

	for p in _flame_particles:
		var alpha: float = (1.0 - p["time"] / 0.6) * _fire_intensity
		var hue: float = p["hue"]
		var c := Color.from_hsv(0.08 + hue, 0.85, 1.0, alpha * 0.8)
		draw_circle(Vector2(p["x"], p["y"]), p["size"], c)

	for p in _smoke_particles:
		var c := Color(0.4, 0.35, 0.3, p["alpha"] * 0.4)
		draw_circle(Vector2(p["x"], p["y"]), p["size"], c)

	for p in _ember_particles:
		var c := Color(1.0, 0.6, 0.2, p["alpha"] * 0.9)
		draw_circle(Vector2(p["x"], p["y"]), p["size"], c)

	if _jet_state == JetState.WARNING:
		var warn_alpha := sin(_state_timer * 20.0) * 0.5 + 0.5
		var warn_c := Color(1.0, 0.5, 0.05, warn_alpha * 0.7)
		var warn_len := jet_length * (0.3 + _state_timer / 0.6 * 0.5)
		draw_line(Vector2.ZERO, dir * warn_len, warn_c, 2.5)

		var bracket_len := jet_length * 0.15
		var bracket_offset := jet_length * 0.5
		draw_line(dir * bracket_offset - perp * jet_width * 0.4, dir * bracket_offset - perp * jet_width * 0.4 + dir * bracket_len, warn_c, 2.0)
		draw_line(dir * bracket_offset + perp * jet_width * 0.4, dir * bracket_offset + perp * jet_width * 0.4 + dir * bracket_len, warn_c, 2.0)
