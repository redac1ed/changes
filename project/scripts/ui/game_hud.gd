extends CanvasLayer
class_name GameHUD

const SCREEN_W := 1200.0
const SCREEN_H := 800.0

const HUD_MARGIN := 16.0
const HUD_BG_COLOR := Color(0.08, 0.08, 0.12, 0.65)
const HUD_BORDER_COLOR := Color(0.3, 0.35, 0.5, 0.5)
const HUD_TEXT_COLOR := Color(0.9, 0.92, 0.95)
const HUD_ACCENT := Color(0.45, 0.78, 1.0)
const STAR_COLOR := Color(1.0, 0.92, 0.35)
const COMBO_COLOR := Color(1.0, 0.55, 0.2)

const PANEL_CORNER := 6.0
const ICON_SIZE := 16.0

var shot_count: int = 0
var combo_multiplier: int = 1
var combo_timer: float = 0.0
var level_time: float = 0.0
var is_paused: bool = false
var world_name: String = "Meadow"
var level_number: int = 1

var _notifications: Array[Dictionary] = []
var _notification_lifetime: float = 3.0

var _shot_flash: float = 0.0
var _combo_scale: float = 1.0
var _time_elapsed: float = 0.0
var _score_popup_items: Array[Dictionary] = []

var _draw_node: Control

func _ready() -> void:
	layer = 10
	
	_draw_node = Control.new()
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_node.draw.connect(_on_draw)
	add_child(_draw_node)
	
	if GameState and GameState.has_signal("level_completed_event"):
		GameState.level_completed_event.connect(_on_level_completed)


func _process(delta: float) -> void:
	if is_paused:
		return
	
	_time_elapsed += delta
	
	# Animations
	if _shot_flash > 0:
		_shot_flash -= delta * 3.0
	if combo_timer > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo_multiplier = 1
	if _combo_scale > 1.0:
		_combo_scale = move_toward(_combo_scale, 1.0, delta * 4.0)
	
	# Update notifications
	var i := _notifications.size() - 1
	while i >= 0:
		_notifications[i]["time"] += delta
		if _notifications[i]["time"] >= _notification_lifetime:
			_notifications.remove_at(i)
		i -= 1
	
	# Update score popups
	i = _score_popup_items.size() - 1
	while i >= 0:
		_score_popup_items[i]["time"] += delta
		_score_popup_items[i]["y"] -= delta * 40.0
		if _score_popup_items[i]["time"] >= 1.5:
			_score_popup_items.remove_at(i)
		i -= 1
	
	_draw_node.queue_redraw()

func add_shot() -> void:
	shot_count += 1
	_shot_flash = 1.0

func show_notification(text: String, color: Color = HUD_TEXT_COLOR) -> void:
	_notifications.append({
		"text": text,
		"color": color,
		"time": 0.0,
	})
	if _notifications.size() > 5:
		_notifications.pop_front()

func show_score_popup(points: int, pos: Vector2 = Vector2(-1, -1)) -> void:
	if pos.x < 0:
		pos = Vector2(SCREEN_W / 2.0, SCREEN_H / 2.0 - 50)
	_score_popup_items.append({
		"points": points,
		"x": pos.x,
		"y": pos.y,
		"time": 0.0,
	})

func reset_hud() -> void:
	shot_count = 0
	combo_multiplier = 1
	combo_timer = 0.0
	level_time = 0.0
	_notifications.clear()
	_score_popup_items.clear()

func set_level_info(world: int, level: int) -> void:
	if GameState:
		world_name = GameState.get_world_name(world)
	level_number = level

func _on_level_completed(_world: int, _level: int, stats: Dictionary) -> void:
	var stars: int = stats.get("stars", 0)
	var rating := ""
	match stars:
		3: rating = "★★★ Perfect!"
		2: rating = "★★☆ Great!"
		1: rating = "★☆☆ Good"
		_: rating = "☆☆☆ Keep Trying"
	show_notification(rating, STAR_COLOR)

func _on_draw() -> void:
	_draw_top_bar()
	_draw_shot_counter()
	_draw_timer()
	_draw_combo_display()
	_draw_level_indicator()
	_draw_notifications()
	_draw_score_popups()
	_draw_star_preview()

func _draw_top_bar() -> void:
	# Subtle gradient bar across top
	var bar_h := 44.0
	for i in range(int(bar_h)):
		var t := float(i) / bar_h
		var alpha: float = lerp(0.55, 0.0, t * t)
		var c := Color(0.03, 0.03, 0.08, alpha)
		_draw_node.draw_line(
			Vector2(0, i), Vector2(SCREEN_W, i), c, 1.0
		)
	# Bottom edge
	_draw_node.draw_line(
		Vector2(0, bar_h), Vector2(SCREEN_W, bar_h),
		Color(0.3, 0.35, 0.55, 0.25), 1.0
	)

func _draw_shot_counter() -> void:
	var x := HUD_MARGIN + 8
	var y := 12.0
	var panel := Rect2(x - 4, y - 2, 100, 28)
	_draw_panel(panel)
	# Arrow icon for shots
	var ix := x + 10
	var iy := y + 13
	var shot_c := HUD_ACCENT
	if _shot_flash > 0:
		shot_c = shot_c.lerp(Color.WHITE, _shot_flash)
	# Arrow shape
	_draw_node.draw_line(Vector2(ix, iy), Vector2(ix + 12, iy), shot_c, 2.0)
	_draw_node.draw_line(Vector2(ix + 8, iy - 4), Vector2(ix + 12, iy), shot_c, 2.0)
	_draw_node.draw_line(Vector2(ix + 8, iy + 4), Vector2(ix + 12, iy), shot_c, 2.0)
	var font := ThemeDB.fallback_font
	_draw_node.draw_string(font, Vector2(ix + 18, iy + 5), "%d" % shot_count, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, HUD_TEXT_COLOR)

func _draw_timer() -> void:
	var x := SCREEN_W - HUD_MARGIN - 120
	var y := 12.0
	var panel := Rect2(x - 4, y - 2, 120, 28)
	_draw_panel(panel)
	var mins := int(level_time) / 60
	var secs := int(level_time) % 60
	var ms := int(fmod(level_time, 1.0) * 100)
	var time_str := "%d:%02d.%02d" % [mins, secs, ms]
	
	# Clock icon
	var cx := x + 12
	var cy := y + 13
	_draw_node.draw_arc(Vector2(cx, cy), 7.0, 0, TAU, 12, HUD_TEXT_COLOR.darkened(0.2), 1.5)
	_draw_node.draw_line(Vector2(cx, cy), Vector2(cx, cy - 5), HUD_TEXT_COLOR, 1.5)
	_draw_node.draw_line(Vector2(cx, cy), Vector2(cx + 3, cy + 1), HUD_TEXT_COLOR, 1.5)
	var font := ThemeDB.fallback_font
	_draw_node.draw_string(font, Vector2(cx + 12, cy + 5), time_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, HUD_TEXT_COLOR.darkened(0.1))

func _draw_combo_display() -> void:
	if combo_multiplier <= 1:
		return
	
	var x := SCREEN_W / 2.0
	var y := 16.0
	var text := "x%d COMBO" % combo_multiplier
	var font := ThemeDB.fallback_font
	var font_size := int(20 * _combo_scale)
	
	# Glow behind
	var glow_alpha := 0.3 * (combo_timer / 3.0)
	var glow_color := Color(COMBO_COLOR.r, COMBO_COLOR.g, COMBO_COLOR.b, glow_alpha)
	_draw_node.draw_circle(Vector2(x, y + 8), 25.0 * _combo_scale, glow_color)
	# Text shadow
	_draw_node.draw_string(font, Vector2(x - 40 + 1, y + 15 + 1), text, HORIZONTAL_ALIGNMENT_CENTER, 80, font_size, Color(0, 0, 0, 0.5))
	# Text
	var combo_c := COMBO_COLOR
	if combo_multiplier >= 4:
		combo_c = COMBO_COLOR.lerp(Color(1, 0.2, 0.2), sin(_time_elapsed * 6.0) * 0.5 + 0.5)
	_draw_node.draw_string(font, Vector2(x - 40, y + 15), text, HORIZONTAL_ALIGNMENT_CENTER, 80, font_size, combo_c)

func _draw_level_indicator() -> void:
	var font := ThemeDB.fallback_font
	var text := "%s - Level %d" % [world_name, level_number]
	var x := SCREEN_W / 2.0 - 60
	var y := SCREEN_H - 14.0
	
	# Subtle bottom bar
	var bar_y := SCREEN_H - 30
	for i in range(30):
		var t := float(i) / 30.0
		var alpha: float = lerp(0.0, 0.35, t * t)
		_draw_node.draw_line(
			Vector2(0, bar_y + i), Vector2(SCREEN_W, bar_y + i),
			Color(0.03, 0.03, 0.08, alpha), 1.0
		)
	
	_draw_node.draw_string(font, Vector2(x + 1, y + 1), text, HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(0, 0, 0, 0.5))
	_draw_node.draw_string(font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_CENTER, 120, 13, HUD_TEXT_COLOR.darkened(0.2))

func _draw_star_preview() -> void:
	# Show expected star rating based on current shots
	var stars := GameState.calculate_stars(shot_count) if GameState else 0
	var x := HUD_MARGIN + 250
	var y := 18.0
	for i in range(3):
		var star_x := x + i * 18.0
		var is_filled := i < stars
		var fill := STAR_COLOR if is_filled else Color(0.3, 0.3, 0.35, 0.5)
		_draw_star(Vector2(star_x, y), 7.0, fill)

func _draw_notifications() -> void:
	var font := ThemeDB.fallback_font
	var y := 60.0
	for note in _notifications:
		var alpha := 1.0
		if note["time"] > _notification_lifetime - 0.5:
			alpha = (_notification_lifetime - note["time"]) / 0.5
		elif note["time"] < 0.3:
			alpha = note["time"] / 0.3
		var slide_x := 0.0
		if note["time"] < 0.2:
			slide_x = (1.0 - note["time"] / 0.2) * -50.0
		var c: Color = note["color"]
		c.a = alpha
		var bg := Color(0.05, 0.05, 0.1, 0.7 * alpha)
		var rect := Rect2(SCREEN_W - 280 + slide_x, y - 4, 260, 26)
		_draw_node.draw_rect(rect, bg, true)
		_draw_node.draw_rect(rect, Color(c.r, c.g, c.b, 0.3 * alpha), false, 1.0)
		_draw_node.draw_string(font, Vector2(SCREEN_W - 270 + slide_x, y + 12), note["text"], HORIZONTAL_ALIGNMENT_LEFT, 240, 14, c)
		y += 32

func _draw_score_popups() -> void:
	var font := ThemeDB.fallback_font
	for popup in _score_popup_items:
		var alpha: float = 1.0 - (popup["time"] / 1.5)
		var scale: float = 1.0 + popup["time"] * 0.3
		var c := HUD_ACCENT
		c.a = alpha
		var text := "+%d" % popup["points"]
		var size := int(18 * scale)
		_draw_node.draw_string(font, Vector2(popup["x"] + 1, popup["y"] + 1), text, HORIZONTAL_ALIGNMENT_CENTER, 80, size, Color(0, 0, 0, alpha * 0.5))
		_draw_node.draw_string(font, Vector2(popup["x"], popup["y"]), text, HORIZONTAL_ALIGNMENT_CENTER, 80, size, c)

func _draw_panel(rect: Rect2) -> void:
	_draw_node.draw_rect(rect, HUD_BG_COLOR, true)
	_draw_node.draw_rect(rect, HUD_BORDER_COLOR, false, 1.0)

func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(10):
		var angle := -PI / 2 + i * TAU / 10
		var r := radius if i % 2 == 0 else radius * 0.4
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	_draw_node.draw_colored_polygon(points, color)
