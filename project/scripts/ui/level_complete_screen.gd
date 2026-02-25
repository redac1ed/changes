extends CanvasLayer
class_name LevelCompleteScreen

## ═══════════════════════════════════════════════════════════════════════════════
## LevelCompleteScreen — Animated overlay shown when a level is finished
## ═══════════════════════════════════════════════════════════════════════════════
##
## Features star reveal animation, shot summary, coin tally, and buttons
## for next level / retry / menu. All custom _draw().

const SCREEN_W := 1200.0
const SCREEN_H := 800.0

# ─── Signals ─────────────────────────────────────────────────────────────────
signal next_level_pressed
signal retry_pressed
signal menu_pressed

# ─── Colors ──────────────────────────────────────────────────────────────────
const BG_COLOR := Color(0.02, 0.02, 0.06, 0.85)
const PANEL_BG := Color(0.08, 0.1, 0.18, 0.95)
const PANEL_BORDER := Color(0.35, 0.45, 0.7, 0.6)
const TEXT_COLOR := Color(0.92, 0.93, 0.96)
const STAR_FILLED := Color(1.0, 0.92, 0.35)
const STAR_EMPTY := Color(0.35, 0.35, 0.4, 0.5)
const ACCENT := Color(0.45, 0.78, 1.0)
const SUCCESS_COLOR := Color(0.3, 0.9, 0.45)

# ─── State ───────────────────────────────────────────────────────────────────
var shots_taken: int = 0
var stars_earned: int = 0
var coins_collected: int = 0
var total_coins: int = 0
var is_new_record: bool = false
var level_time: float = 0.0

# ─── Animation ───────────────────────────────────────────────────────────────
var _anim_time: float = 0.0
var _star_reveal_times: Array[float] = [0.5, 0.9, 1.3]
var _stars_revealed: int = 0
var _panel_scale: float = 0.0
var _show_buttons: bool = false
var _selected_button: int = 0  # 0=next, 1=retry, 2=menu
var _button_hover: Array[float] = [0.0, 0.0, 0.0]
var _active: bool = false
var _sparkle_particles: Array[Dictionary] = []

var _draw_node: Control


func _ready() -> void:
	layer = 20
	visible = false
	
	_draw_node = Control.new()
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.draw.connect(_on_draw)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_draw_node)


func show_screen(p_shots: int, p_stars: int, p_coins: int, p_total_coins: int, p_new_record: bool, p_time: float) -> void:
	shots_taken = p_shots
	stars_earned = p_stars
	coins_collected = p_coins
	total_coins = p_total_coins
	is_new_record = p_new_record
	level_time = p_time
	
	_anim_time = 0.0
	_stars_revealed = 0
	_panel_scale = 0.0
	_show_buttons = false
	_selected_button = 0
	_button_hover = [0.0, 0.0, 0.0]
	_active = true
	_sparkle_particles.clear()
	visible = true


func hide_screen() -> void:
	_active = false
	visible = false


func _process(delta: float) -> void:
	if not _active:
		return
	
	_anim_time += delta
	
	# Panel scale in
	if _panel_scale < 1.0:
		_panel_scale = min(_panel_scale + delta * 3.0, 1.0)
	
	# Star reveals
	for i in range(3):
		if i < stars_earned and _stars_revealed <= i and _anim_time >= _star_reveal_times[i]:
			_stars_revealed = i + 1
			_spawn_star_sparkles(i)
	
	# Show buttons after stars
	if _anim_time > 2.0:
		_show_buttons = true
	
	# Update sparkles
	var idx := _sparkle_particles.size() - 1
	while idx >= 0:
		_sparkle_particles[idx]["time"] += delta
		_sparkle_particles[idx]["x"] += _sparkle_particles[idx]["vx"] * delta
		_sparkle_particles[idx]["y"] += _sparkle_particles[idx]["vy"] * delta
		_sparkle_particles[idx]["vy"] += 120.0 * delta  # gravity
		if _sparkle_particles[idx]["time"] > 1.0:
			_sparkle_particles.remove_at(idx)
		idx -= 1
	
	# Button hover effects
	for i in range(3):
		var target := 1.0 if i == _selected_button else 0.0
		_button_hover[i] = move_toward(_button_hover[i], target, delta * 5.0)
	
	_draw_node.queue_redraw()


func _input(event: InputEvent) -> void:
	if not _active or not _show_buttons:
		return
	
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT, KEY_A:
				_selected_button = max(0, _selected_button - 1)
			KEY_RIGHT, KEY_D:
				_selected_button = min(2, _selected_button + 1)
			KEY_ENTER, KEY_SPACE:
				_press_button()
			KEY_ESCAPE:
				menu_pressed.emit()
	
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mx: float = event.position.x
		var my: float = event.position.y
		var btn_y := SCREEN_H / 2.0 + 130.0
		var btn_h := 38.0
		if my >= btn_y - 5 and my <= btn_y + btn_h + 5:
			var centers := [SCREEN_W / 2.0 - 140, SCREEN_W / 2.0, SCREEN_W / 2.0 + 140]
			for i in range(3):
				if abs(mx - centers[i]) < 65:
					_selected_button = i
					_press_button()
					break


func _press_button() -> void:
	match _selected_button:
		0: next_level_pressed.emit()
		1: retry_pressed.emit()
		2: menu_pressed.emit()


func _spawn_star_sparkles(star_index: int) -> void:
	var cx := SCREEN_W / 2.0 + (star_index - 1) * 50.0
	var cy := SCREEN_H / 2.0 - 50.0
	for _i in range(8):
		var angle := randf() * TAU
		var speed := randf_range(50, 150)
		_sparkle_particles.append({
			"x": cx, "y": cy,
			"vx": cos(angle) * speed,
			"vy": sin(angle) * speed - 30,
			"time": 0.0,
			"size": randf_range(2, 5),
		})


func _on_draw() -> void:
	# Full screen dim
	var dim_alpha: float = min(_anim_time * 2.0, 1.0) * 0.85
	_draw_node.draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), Color(0.02, 0.02, 0.06, dim_alpha), true)
	
	if _panel_scale <= 0:
		return
	
	# Panel
	var pw := 420.0 * _panel_scale
	var ph := 340.0 * _panel_scale
	var px := (SCREEN_W - pw) / 2.0
	var py := (SCREEN_H - ph) / 2.0 - 20
	
	_draw_node.draw_rect(Rect2(px, py, pw, ph), PANEL_BG, true)
	_draw_node.draw_rect(Rect2(px, py, pw, ph), PANEL_BORDER, false, 2.0)
	
	if _panel_scale < 0.9:
		return
	
	var font := ThemeDB.fallback_font
	var cx := SCREEN_W / 2.0
	
	# Title
	_draw_node.draw_string(font, Vector2(cx - 80, py + 40), "Level Complete!", HORIZONTAL_ALIGNMENT_CENTER, 160, 24, SUCCESS_COLOR)
	
	# Stars
	var star_y := py + 80
	for i in range(3):
		var sx := cx + (i - 1) * 50.0
		var is_filled := i < _stars_revealed
		var color := STAR_FILLED if is_filled else STAR_EMPTY
		var radius := 18.0
		if is_filled and _anim_time - _star_reveal_times[i] < 0.3:
			var t := (_anim_time - _star_reveal_times[i]) / 0.3
			radius = 18.0 * (1.0 + (1.0 - t) * 0.5)
		_draw_star(Vector2(sx, star_y), radius, color)
	
	# Stats
	var stat_y := star_y + 45
	var left_x := cx - 80
	
	# Shots
	_draw_node.draw_string(font, Vector2(left_x, stat_y), "Shots:", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT_COLOR.darkened(0.2))
	_draw_node.draw_string(font, Vector2(left_x + 120, stat_y), "%d" % shots_taken, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ACCENT)
	
	# Coins
	stat_y += 28
	_draw_node.draw_string(font, Vector2(left_x, stat_y), "Coins:", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT_COLOR.darkened(0.2))
	var coin_text := "%d / %d" % [coins_collected, total_coins] if total_coins > 0 else "%d" % coins_collected
	_draw_node.draw_string(font, Vector2(left_x + 120, stat_y), coin_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.85, 0.3))
	
	# Time
	stat_y += 28
	var mins := int(level_time) / 60
	var secs := int(level_time) % 60
	_draw_node.draw_string(font, Vector2(left_x, stat_y), "Time:", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT_COLOR.darkened(0.2))
	_draw_node.draw_string(font, Vector2(left_x + 120, stat_y), "%d:%02d" % [mins, secs], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT_COLOR)
	
	# New record badge
	if is_new_record and _anim_time > 1.5:
		var badge_alpha: float = min((_anim_time - 1.5) * 3.0, 1.0)
		var badge_c := Color(1.0, 0.4, 0.2, badge_alpha)
		_draw_node.draw_string(font, Vector2(cx - 40, stat_y + 35), "★ NEW RECORD ★", HORIZONTAL_ALIGNMENT_CENTER, 80, 14, badge_c)
	
	# Buttons
	if _show_buttons:
		var btn_y := py + ph - 55
		var btn_labels := ["Next Level", "Retry", "Menu"]
		var btn_colors := [SUCCESS_COLOR, ACCENT, TEXT_COLOR.darkened(0.2)]
		
		for i in range(3):
			var bx := cx + (i - 1) * 140.0 - 55
			var by := btn_y
			var bw := 110.0
			var bh := 34.0
			
			var bg := PANEL_BG.lightened(0.1 + _button_hover[i] * 0.15)
			var border: Color = btn_colors[i]
			border.a = 0.5 + _button_hover[i] * 0.5
			
			_draw_node.draw_rect(Rect2(bx, by, bw, bh), bg, true)
			_draw_node.draw_rect(Rect2(bx, by, bw, bh), border, false, 1.5 + _button_hover[i])
			
			var text_c: Color = btn_colors[i]
			text_c.a = 0.7 + _button_hover[i] * 0.3
			_draw_node.draw_string(font, Vector2(bx + 8, by + 22), btn_labels[i], HORIZONTAL_ALIGNMENT_CENTER, bw - 16, 14, text_c)
	
	# Sparkle particles
	for p in _sparkle_particles:
		var alpha: float = 1.0 - p["time"]
		var c := Color(1.0, 0.95, 0.6, alpha)
		_draw_node.draw_circle(Vector2(p["x"], p["y"]), p["size"] * (1.0 - p["time"] * 0.5), c)


func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(10):
		var angle := -PI / 2 + i * TAU / 10
		var r := radius if i % 2 == 0 else radius * 0.4
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	_draw_node.draw_colored_polygon(points, color)
	# Outline
	points.append(points[0])
	_draw_node.draw_polyline(points, color.darkened(0.3), 1.5)
