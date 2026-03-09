extends CanvasLayer
class_name SubtitleOverlay

const FADE_IN_DURATION  := 0.35
const FADE_OUT_DURATION := 0.45

var _container: Control
var _label: Label
var _tween: Tween

func _ready() -> void:
	layer = 12
	_container = Control.new()
	_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_container.offset_top    = -68.0
	_container.offset_bottom =   0.0
	_container.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_container.modulate.a    = 0.0
	add_child(_container)

	# Dark letterbox strip
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.62)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.add_child(bg)

	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 18)
	_label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.90))
	_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	_label.add_theme_constant_override("shadow_offset_x", 1)
	_label.add_theme_constant_override("shadow_offset_y", 1)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.add_child(_label)

func show_line(text: String) -> void:
	_label.text = text
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_container, "modulate:a", 1.0, FADE_IN_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func hide_line(on_done: Callable = Callable()) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_container, "modulate:a", 0.0, FADE_OUT_DURATION) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	if on_done.is_valid():
		_tween.tween_callback(on_done)

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
