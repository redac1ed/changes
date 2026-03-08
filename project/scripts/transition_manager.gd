extends CanvasLayer

## Scene Transition Manager
## Handles fade transitions, world title cards, and loading screens
## Add as child to main scenes or autoload

@export var default_fade_duration: float = 0.5
@export var default_color: Color = Color.BLACK

# --- Nodes ---
var fade_rect: ColorRect
var title_label: Label
var subtitle_label: Label
var loading_spinner: Control

# --- State ---
var is_transitioning: bool = false

signal transition_started
signal transition_midpoint  # When fully faded/covered
signal transition_completed


func _ready() -> void:
	layer = 100  # Above everything
	_create_ui()


func _create_ui() -> void:
	# Fade rectangle
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)
	
	# Center container for title card
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)
	
	# Title label
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 64)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.modulate.a = 0
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_label)
	
	# Subtitle label
	subtitle_label = Label.new()
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 24)
	subtitle_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	subtitle_label.modulate.a = 0
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(subtitle_label)
	
	# Loading spinner (simple rotating dots)
	loading_spinner = _create_spinner()
	loading_spinner.position = Vector2(get_viewport().size.x / 2, get_viewport().size.y - 100)
	loading_spinner.visible = false
	add_child(loading_spinner)


func _create_spinner() -> Control:
	var spinner := Control.new()
	spinner.custom_minimum_size = Vector2(50, 50)
	
	# Add spinning animation via script
	var script := GDScript.new()
	script.source_code = """
extends Control

var _time: float = 0.0

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var dot_count := 8
	var radius := 20.0
	for i in range(dot_count):
		var angle := float(i) / dot_count * TAU + _time * 4
		var pos := Vector2(cos(angle), sin(angle)) * radius
		var alpha := (float(i) / dot_count + 0.2)
		draw_circle(pos, 4, Color(1, 1, 1, alpha))
"""
	spinner.set_script(script)
	return spinner


# ===========================================================================
#  SIMPLE TRANSITIONS
# ===========================================================================

func fade_out(duration: float = -1, color: Color = Color(-1, -1, -1, -1)) -> void:
	if duration < 0:
		duration = default_fade_duration
	if color.r < 0:
		color = default_color
	
	is_transitioning = true
	transition_started.emit()
	
	fade_rect.color = Color(color.r, color.g, color.b, 0)
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, duration)
	tween.tween_callback(func():
		transition_midpoint.emit()
	)


func fade_in(duration: float = -1) -> void:
	if duration < 0:
		duration = default_fade_duration
	
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, duration)
	tween.tween_callback(func():
		is_transitioning = false
		transition_completed.emit()
	)


func fade_to_scene(scene_path: String, duration: float = -1, color: Color = Color(-1, -1, -1, -1)) -> void:
	if duration < 0:
		duration = default_fade_duration
	if color.r < 0:
		color = default_color
	
	is_transitioning = true
	transition_started.emit()
	
	fade_rect.color = Color(color.r, color.g, color.b, 0)
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, duration)
	tween.tween_callback(func():
		transition_midpoint.emit()
		get_tree().change_scene_to_file(scene_path)
	)
	tween.tween_interval(0.1)  # Brief pause after scene load
	tween.tween_property(fade_rect, "color:a", 0.0, duration)
	tween.tween_callback(func():
		is_transitioning = false
		transition_completed.emit()
	)


# ===========================================================================
#  WORLD TITLE CARD TRANSITIONS
# ===========================================================================

func transition_to_world(world: int, scene_path: String) -> void:
	is_transitioning = true
	transition_started.emit()
	
	var world_name := _get_world_name(world)
	var world_subtitle := _get_world_subtitle(world)
	var world_color := _get_world_color(world)
	
	title_label.text = world_name
	title_label.add_theme_color_override("font_color", world_color)
	subtitle_label.text = world_subtitle
	
	# Fade to color
	fade_rect.color = Color(0, 0, 0, 0)
	var tween := create_tween()
	
	# Fade out
	tween.tween_property(fade_rect, "color:a", 1.0, 0.5)
	
	# Show title card
	tween.tween_callback(func():
		transition_midpoint.emit()
		get_tree().change_scene_to_file(scene_path)
	)
	tween.tween_property(title_label, "modulate:a", 1.0, 0.3)
	tween.tween_property(subtitle_label, "modulate:a", 1.0, 0.3)
	
	# Hold
	tween.tween_interval(1.5)
	
	# Fade out title
	tween.set_parallel(true)
	tween.tween_property(title_label, "modulate:a", 0.0, 0.3)
	tween.tween_property(subtitle_label, "modulate:a", 0.0, 0.3)
	tween.set_parallel(false)
	
	# Fade in scene
	tween.tween_property(fade_rect, "color:a", 0.0, 0.5)
	tween.tween_callback(func():
		is_transitioning = false
		transition_completed.emit()
	)


func show_world_title(world: int, duration: float = 2.0) -> void:
	var world_name := _get_world_name(world)
	var world_subtitle := _get_world_subtitle(world)
	var world_color := _get_world_color(world)
	
	title_label.text = world_name
	title_label.add_theme_color_override("font_color", world_color)
	subtitle_label.text = world_subtitle
	
	var tween := create_tween()
	tween.tween_property(title_label, "modulate:a", 1.0, 0.3)
	tween.tween_property(subtitle_label, "modulate:a", 0.8, 0.3)
	tween.tween_interval(duration)
	tween.set_parallel(true)
	tween.tween_property(title_label, "modulate:a", 0.0, 0.5)
	tween.tween_property(subtitle_label, "modulate:a", 0.0, 0.5)


# ===========================================================================
#  SPECIAL TRANSITIONS
# ===========================================================================

func circle_wipe_out(duration: float = 0.8, center: Vector2 = Vector2(-1, -1)) -> void:
	if center.x < 0:
		center = get_viewport().size / 2
	
	is_transitioning = true
	transition_started.emit()
	
	# Create circle wipe shader material (simplified - just fade for now)
	fade_out(duration)


func diamond_transition(duration: float = 0.6) -> void:
	# Simplified - use fade
	fade_out(duration)


func show_loading(show: bool = true) -> void:
	loading_spinner.visible = show


# ===========================================================================
#  WORLD DATA
# ===========================================================================

func _get_world_name(world: int) -> String:
	match world:
		1: return "Meadow"
		2: return "Volcano"
		3: return "Sky"
		4: return "Ocean"
		5: return "Space"
		6: return "Victory"
		_: return "World %d" % world


func _get_world_subtitle(world: int) -> String:
	match world:
		1: return "Gentle rolling hills"
		2: return "Fiery obstacles await"
		3: return "Floating through clouds"
		4: return "Dive into the deep"
		5: return "Among the stars"
		6: return "Congratulations!"
		_: return ""


func _get_world_color(world: int) -> Color:
	match world:
		1: return Color(0.45, 0.82, 0.45)
		2: return Color(1.0, 0.4, 0.2)
		3: return Color(0.6, 0.85, 1.0)
		4: return Color(0.2, 0.6, 0.9)
		5: return Color(0.6, 0.3, 0.9)
		6: return Color(1.0, 0.85, 0.4)
		_: return Color.WHITE


# ===========================================================================
#  UTILITIES
# ===========================================================================

func instant_black() -> void:
	fade_rect.color = Color.BLACK


func instant_clear() -> void:
	fade_rect.color = Color(0, 0, 0, 0)


func set_fade_color(color: Color) -> void:
	fade_rect.color = color
