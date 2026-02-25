extends TrapBase
class_name FireJetTrap

## ═══════════════════════════════════════════════════════════════════════════════
## FireJetTrap — Periodic flame burst from a wall/floor nozzle
## ═══════════════════════════════════════════════════════════════════════════════
##
## Fires a jet of flame in a configurable direction. Cycles between
## active and cooldown phases. Damages ball on contact.

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
var _nozzle_glow: float = 0.0
var _started: bool = false


func _ready() -> void:
	super._ready()
	trap_type = TrapType.FIRE_JET
	_state_timer = -start_delay
	
	# Setup collision for the flame jet area
	if _collision_shape:
		var shape := RectangleShape2D.new()
		shape.size = Vector2(jet_width, jet_length)
		_collision_shape.shape = shape
		_collision_shape.position = jet_direction * jet_length * 0.5
		_collision_shape.rotation = atan2(jet_direction.y, jet_direction.x) + PI / 2
	
	# Initially not dangerous
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
	
	match _jet_state:
		JetState.WARNING:
			_nozzle_glow = sin(_state_timer * 12.0) * 0.5 + 0.5
			if _state_timer >= 0.5:
				_jet_state = JetState.FIRING
				_state_timer = 0.0
				monitoring = true
		
		JetState.FIRING:
			_fire_intensity = min(_fire_intensity + delta * 5.0, 1.0)
			_spawn_flame_particles(delta)
			if _state_timer >= fire_duration:
				_jet_state = JetState.COOLDOWN
				_state_timer = 0.0
				monitoring = false
		
		JetState.COOLDOWN:
			_fire_intensity = max(_fire_intensity - delta * 3.0, 0.0)
			_nozzle_glow = max(_nozzle_glow - delta * 2.0, 0.0)
			if _state_timer >= cooldown_duration:
				_jet_state = JetState.WARNING
				_state_timer = 0.0
	
	# Update flame particles
	var i := _flame_particles.size() - 1
	while i >= 0:
		var p := _flame_particles[i]
		p["time"] += delta
		p["x"] += p["vx"] * delta
		p["y"] += p["vy"] * delta
		p["size"] *= 0.97
		if p["time"] > 0.5 or p["size"] < 0.5:
			_flame_particles.remove_at(i)
		i -= 1
	
	queue_redraw()


func _spawn_flame_particles(delta: float) -> void:
	var count := int(40 * delta)
	for _i in range(max(count, 1)):
		var spread := randf_range(-jet_width * 0.4, jet_width * 0.4)
		var speed := randf_range(jet_length * 0.8, jet_length * 1.5)
		var perp := Vector2(-jet_direction.y, jet_direction.x)
		
		_flame_particles.append({
			"x": perp.x * spread * 0.3,
			"y": perp.y * spread * 0.3,
			"vx": jet_direction.x * speed + perp.x * spread * 2,
			"vy": jet_direction.y * speed + perp.y * spread * 2,
			"time": 0.0,
			"size": randf_range(4, 10),
			"hue": randf_range(0.0, 0.15),  # Yellow to red
		})


func _draw() -> void:
	var dir := jet_direction.normalized()
	var perp := Vector2(-dir.y, dir.x)
	
	# Nozzle base
	var nozzle_w := jet_width * 0.8
	var nozzle_h := 8.0
	var nozzle_points := PackedVector2Array()
	nozzle_points.append(-perp * nozzle_w * 0.5)
	nozzle_points.append(perp * nozzle_w * 0.5)
	nozzle_points.append(perp * nozzle_w * 0.3 - dir * nozzle_h)
	nozzle_points.append(-perp * nozzle_w * 0.3 - dir * nozzle_h)
	draw_colored_polygon(nozzle_points, Color(0.4, 0.4, 0.45))
	draw_polyline(nozzle_points, Color(0.25, 0.25, 0.3), 1.5)
	
	# Nozzle glow
	if _nozzle_glow > 0:
		var glow_c := Color(1.0, 0.5, 0.1, _nozzle_glow * 0.6)
		draw_circle(Vector2.ZERO, nozzle_w * 0.4, glow_c)
	
	# Flame jet
	if _fire_intensity > 0:
		# Core flame
		var flame_len := jet_length * _fire_intensity
		var segments := 8
		for seg in range(segments):
			var t := float(seg) / segments
			var next_t := float(seg + 1) / segments
			var width_at := jet_width * (1.0 - t * 0.4) * _fire_intensity
			var next_width := jet_width * (1.0 - next_t * 0.4) * _fire_intensity
			
			var wobble := sin(_time_elapsed * 15.0 + t * 10.0) * 3.0 * t
			var next_wobble := sin(_time_elapsed * 15.0 + next_t * 10.0) * 3.0 * next_t
			
			var pos := dir * t * flame_len + perp * wobble
			var next_pos := dir * next_t * flame_len + perp * next_wobble
			
			# Color gradient: white -> yellow -> orange -> red
			var c: Color
			if t < 0.2:
				c = Color(1.0, 0.95, 0.8, 0.9)
			elif t < 0.5:
				c = Color(1.0, 0.7, 0.2, 0.7)
			elif t < 0.8:
				c = Color(1.0, 0.4, 0.1, 0.5)
			else:
				c = Color(0.8, 0.2, 0.05, 0.3)
			
			c.a *= _fire_intensity
			
			var quad := PackedVector2Array()
			quad.append(pos + perp * width_at * 0.5)
			quad.append(pos - perp * width_at * 0.5)
			quad.append(next_pos - perp * next_width * 0.5)
			quad.append(next_pos + perp * next_width * 0.5)
			draw_colored_polygon(quad, c)
		
		# Glow
		var glow := Color(1.0, 0.5, 0.1, _fire_intensity * 0.15)
		draw_circle(dir * flame_len * 0.3, flame_len * 0.4, glow)
	
	# Flame particles
	for p in _flame_particles:
		var alpha := (1.0 - p["time"] / 0.5) * _fire_intensity
		var hue: float = p["hue"]
		var c := Color.from_hsv(hue, 0.9, 1.0, alpha)
		draw_circle(Vector2(p["x"], p["y"]), p["size"], c)
	
	# Warning indicator
	if _jet_state == JetState.WARNING:
		var warn_alpha := sin(_state_timer * 16.0) * 0.5 + 0.5
		var warn_c := Color(1.0, 0.6, 0.1, warn_alpha * 0.6)
		draw_line(Vector2.ZERO, dir * jet_length * 0.7, warn_c, 2.0)
