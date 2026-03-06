extends CanvasLayer
class_name PauseOverlay

const SCREEN_W := 1200.0
const SCREEN_H := 800.0

signal resumed
signal restarted
signal quit_to_menu

const BG_DIM := Color(0.01, 0.01, 0.04, 0.75)
const PANEL_BG := Color(0.06, 0.08, 0.14, 0.95)
const PANEL_BORDER := Color(0.3, 0.4, 0.65, 0.5)
const TEXT_COLOR := Color(0.9, 0.92, 0.95)
const HIGHLIGHT := Color(0.45, 0.78, 1.0)
const DIM_TEXT := Color(0.55, 0.55, 0.6)

enum PauseView { MAIN, SETTINGS }

var _view: PauseView = PauseView.MAIN
var _selected: int = 0
var _menu_items: Array[String] = ["Resume", "Restart", "Settings", "Quit to Menu"]
var _settings_items: Array[String] = ["Music Volume", "SFX Volume", "Master Volume", "Screen Shake", "Show Trajectory", "Back"]
var _settings_values: Array = []
var _is_active: bool = false
var _anim_time: float = 0.0
var _glow_offsets: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
var _draw_node: Control

func _ready() -> void:
	layer = 25
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_draw_node = Control.new()
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.draw.connect(_on_draw)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_draw_node)
	_load_settings_values()

func toggle_pause() -> void:
	if _is_active:
		_unpause()
	else:
		_pause()

func _pause() -> void:
	_is_active = true
	_view = PauseView.MAIN
	_selected = 0
	_anim_time = 0.0
	visible = true
	get_tree().paused = true
	_load_settings_values()

func _unpause() -> void:
	_is_active = false
	visible = false
	get_tree().paused = false
	resumed.emit()

func _load_settings_values() -> void:
	if GameState:
		_settings_values = [
			GameState.get_setting("audio", "music"),
			GameState.get_setting("audio", "sfx"),
			GameState.get_setting("audio", "master"),
			GameState.get_setting("video", "shake") > 0.0,
			GameState.get_setting("gameplay", "show_trajectory"),
			0,  # back button placeholder
		]
		# Handle potential nulls
		if _settings_values[0] == null: _settings_values[0] = 0.7
		if _settings_values[1] == null: _settings_values[1] = 0.8
		if _settings_values[2] == null: _settings_values[2] = 1.0
		if _settings_values[3] == null: _settings_values[3] = true
		if _settings_values[4] == null: _settings_values[4] = true
	else:
		_settings_values = [0.7, 0.8, 1.0, true, true, 0]

func _process(delta: float) -> void:
	if not _is_active:
		return
	_anim_time += delta
	var items := _menu_items if _view == PauseView.MAIN else _settings_items
	for i in range(items.size()):
		var target := 1.0 if i == _selected else 0.0
		_glow_offsets[i] = move_toward(_glow_offsets[i], target, delta * 6.0)
	_draw_node.queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _is_active:
			if _view == PauseView.SETTINGS:
				_view = PauseView.MAIN
				_selected = 2
			else:
				_unpause()
			get_viewport().set_input_as_handled()
		else:
			_pause()
			get_viewport().set_input_as_handled()
		return
	if not _is_active:
		return
	if event is InputEventKey and event.pressed:
		var items := _menu_items if _view == PauseView.MAIN else _settings_items
		var count := items.size()
		match event.keycode:
			KEY_UP, KEY_W:
				_selected = (_selected - 1 + count) % count
			KEY_DOWN, KEY_S:
				_selected = (_selected + 1) % count
			KEY_LEFT, KEY_A:
				if _view == PauseView.SETTINGS:
					_adjust_setting(-1)
			KEY_RIGHT, KEY_D:
				if _view == PauseView.SETTINGS:
					_adjust_setting(1)
			KEY_ENTER, KEY_SPACE:
				_select_item()
		get_viewport().set_input_as_handled()

func _adjust_setting(dir: int) -> void:
	match _selected:
		0, 1, 2:  # Volume sliders
			var val: float = _settings_values[_selected]
			val = clamp(val + dir * 0.1, 0.0, 1.0)
			_settings_values[_selected] = val
			if GameState:
				var key = ""
				match _selected:
					0: key = "music"
					1: key = "sfx"
					2: key = "master"
				GameState.set_setting("audio", key, val)
		3:  # Screen shake toggle
			_settings_values[3] = not _settings_values[3]
			if GameState:
				GameState.set_setting("video", "shake", 1.0 if _settings_values[3] else 0.0)
		4:  # Trajectory toggle
			_settings_values[4] = not _settings_values[4]
			if GameState:
				GameState.set_setting("gameplay", "show_trajectory", _settings_values[4])

func _select_item() -> void:
	if _view == PauseView.MAIN:
		match _selected:
			0: _unpause()
			1:
				_unpause()
				restarted.emit()
				get_tree().reload_current_scene()
			2:
				_view = PauseView.SETTINGS
				_selected = 0
			3:
				_unpause()
				quit_to_menu.emit()
	else:
		match _selected:
			3:  # Toggle screen shake
				_adjust_setting(0)
			4:  # Toggle trajectory
				_adjust_setting(0)
			5:  # Back
				_view = PauseView.MAIN
				_selected = 2

func _on_draw() -> void:
	# Dimmed background
	var dim_a: float = min(_anim_time * 4.0, 1.0) * 0.75
	_draw_node.draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), Color(0.01, 0.01, 0.04, dim_a), true)
	if _view == PauseView.MAIN:
		_draw_main_menu()
	else:
		_draw_settings()

func _draw_main_menu() -> void:
	var font := ThemeDB.fallback_font
	var cx := SCREEN_W / 2.0
	var pw := 300.0
	var ph := 260.0
	var px := cx - pw / 2.0
	var py := (SCREEN_H - ph) / 2.0
	
	# Panel
	_draw_node.draw_rect(Rect2(px, py, pw, ph), PANEL_BG, true)
	_draw_node.draw_rect(Rect2(px, py, pw, ph), PANEL_BORDER, false, 2.0)
	
	# Title
	_draw_node.draw_string(font, Vector2(cx - 30, py + 35), "PAUSED", HORIZONTAL_ALIGNMENT_CENTER, 60, 22, TEXT_COLOR)
	
	# Divider
	_draw_node.draw_line(Vector2(px + 20, py + 50), Vector2(px + pw - 20, py + 50), PANEL_BORDER, 1.0)
	
	# Menu items
	var item_y := py + 80
	for i in range(_menu_items.size()):
		var is_sel := i == _selected
		var glow := _glow_offsets[i]
		if glow > 0:
			var sel_bg := Color(HIGHLIGHT.r, HIGHLIGHT.g, HIGHLIGHT.b, 0.1 * glow)
			_draw_node.draw_rect(Rect2(px + 15, item_y - 8, pw - 30, 32), sel_bg, true)
		if is_sel:
			_draw_node.draw_string(font, Vector2(px + 25, item_y + 12), "▸", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, HIGHLIGHT)
		var text_c := HIGHLIGHT if is_sel else TEXT_COLOR.darkened(0.15)
		_draw_node.draw_string(font, Vector2(px + 45, item_y + 12), _menu_items[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, text_c)
		item_y += 42

func _draw_settings() -> void:
	var font := ThemeDB.fallback_font
	var cx := SCREEN_W / 2.0
	var pw := 380.0
	var ph := 360.0
	var px := cx - pw / 2.0
	var py := (SCREEN_H - ph) / 2.0
	
	# Panel
	_draw_node.draw_rect(Rect2(px, py, pw, ph), PANEL_BG, true)
	_draw_node.draw_rect(Rect2(px, py, pw, ph), PANEL_BORDER, false, 2.0)
	
	# Title
	_draw_node.draw_string(font, Vector2(cx - 35, py + 35), "SETTINGS", HORIZONTAL_ALIGNMENT_CENTER, 70, 20, TEXT_COLOR)
	_draw_node.draw_line(Vector2(px + 20, py + 50), Vector2(px + pw - 20, py + 50), PANEL_BORDER, 1.0)
	
	var item_y := py + 75
	for i in range(_settings_items.size()):
		var is_sel := i == _selected
		var glow := _glow_offsets[i] if i < _glow_offsets.size() else 0.0
		if glow > 0:
			var sel_bg := Color(HIGHLIGHT.r, HIGHLIGHT.g, HIGHLIGHT.b, 0.08 * glow)
			_draw_node.draw_rect(Rect2(px + 10, item_y - 10, pw - 20, 36), sel_bg, true)
		var label_c := HIGHLIGHT if is_sel else TEXT_COLOR.darkened(0.15)
		_draw_node.draw_string(font, Vector2(px + 25, item_y + 10), _settings_items[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, label_c)
		# Value display
		if i <= 2:  # Volume sliders
			var val: float = _settings_values[i] if i < _settings_values.size() else 0.0
			var slider_x := px + 200
			var slider_w := 140.0
			var slider_y := item_y + 4
			
			# Track
			_draw_node.draw_rect(Rect2(slider_x, slider_y, slider_w, 6), Color(0.2, 0.2, 0.25), true)
			# Fill
			_draw_node.draw_rect(Rect2(slider_x, slider_y, slider_w * val, 6), HIGHLIGHT.darkened(0.1), true)
			# Thumb
			var thumb_x := slider_x + slider_w * val
			_draw_node.draw_circle(Vector2(thumb_x, slider_y + 3), 5.0, HIGHLIGHT if is_sel else DIM_TEXT)
			# Percentage
			_draw_node.draw_string(font, Vector2(slider_x + slider_w + 10, item_y + 10), "%d%%" % int(val * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DIM_TEXT)
		
		elif i == 3 or i == 4:  # Toggles
			var val: bool = _settings_values[i] if i < _settings_values.size() else false
			var toggle_x := px + 280
			var toggle_text := "ON" if val else "OFF"
			var toggle_c := Color(0.3, 0.9, 0.4) if val else Color(0.7, 0.3, 0.3)
			_draw_node.draw_string(font, Vector2(toggle_x, item_y + 10), toggle_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, toggle_c)

		elif i == 5:  # Back button
			if is_sel:
				_draw_node.draw_string(font, Vector2(px + 15, item_y + 10), "◂", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, HIGHLIGHT)
	
		item_y += 44
	# Navigation hint
	_draw_node.draw_string(font, Vector2(cx - 80, py + ph - 15), "← → to adjust · Enter to select", HORIZONTAL_ALIGNMENT_CENTER, 160, 11, DIM_TEXT)
