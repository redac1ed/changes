extends PlatformBase
class_name DisappearingPlatform

## ═══════════════════════════════════════════════════════════════════════════════
## DisappearingPlatform — Phases in and out on a configurable timer
## ═══════════════════════════════════════════════════════════════════════════════
##
## Cycles between visible/solid and invisible/passthrough states.
## Features smooth fade transitions and sync grouping for puzzle design.

# ─── Signals ─────────────────────────────────────────────────────────────────
signal phase_changed(is_solid: bool)

# ─── Exports ─────────────────────────────────────────────────────────────────
@export_category("Phase Settings")
@export var visible_duration: float = 3.0
@export var invisible_duration: float = 2.0
@export var fade_time: float = 0.4
@export var start_visible: bool = true
@export var phase_offset: float = 0.0  ## Offset from other platforms in group
@export var sync_group: String = ""     ## Platforms with same group sync

@export_category("Visual")
@export var ghost_when_invisible: bool = true
@export var ghost_alpha: float = 0.15
@export var pulse_when_about_to_change: bool = true
@export var warning_time: float = 1.0

# ─── Internal ────────────────────────────────────────────────────────────────
var _phase_timer: float = 0.0
var _is_solid: bool = true
var _fade_progress: float = 1.0  # 1.0 = fully visible, 0.0 = invisible
var _fading_direction: int = 0   # 0 = not fading, 1 = fading in, -1 = fading out
var _warning_active: bool = false


func _platform_ready() -> void:
	platform_type = PlatformType.DISAPPEARING
	platform_color = Color(0.65, 0.5, 0.85, 1.0)
	outline_color = Color(0.45, 0.3, 0.7, 0.9)
	particle_color = Color(0.7, 0.55, 0.9, 0.5)
	glow_intensity = 0.1
	glow_color = Color(0.6, 0.4, 0.9, 0.25)
	
	_is_solid = start_visible
	_fade_progress = 1.0 if start_visible else 0.0
	_phase_timer = phase_offset
	
	if not start_visible:
		_set_solid(false)


func _platform_process(delta: float) -> void:
	_phase_timer += delta
	
	# Handle fading
	if _fading_direction != 0:
		_fade_progress += _fading_direction * (delta / fade_time)
		_fade_progress = clampf(_fade_progress, 0.0, 1.0)
		
		if _fade_progress <= 0.0 and _fading_direction < 0:
			_fading_direction = 0
			_set_solid(false)
		elif _fade_progress >= 1.0 and _fading_direction > 0:
			_fading_direction = 0
	
	# Phase cycling
	var cycle_time := visible_duration + invisible_duration
	var cycle_pos := fmod(_phase_timer, cycle_time)
	
	if _is_solid and cycle_pos >= visible_duration and _fading_direction == 0:
		# Start fading out
		_fading_direction = -1
	elif not _is_solid and cycle_pos < visible_duration and _fading_direction == 0:
		# Start fading in
		_fading_direction = 1
		_set_solid(true)
	
	# Warning pulse
	if _is_solid and _fading_direction == 0:
		var time_until_fade := visible_duration - cycle_pos
		_warning_active = pulse_when_about_to_change and time_until_fade < warning_time and time_until_fade > 0
	else:
		_warning_active = false
	
	# Apply visual alpha
	var target_alpha := _fade_progress
	if ghost_when_invisible and _fade_progress <= 0.0:
		target_alpha = ghost_alpha
	
	if _warning_active:
		# Pulsing warning effect
		var pulse := 0.5 + sin(_time_elapsed * 8.0) * 0.3
		target_alpha = minf(target_alpha, pulse + 0.2)
	
	modulate.a = target_alpha


func _set_solid(solid: bool) -> void:
	_is_solid = solid
	_collision_shape.disabled = not solid
	phase_changed.emit(solid)


func _draw_platform_details(rect: Rect2) -> void:
	# Phase indicator dots
	var dot_count := 5
	var dot_spacing := rect.size.x / float(dot_count + 1)
	var center_y := rect.position.y + rect.size.y / 2.0
	
	for i in range(dot_count):
		var dx: float = rect.position.x + dot_spacing * (i + 1)
		var dot_alpha := _fade_progress * 0.4
		
		if _warning_active:
			dot_alpha *= (0.5 + sin(_time_elapsed * 10.0 + i * 0.5) * 0.5)
		
		var dot_color := Color(1.0, 1.0, 1.0, dot_alpha)
		draw_circle(Vector2(dx, center_y), 2.0, dot_color)
	
	# Ghost outline when invisible
	if not _is_solid and ghost_when_invisible:
		var ghost_color := Color(outline_color.r, outline_color.g, outline_color.b, ghost_alpha * 0.5)
		draw_rect(rect, ghost_color, false, 1.0)
		
		# Dashed interior
		var dash_color := Color(0.7, 0.5, 0.9, ghost_alpha * 0.3)
		var dash_len := 6.0
		var gap_len := 4.0
		var x := rect.position.x + 4
		while x < rect.position.x + rect.size.x - dash_len:
			draw_line(
				Vector2(x, center_y),
				Vector2(x + dash_len, center_y),
				dash_color, 1.0
			)
			x += dash_len + gap_len


func is_currently_solid() -> bool:
	return _is_solid


func force_phase(solid: bool) -> void:
	_is_solid = solid
	_fade_progress = 1.0 if solid else 0.0
	_fading_direction = 0
	_set_solid(solid)
	modulate.a = _fade_progress if solid or not ghost_when_invisible else ghost_alpha
