extends TrapBase
class_name LaserBeam

## ═══════════════════════════════════════════════════════════════════════════════
## LaserBeam — Toggling laser trap between two points
## ═══════════════════════════════════════════════════════════════════════════════
##
## Draws a laser beam between emitter and receiver. Toggles on/off
## with configurable timing. Warns before activating.

@export_category("Laser Settings")
@export var beam_length: float = 200.0
@export var beam_direction: Vector2 = Vector2.RIGHT
@export var on_duration: float = 2.5
@export var off_duration: float = 1.5
@export var warning_time: float = 0.4
@export var beam_width: float = 4.0
@export var beam_color: Color = Color(1.0, 0.15, 0.1)
@export var emitter_color: Color = Color(0.5, 0.5, 0.55)
@export var start_on: bool = true

var _is_on: bool = false
var _timer: float = 0.0
var _warning: bool = false
var _beam_alpha: float = 0.0
var _beam_flicker: float = 0.0
var _emitter_particles: Array[Dictionary] = []


func _ready() -> void:
	super._ready()
	trap_type = TrapType.LASER
	_is_on = start_on
	
	# Setup collision for the beam
	if _collision_shape:
		var shape := RectangleShape2D.new()
		var dir := beam_direction.normalized()
		shape.size = Vector2(beam_length, beam_width * 2)
		_collision_shape.shape = shape
		_collision_shape.position = dir * beam_length * 0.5
		_collision_shape.rotation = atan2(dir.y, dir.x)
	
	monitoring = _is_on


func _process(delta: float) -> void:
	_time_elapsed += delta
	_timer += delta
	_beam_flicker = randf_range(0.85, 1.0)
	
	if _is_on:
		_beam_alpha = min(_beam_alpha + delta * 8.0, 1.0)
		if _timer >= on_duration:
			_is_on = false
			_timer = 0.0
			_warning = false
			monitoring = false
	else:
		_beam_alpha = max(_beam_alpha - delta * 6.0, 0.0)
		if _timer >= off_duration - warning_time:
			_warning = true
		if _timer >= off_duration:
			_is_on = true
			_timer = 0.0
			_warning = false
			monitoring = true
	
	# Emitter particles
	if _is_on and randf() < 0.3:
		var dir := beam_direction.normalized()
		var perp := Vector2(-dir.y, dir.x)
		_emitter_particles.append({
			"x": perp.x * randf_range(-3, 3),
			"y": perp.y * randf_range(-3, 3),
			"vx": perp.x * randf_range(-20, 20),
			"vy": perp.y * randf_range(-20, 20) - 10,
			"time": 0.0,
		})
	
	var i := _emitter_particles.size() - 1
	while i >= 0:
		_emitter_particles[i]["time"] += delta
		_emitter_particles[i]["x"] += _emitter_particles[i]["vx"] * delta
		_emitter_particles[i]["y"] += _emitter_particles[i]["vy"] * delta
		if _emitter_particles[i]["time"] > 0.4:
			_emitter_particles.remove_at(i)
		i -= 1
	
	queue_redraw()


func _draw() -> void:
	var dir := beam_direction.normalized()
	var perp := Vector2(-dir.y, dir.x)
	var end := dir * beam_length
	
	# Emitter housing
	var ew := 10.0
	var eh := 14.0
	draw_rect(Rect2(-perp * eh * 0.5 - dir * ew * 0.5, Vector2(ew, eh).rotated(atan2(dir.y, dir.x))), emitter_color, true)
	
	# Emitter dot
	var emit_c := beam_color if _is_on else Color(0.3, 0.3, 0.35)
	if _warning and not _is_on:
		emit_c = Color(1.0, 0.6, 0.1, sin(_time_elapsed * 20.0) * 0.5 + 0.5)
	draw_circle(Vector2.ZERO, 4.0, emit_c)
	
	# Receiver housing
	draw_rect(Rect2(end - Vector2(ew, eh) * 0.5, Vector2(ew, eh)), emitter_color.darkened(0.15), true)
	draw_circle(end, 3.0, emit_c.darkened(0.2))
	
	# Beam
	if _beam_alpha > 0:
		var alpha := _beam_alpha * _beam_flicker
		
		# Outer glow
		draw_line(Vector2.ZERO, end, Color(beam_color.r, beam_color.g, beam_color.b, alpha * 0.15), beam_width * 4)
		
		# Main beam
		draw_line(Vector2.ZERO, end, Color(beam_color.r, beam_color.g, beam_color.b, alpha * 0.6), beam_width * 2)
		
		# Core
		draw_line(Vector2.ZERO, end, Color(1.0, 0.9, 0.9, alpha * 0.9), beam_width)
		
		# Bright center line
		draw_line(Vector2.ZERO, end, Color(1.0, 1.0, 1.0, alpha * 0.5), beam_width * 0.3)
		
		# End point glow
		draw_circle(end, 6.0 * alpha, Color(beam_color.r, beam_color.g, beam_color.b, alpha * 0.3))
		
		# Scanning dots along beam
		var dot_count := 4
		for dot in range(dot_count):
			var t := fmod(_time_elapsed * 3.0 + float(dot) / dot_count, 1.0)
			var dot_pos := dir * beam_length * t
			draw_circle(dot_pos, 2.0, Color(1, 1, 1, alpha * 0.5 * (1.0 - t)))
	
	# Warning pulse
	if _warning and not _is_on:
		var pulse := sin(_time_elapsed * 16.0) * 0.5 + 0.5
		draw_line(Vector2.ZERO, end, Color(beam_color.r, beam_color.g, beam_color.b, pulse * 0.2), beam_width)
	
	# Emitter particles
	for p in _emitter_particles:
		var p_alpha := 1.0 - (p["time"] / 0.4)
		draw_circle(Vector2(p["x"], p["y"]), 2.0, Color(beam_color.r, beam_color.g, beam_color.b, p_alpha * 0.6))
