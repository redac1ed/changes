extends Control

## Interactive Title Screen with animated menus
## Features: floating particles, bouncing ball, world select, settings, credits

# ─── Menu States ─────────────────────────────────────────────
enum MenuState { MAIN, WORLD_SELECT, SETTINGS, CREDITS }
var current_state: MenuState = MenuState.MAIN

# ─── World Data ──────────────────────────────────────────────
const WORLDS = [
	{"name": "Tutorial", "subtitle": "Learn the basics", "color": Color(0.95, 0.88, 0.72), "icon": "T", "levels": 1},
	{"name": "Meadow", "subtitle": "Rolling green hills", "color": Color(0.45, 0.82, 0.45), "icon": "M", "levels": 3},
	{"name": "Volcano", "subtitle": "Fiery obstacles", "color": Color(0.95, 0.35, 0.2), "icon": "V", "levels": 3},
	{"name": "Sky", "subtitle": "Wind-swept heights", "color": Color(0.55, 0.78, 0.95), "icon": "S", "levels": 3},
	{"name": "Ocean", "subtitle": "Deep currents", "color": Color(0.2, 0.5, 0.85), "icon": "O", "levels": 3},
	{"name": "Space", "subtitle": "Zero gravity", "color": Color(0.6, 0.4, 0.9), "icon": "X", "levels": 3},
]

# ─── Node References ─────────────────────────────────────────
var bg_layer: Control
var bg_orbs: Array[Dictionary] = []
var ball_preview: ColorRect
var ball_trail: Array[ColorRect] = []
var title_label: Label
var subtitle_label: Label
var version_label: Label
var main_panel: Control
var world_panel: Control
var settings_panel: Control
var credits_panel: Control
var panels: Dictionary = {}

# ─── Animation State ─────────────────────────────────────────
var time_elapsed: float = 0.0
var is_transitioning: bool = false
var title_bob_offset: float = 0.0
var ball_pos: Vector2 = Vector2(200, 300)
var ball_vel: Vector2 = Vector2(130, -90)
var trail_positions: Array[Vector2] = []
var menu_buttons: Array[Button] = []

# ─── Settings State ──────────────────────────────────────────
var master_vol: float = 1.0
var music_vol: float = 0.8
var sfx_vol: float = 1.0
var screen_shake: bool = true
var fullscreen: bool = false

# ─── Constants ───────────────────────────────────────────────
const SCREEN_W: float = 1200.0
const SCREEN_H: float = 800.0
const BG_ORB_COUNT: int = 35
const BALL_RADIUS: float = 12.0
const TRAIL_LENGTH: int = 8


func _ready() -> void:
	_build_background()
	_build_ball_preview()
	_build_main_panel()
	_build_world_panel()
	_build_settings_panel()
	_build_credits_panel()
	_show_panel("main")
	# Entrance fade-in
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	time_elapsed += delta
	_update_background(delta)
	_update_ball_preview(delta)
	_update_title_animation(delta)


# ═══════════════════════════════════════════════════════════════
# BACKGROUND SYSTEM - Floating colored orbs
# ═══════════════════════════════════════════════════════════════

func _build_background() -> void:
	bg_layer = Control.new()
	bg_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_layer)

	# Base dark colour
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.055, 0.09, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_layer.add_child(bg)

	# Top gradient overlay for depth
	var grad_top := ColorRect.new()
	grad_top.color = Color(0.1, 0.07, 0.16, 0.35)
	grad_top.position = Vector2.ZERO
	grad_top.size = Vector2(SCREEN_W, SCREEN_H * 0.45)
	grad_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(grad_top)

	# Bottom subtle glow
	var grad_bot := ColorRect.new()
	grad_bot.color = Color(0.08, 0.12, 0.1, 0.2)
	grad_bot.position = Vector2(0, SCREEN_H * 0.6)
	grad_bot.size = Vector2(SCREEN_W, SCREEN_H * 0.4)
	grad_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(grad_bot)

	# Create floating orbs (one per world colour cycling)
	for i in BG_ORB_COUNT:
		var orb := ColorRect.new()
		var orb_size := randf_range(2.0, 10.0)
		orb.size = Vector2(orb_size, orb_size)
		orb.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var world_idx := i % WORLDS.size()
		var base_color: Color = WORLDS[world_idx]["color"]
		orb.color = Color(base_color.r, base_color.g, base_color.b, randf_range(0.06, 0.25))

		var data := {
			"node": orb,
			"x": randf_range(0, SCREEN_W),
			"y": randf_range(0, SCREEN_H),
			"speed_x": randf_range(-12, 12),
			"speed_y": randf_range(-20, -4),
			"phase": randf_range(0, TAU),
			"wobble": randf_range(8, 35),
			"base_alpha": orb.color.a,
		}
		bg_orbs.append(data)
		bg_layer.add_child(orb)


func _update_background(delta: float) -> void:
	for orb_data in bg_orbs:
		var node: ColorRect = orb_data["node"]
		orb_data["y"] -= orb_data["speed_y"] * delta
		orb_data["x"] += orb_data["speed_x"] * delta
		orb_data["x"] += sin(time_elapsed + orb_data["phase"]) * orb_data["wobble"] * delta

		# Wrap around screen edges
		if orb_data["y"] < -20:
			orb_data["y"] = SCREEN_H + 20
			orb_data["x"] = randf_range(0, SCREEN_W)
		if orb_data["x"] < -20:
			orb_data["x"] = SCREEN_W + 20
		elif orb_data["x"] > SCREEN_W + 20:
			orb_data["x"] = -20

		node.position = Vector2(orb_data["x"], orb_data["y"])

		# Gentle alpha pulse
		var alpha_pulse: float = orb_data["base_alpha"] + sin(time_elapsed * 2.0 + orb_data["phase"]) * 0.06
		node.color.a = clampf(alpha_pulse, 0.02, 0.35)


# ═══════════════════════════════════════════════════════════════
# BOUNCING BALL PREVIEW
# ═══════════════════════════════════════════════════════════════

func _build_ball_preview() -> void:
	# Trail dots (oldest → newest, drawn behind the ball)
	for i in TRAIL_LENGTH:
		var trail := ColorRect.new()
		var t_size := BALL_RADIUS * 2.0 * (1.0 - float(i) / float(TRAIL_LENGTH))
		trail.size = Vector2(t_size, t_size)
		trail.color = Color(0.95, 0.88, 0.72, 0.12 * (1.0 - float(i) / float(TRAIL_LENGTH)))
		trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trail.visible = false
		add_child(trail)
		ball_trail.append(trail)

	# Main ball square (acts as the ball visually)
	ball_preview = ColorRect.new()
	ball_preview.size = Vector2(BALL_RADIUS * 2, BALL_RADIUS * 2)
	ball_preview.color = Color(0.95, 0.88, 0.72, 0.18)
	ball_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ball_preview.pivot_offset = Vector2(BALL_RADIUS, BALL_RADIUS)
	add_child(ball_preview)

	# Seed the trail positions
	for i in TRAIL_LENGTH:
		trail_positions.append(ball_pos)


func _update_ball_preview(delta: float) -> void:
	# Simple gravity
	ball_vel.y += 280.0 * delta
	ball_pos += ball_vel * delta

	# Bounce off left / right walls
	if ball_pos.x < BALL_RADIUS:
		ball_pos.x = BALL_RADIUS
		ball_vel.x = absf(ball_vel.x) * 0.88
	elif ball_pos.x > SCREEN_W - BALL_RADIUS:
		ball_pos.x = SCREEN_W - BALL_RADIUS
		ball_vel.x = -absf(ball_vel.x) * 0.88

	# Bounce off floor / ceiling
	if ball_pos.y > SCREEN_H - BALL_RADIUS:
		ball_pos.y = SCREEN_H - BALL_RADIUS
		ball_vel.y = -absf(ball_vel.y) * 0.82
		ball_vel.x += randf_range(-35, 35)
	elif ball_pos.y < BALL_RADIUS:
		ball_pos.y = BALL_RADIUS
		ball_vel.y = absf(ball_vel.y) * 0.88

	# Prevent the ball from going to sleep
	if ball_vel.length() < 60:
		ball_vel += Vector2(randf_range(-80, 80), randf_range(-150, -50))

	ball_preview.position = ball_pos - Vector2(BALL_RADIUS, BALL_RADIUS)

	# Update trail history
	trail_positions.insert(0, ball_pos)
	if trail_positions.size() > TRAIL_LENGTH:
		trail_positions.resize(TRAIL_LENGTH)

	for i in ball_trail.size():
		if i < trail_positions.size():
			var t_node: ColorRect = ball_trail[i]
			t_node.visible = true
			var offset := t_node.size * 0.5
			t_node.position = trail_positions[i] - offset


func _update_title_animation(_delta: float) -> void:
	# Gentle vertical bob on the title text
	if title_label and title_label.has_meta("base_y"):
		title_bob_offset = sin(time_elapsed * 1.5) * 3.0
		title_label.position.y = title_label.get_meta("base_y") + title_bob_offset

	if subtitle_label and subtitle_label.has_meta("base_y"):
		var sub_bob := sin(time_elapsed * 1.2 + 0.5) * 2.0
		subtitle_label.position.y = subtitle_label.get_meta("base_y") + sub_bob


# ═══════════════════════════════════════════════════════════════
# MAIN MENU PANEL
# ═══════════════════════════════════════════════════════════════

func _build_main_panel() -> void:
	main_panel = Control.new()
	main_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(main_panel)
	panels["main"] = main_panel

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_panel.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	# ── Title ──
	title_label = Label.new()
	title_label.text = "Changes"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 82)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72))
	vbox.add_child(title_label)

	# ── Subtitle ──
	subtitle_label = Label.new()
	subtitle_label.text = "A physics puzzle journey through changing worlds"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", Color(0.5, 0.48, 0.45))
	vbox.add_child(subtitle_label)

	# ── Decorative divider ──
	var divider_wrap := CenterContainer.new()
	divider_wrap.custom_minimum_size = Vector2(0, 14)
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(280, 2)
	divider.color = Color(0.95, 0.88, 0.72, 0.25)
	divider_wrap.add_child(divider)
	vbox.add_child(divider_wrap)

	_add_spacer(vbox, 18)

	# ── Play button (prominent) ──
	var btn_play := _create_menu_button("Play", Color(0.45, 0.82, 0.45), 24)
	btn_play.custom_minimum_size = Vector2(380, 58)
	btn_play.pressed.connect(_on_play_pressed)
	vbox.add_child(btn_play)

	# ── Continue (disabled when no save) ──
	var btn_continue := _create_menu_button("Continue", Color(0.55, 0.78, 0.95), 20)
	btn_continue.custom_minimum_size = Vector2(380, 50)
	btn_continue.pressed.connect(_on_continue_pressed)
	if GameState.levels_completed == 0:
		btn_continue.disabled = true
		btn_continue.modulate.a = 0.4
	vbox.add_child(btn_continue)

	# ── World Select ──
	var btn_worlds := _create_menu_button("World Select", Color(0.75, 0.7, 0.85), 20)
	btn_worlds.custom_minimum_size = Vector2(380, 50)
	btn_worlds.pressed.connect(_on_worlds_pressed)
	vbox.add_child(btn_worlds)

	# ── Settings ──
	var btn_settings := _create_menu_button("Settings", Color(0.7, 0.68, 0.65), 20)
	btn_settings.custom_minimum_size = Vector2(380, 50)
	btn_settings.pressed.connect(_on_settings_pressed)
	vbox.add_child(btn_settings)

	# ── Credits ──
	var btn_credits := _create_menu_button("Credits", Color(0.6, 0.58, 0.65), 18)
	btn_credits.custom_minimum_size = Vector2(380, 46)
	btn_credits.pressed.connect(_on_credits_pressed)
	vbox.add_child(btn_credits)

	_add_spacer(vbox, 10)

	# ── Quit ──
	var btn_quit := _create_menu_button("Quit", Color(0.7, 0.38, 0.38), 18)
	btn_quit.custom_minimum_size = Vector2(380, 44)
	btn_quit.pressed.connect(_on_quit_pressed)
	vbox.add_child(btn_quit)

	# ── Version footer ──
	_add_spacer(vbox, 8)
	version_label = Label.new()
	version_label.text = "v0.2.0  •  Godot 4.2"
	version_label.add_theme_font_size_override("font_size", 11)
	version_label.add_theme_color_override("font_color", Color(0.3, 0.28, 0.26))
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(version_label)

	# Cache base Y for bobbing after layout settles
	await get_tree().process_frame
	if is_instance_valid(title_label):
		title_label.set_meta("base_y", title_label.position.y)
	if is_instance_valid(subtitle_label):
		subtitle_label.set_meta("base_y", subtitle_label.position.y)


# ═══════════════════════════════════════════════════════════════
# WORLD SELECT PANEL
# ═══════════════════════════════════════════════════════════════

func _build_world_panel() -> void:
	world_panel = Control.new()
	world_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	world_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_panel.visible = false
	add_child(world_panel)
	panels["world"] = world_panel

	# Header
	var header := Label.new()
	header.text = "Select World"
	header.position = Vector2(0, 25)
	header.size = Vector2(SCREEN_W, 50)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 40)
	header.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72))
	world_panel.add_child(header)

	var sub_header := Label.new()
	sub_header.text = "Choose your next destination"
	sub_header.position = Vector2(0, 72)
	sub_header.size = Vector2(SCREEN_W, 25)
	sub_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_header.add_theme_font_size_override("font_size", 14)
	sub_header.add_theme_color_override("font_color", Color(0.45, 0.43, 0.4))
	world_panel.add_child(sub_header)

	# Grid layout: 3 cols × 2 rows
	var card_w: float = 300.0
	var card_h: float = 230.0
	var gap_x: float = 30.0
	var gap_y: float = 20.0
	var grid_w: float = card_w * 3.0 + gap_x * 2.0
	var start_x: float = (SCREEN_W - grid_w) / 2.0
	var start_y: float = 110.0

	for i in WORLDS.size():
		var col: int = i % 3
		var row: int = i / 3
		var cx: float = start_x + (card_w + gap_x) * col
		var cy: float = start_y + (card_h + gap_y) * row
		_build_world_card(WORLDS[i], i, cx, cy, card_w, card_h)

	# Back button
	var back_btn := _create_menu_button("<- Back to Menu", Color(0.6, 0.58, 0.65), 18)
	back_btn.position = Vector2(SCREEN_W / 2.0 - 190, SCREEN_H - 65)
	back_btn.pressed.connect(_on_back_to_main)
	world_panel.add_child(back_btn)


# ─── World Card Builder ──────────────────────────────────────

func _build_world_card(data: Dictionary, idx: int, x: float, y: float, w: float, h: float) -> void:
	var card := Panel.new()
	card.position = Vector2(x, y)
	card.size = Vector2(w, h)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.1, 0.15, 0.92)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(data["color"].r, data["color"].g, data["color"].b, 0.6)
	style.shadow_color = Color(data["color"].r, data["color"].g, data["color"].b, 0.1)
	style.shadow_size = 6
	card.add_theme_stylebox_override("panel", style)
	world_panel.add_child(card)

	# Top accent bar
	var accent := ColorRect.new()
	accent.position = Vector2(10, 0)
	accent.size = Vector2(w - 20, 3)
	accent.color = data["color"]
	card.add_child(accent)

	# World letter/icon
	var icon_lbl := Label.new()
	icon_lbl.text = data["icon"]
	icon_lbl.position = Vector2(0, 12)
	icon_lbl.size = Vector2(w, 45)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 34)
	icon_lbl.add_theme_color_override("font_color", data["color"])
	card.add_child(icon_lbl)

	# World name
	var name_lbl := Label.new()
	name_lbl.text = data["name"]
	name_lbl.position = Vector2(0, 58)
	name_lbl.size = Vector2(w, 30)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	card.add_child(name_lbl)

	# Subtitle description
	var sub_lbl := Label.new()
	sub_lbl.text = data["subtitle"]
	sub_lbl.position = Vector2(0, 88)
	sub_lbl.size = Vector2(w, 22)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 12)
	sub_lbl.add_theme_color_override("font_color", Color(0.5, 0.48, 0.45))
	card.add_child(sub_lbl)

	# Progress bar background
	var bar_x: float = 20.0
	var bar_w: float = w - 40.0
	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2(bar_x, 125)
	bar_bg.size = Vector2(bar_w, 6)
	bar_bg.color = Color(0.14, 0.15, 0.2)
	card.add_child(bar_bg)

	# Progress bar fill
	var pct: float = 0.0
	if idx == 0:
		pct = 1.0
	var bar_fill := ColorRect.new()
	bar_fill.position = Vector2(bar_x, 125)
	bar_fill.size = Vector2(bar_w * pct, 6)
	bar_fill.color = data["color"]
	card.add_child(bar_fill)

	# Level completion count
	var count_lbl := Label.new()
	count_lbl.text = "0 / %d levels" % data["levels"]
	count_lbl.position = Vector2(0, 138)
	count_lbl.size = Vector2(w, 18)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.add_theme_font_size_override("font_size", 11)
	count_lbl.add_theme_color_override("font_color", Color(0.45, 0.43, 0.4))
	card.add_child(count_lbl)

	# Enter world button
	var pbtn := Button.new()
	pbtn.text = "Enter World"
	pbtn.position = Vector2(w / 2.0 - 65, h - 50)
	pbtn.size = Vector2(130, 36)
	pbtn.add_theme_font_size_override("font_size", 15)

	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(data["color"].r, data["color"].g, data["color"].b, 0.2)
	bs.corner_radius_top_left = 6
	bs.corner_radius_top_right = 6
	bs.corner_radius_bottom_left = 6
	bs.corner_radius_bottom_right = 6
	bs.border_width_left = 1
	bs.border_width_top = 1
	bs.border_width_right = 1
	bs.border_width_bottom = 1
	bs.border_color = data["color"]

	var bh := bs.duplicate()
	bh.bg_color = Color(data["color"].r, data["color"].g, data["color"].b, 0.4)

	pbtn.add_theme_stylebox_override("normal", bs)
	pbtn.add_theme_stylebox_override("hover", bh)
	pbtn.add_theme_stylebox_override("pressed", bs)
	pbtn.add_theme_color_override("font_color", data["color"])
	pbtn.add_theme_color_override("font_hover_color", Color.WHITE)
	pbtn.pressed.connect(_on_world_play.bind(idx))
	card.add_child(pbtn)


# ═══════════════════════════════════════════════════════════════
# SETTINGS PANEL
# ═══════════════════════════════════════════════════════════════

func _build_settings_panel() -> void:
	settings_panel = Control.new()
	settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_panel.visible = false
	add_child(settings_panel)
	panels["settings"] = settings_panel

	# Card background
	var card := Panel.new()
	card.position = Vector2(SCREEN_W / 2.0 - 250, 100)
	card.size = Vector2(500, 520)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.09, 0.13, 0.95)
	card_style.corner_radius_top_left = 14
	card_style.corner_radius_top_right = 14
	card_style.corner_radius_bottom_left = 14
	card_style.corner_radius_bottom_right = 14
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.border_color = Color(0.25, 0.24, 0.3)
	card_style.shadow_color = Color(0, 0, 0, 0.3)
	card_style.shadow_size = 12
	card.add_theme_stylebox_override("panel", card_style)
	settings_panel.add_child(card)

	# Title
	var stitle := Label.new()
	stitle.text = "Settings"
	stitle.position = Vector2(0, 20)
	stitle.size = Vector2(500, 40)
	stitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stitle.add_theme_font_size_override("font_size", 32)
	stitle.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72))
	card.add_child(stitle)

	# Divider
	var sdiv := ColorRect.new()
	sdiv.position = Vector2(50, 65)
	sdiv.size = Vector2(400, 1)
	sdiv.color = Color(0.3, 0.28, 0.35, 0.5)
	card.add_child(sdiv)

	# ── Audio Section ──
	var audio_hdr := Label.new()
	audio_hdr.text = "Audio"
	audio_hdr.position = Vector2(40, 85)
	audio_hdr.size = Vector2(200, 25)
	audio_hdr.add_theme_font_size_override("font_size", 18)
	audio_hdr.add_theme_color_override("font_color", Color(0.7, 0.68, 0.65))
	card.add_child(audio_hdr)

	_build_slider(card, "Master Volume", 120, master_vol, "_on_master_vol_changed")
	_build_slider(card, "Music Volume", 175, music_vol, "_on_music_vol_changed")
	_build_slider(card, "SFX Volume", 230, sfx_vol, "_on_sfx_vol_changed")

	# ── Display Section ──
	var disp_hdr := Label.new()
	disp_hdr.text = "Display"
	disp_hdr.position = Vector2(40, 295)
	disp_hdr.size = Vector2(200, 25)
	disp_hdr.add_theme_font_size_override("font_size", 18)
	disp_hdr.add_theme_color_override("font_color", Color(0.7, 0.68, 0.65))
	card.add_child(disp_hdr)

	# Fullscreen toggle
	var fs_label := Label.new()
	fs_label.text = "Fullscreen"
	fs_label.position = Vector2(40, 330)
	fs_label.size = Vector2(200, 25)
	fs_label.add_theme_font_size_override("font_size", 15)
	fs_label.add_theme_color_override("font_color", Color(0.6, 0.58, 0.55))
	card.add_child(fs_label)

	var fs_btn := CheckButton.new()
	fs_btn.position = Vector2(380, 328)
	fs_btn.button_pressed = fullscreen
	fs_btn.toggled.connect(_on_fullscreen_toggled)
	card.add_child(fs_btn)

	# Screen shake toggle
	var shake_label := Label.new()
	shake_label.text = "Screen Shake"
	shake_label.position = Vector2(40, 370)
	shake_label.size = Vector2(200, 25)
	shake_label.add_theme_font_size_override("font_size", 15)
	shake_label.add_theme_color_override("font_color", Color(0.6, 0.58, 0.55))
	card.add_child(shake_label)

	var shake_btn := CheckButton.new()
	shake_btn.position = Vector2(380, 368)
	shake_btn.button_pressed = screen_shake
	shake_btn.toggled.connect(_on_shake_toggled)
	card.add_child(shake_btn)

	# ── Reset Progress ──
	var reset_btn := Button.new()
	reset_btn.text = "Reset All Progress"
	reset_btn.position = Vector2(125, 430)
	reset_btn.size = Vector2(250, 38)
	reset_btn.add_theme_font_size_override("font_size", 14)

	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0.3, 0.12, 0.12, 0.6)
	rs.corner_radius_top_left = 6
	rs.corner_radius_top_right = 6
	rs.corner_radius_bottom_left = 6
	rs.corner_radius_bottom_right = 6
	rs.border_width_left = 1
	rs.border_width_top = 1
	rs.border_width_right = 1
	rs.border_width_bottom = 1
	rs.border_color = Color(0.6, 0.25, 0.25)

	var rh := rs.duplicate()
	rh.bg_color = Color(0.45, 0.15, 0.15, 0.7)

	reset_btn.add_theme_stylebox_override("normal", rs)
	reset_btn.add_theme_stylebox_override("hover", rh)
	reset_btn.add_theme_stylebox_override("pressed", rs)
	reset_btn.add_theme_color_override("font_color", Color(0.85, 0.4, 0.4))
	reset_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.5, 0.5))
	reset_btn.pressed.connect(_on_reset_progress)
	card.add_child(reset_btn)

	# Back button
	var back_btn := _create_menu_button("<- Back to Menu", Color(0.6, 0.58, 0.65), 18)
	back_btn.position = Vector2(SCREEN_W / 2.0 - 190, SCREEN_H - 65)
	back_btn.pressed.connect(_on_back_to_main)
	settings_panel.add_child(back_btn)


func _build_slider(parent: Control, label_text: String, y_pos: float, initial: float, callback: String) -> void:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.position = Vector2(40, y_pos)
	lbl.size = Vector2(150, 25)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.58, 0.55))
	parent.add_child(lbl)

	var slider := HSlider.new()
	slider.position = Vector2(200, y_pos + 3)
	slider.size = Vector2(180, 20)
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial
	slider.value_changed.connect(Callable(self, callback))
	parent.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.text = "%d%%" % int(initial * 100)
	val_lbl.position = Vector2(395, y_pos)
	val_lbl.size = Vector2(60, 25)
	val_lbl.add_theme_font_size_override("font_size", 14)
	val_lbl.add_theme_color_override("font_color", Color(0.5, 0.48, 0.45))
	parent.add_child(val_lbl)

	# Live-update the percentage label
	slider.value_changed.connect(func(val: float) -> void:
		val_lbl.text = "%d%%" % int(val * 100)
	)


# ═══════════════════════════════════════════════════════════════
# CREDITS PANEL
# ═══════════════════════════════════════════════════════════════

func _build_credits_panel() -> void:
	credits_panel = Control.new()
	credits_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	credits_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	credits_panel.visible = false
	add_child(credits_panel)
	panels["credits"] = credits_panel

	# Card
	var card := Panel.new()
	card.position = Vector2(SCREEN_W / 2.0 - 280, 80)
	card.size = Vector2(560, 560)

	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.08, 0.09, 0.13, 0.95)
	cs.corner_radius_top_left = 14
	cs.corner_radius_top_right = 14
	cs.corner_radius_bottom_left = 14
	cs.corner_radius_bottom_right = 14
	cs.border_width_left = 1
	cs.border_width_top = 1
	cs.border_width_right = 1
	cs.border_width_bottom = 1
	cs.border_color = Color(0.25, 0.24, 0.3)
	cs.shadow_color = Color(0, 0, 0, 0.3)
	cs.shadow_size = 12
	card.add_theme_stylebox_override("panel", cs)
	credits_panel.add_child(card)

	# Title
	var cr_title := Label.new()
	cr_title.text = "Credits"
	cr_title.position = Vector2(0, 25)
	cr_title.size = Vector2(560, 45)
	cr_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cr_title.add_theme_font_size_override("font_size", 34)
	cr_title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72))
	card.add_child(cr_title)

	# Divider
	var cdiv := ColorRect.new()
	cdiv.position = Vector2(60, 75)
	cdiv.size = Vector2(440, 1)
	cdiv.color = Color(0.3, 0.28, 0.35, 0.5)
	card.add_child(cdiv)

	# Credit entries
	var entries := [
		{"role": "Game Design & Development", "name": "Changes Team"},
		{"role": "Engine", "name": "Godot 4.2 (godotengine.org)"},
		{"role": "Physics Puzzles", "name": "Pull-and-Shoot Mechanic"},
		{"role": "World Design", "name": "Meadow - Volcano - Sky - Ocean - Space"},
		{"role": "Sound Design", "name": "To be added"},
		{"role": "Music", "name": "To be added"},
		{"role": "Art Style", "name": "Abstract Minimalist"},
		{"role": "Special Thanks", "name": "The Godot Community"},
	]

	var y_offset: float = 100.0
	for entry in entries:
		var role_lbl := Label.new()
		role_lbl.text = entry["role"]
		role_lbl.position = Vector2(40, y_offset)
		role_lbl.size = Vector2(480, 20)
		role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_lbl.add_theme_font_size_override("font_size", 12)
		role_lbl.add_theme_color_override("font_color", Color(0.5, 0.48, 0.55))
		card.add_child(role_lbl)

		var name_lbl := Label.new()
		name_lbl.text = entry["name"]
		name_lbl.position = Vector2(40, y_offset + 18)
		name_lbl.size = Vector2(480, 25)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.82, 0.78))
		card.add_child(name_lbl)

		y_offset += 52.0

	# Closing message
	var love_lbl := Label.new()
	love_lbl.text = "Made with patience and curiosity"
	love_lbl.position = Vector2(0, 510)
	love_lbl.size = Vector2(560, 25)
	love_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	love_lbl.add_theme_font_size_override("font_size", 13)
	love_lbl.add_theme_color_override("font_color", Color(0.45, 0.42, 0.4))
	card.add_child(love_lbl)

	# Back button
	var back_btn := _create_menu_button("<- Back to Menu", Color(0.6, 0.58, 0.65), 18)
	back_btn.position = Vector2(SCREEN_W / 2.0 - 190, SCREEN_H - 65)
	back_btn.pressed.connect(_on_back_to_main)
	credits_panel.add_child(back_btn)


# ═══════════════════════════════════════════════════════════════
# UI HELPERS
# ═══════════════════════════════════════════════════════════════

func _add_spacer(parent: Control, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	parent.add_child(spacer)


func _create_menu_button(text: String, color: Color, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(380, 50)
	btn.add_theme_font_size_override("font_size", font_size)

	# Normal style — dark with coloured left accent
	var style_n := StyleBoxFlat.new()
	style_n.bg_color = Color(0.12, 0.13, 0.18, 0.85)
	style_n.corner_radius_top_left = 8
	style_n.corner_radius_top_right = 8
	style_n.corner_radius_bottom_left = 8
	style_n.corner_radius_bottom_right = 8
	style_n.border_width_left = 2
	style_n.border_width_top = 0
	style_n.border_width_right = 0
	style_n.border_width_bottom = 0
	style_n.border_color = color
	style_n.content_margin_left = 20
	style_n.content_margin_right = 20

	# Hover style — brighter with glow
	var style_h := style_n.duplicate()
	style_h.bg_color = Color(0.18, 0.19, 0.26, 0.9)
	style_h.border_width_left = 4
	style_h.shadow_color = Color(color.r, color.g, color.b, 0.12)
	style_h.shadow_size = 4

	# Pressed style — darker
	var style_p := style_n.duplicate()
	style_p.bg_color = Color(0.1, 0.1, 0.14, 0.9)

	# Disabled style
	var style_d := style_n.duplicate()
	style_d.bg_color = Color(0.1, 0.1, 0.12, 0.5)

	btn.add_theme_stylebox_override("normal", style_n)
	btn.add_theme_stylebox_override("hover", style_h)
	btn.add_theme_stylebox_override("pressed", style_p)
	btn.add_theme_stylebox_override("disabled", style_d)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", Color(
		minf(color.r + 0.3, 1.0), minf(color.g + 0.3, 1.0), minf(color.b + 0.3, 1.0)
	))
	btn.add_theme_color_override("font_disabled_color", Color(0.35, 0.33, 0.3))

	btn.mouse_entered.connect(_on_button_hover.bind(btn))
	menu_buttons.append(btn)
	return btn


# ═══════════════════════════════════════════════════════════════
# PANEL TRANSITIONS
# ═══════════════════════════════════════════════════════════════

func _show_panel(panel_name: String) -> void:
	if is_transitioning:
		return
	is_transitioning = true

	# Fade out all visible panels except the target
	for key in panels:
		var panel: Control = panels[key]
		if key == panel_name:
			continue
		if panel.visible:
			var tw := create_tween()
			tw.tween_property(panel, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
			tw.tween_callback(func() -> void: panel.visible = false)

	# Wait briefly, then fade in the target
	var target: Control = panels[panel_name]
	target.modulate.a = 0.0
	target.visible = true

	await get_tree().create_timer(0.15).timeout

	var tw := create_tween()
	tw.tween_property(target, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: is_transitioning = false)

	match panel_name:
		"main": current_state = MenuState.MAIN
		"world": current_state = MenuState.WORLD_SELECT
		"settings": current_state = MenuState.SETTINGS
		"credits": current_state = MenuState.CREDITS


func _fade_out_and_load(callback: Callable) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
	tw.tween_callback(callback)


# ═══════════════════════════════════════════════════════════════
# SIGNAL HANDLERS
# ═══════════════════════════════════════════════════════════════

func _on_button_hover(btn: Button) -> void:
	# Subtle scale pulse on hover
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2(1.02, 1.02), 0.1).set_ease(Tween.EASE_OUT)
	btn.mouse_exited.connect(func() -> void:
		var tw2 := create_tween()
		tw2.tween_property(btn, "scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_IN)
	, CONNECT_ONE_SHOT)


func _on_play_pressed() -> void:
	_fade_out_and_load(func() -> void:
		GameState.reset()
		LevelManager.load_world(1)
	)


func _on_continue_pressed() -> void:
	_fade_out_and_load(func() -> void:
		LevelManager.load_world(GameState.current_world)
	)


func _on_worlds_pressed() -> void:
	_show_panel("world")


func _on_settings_pressed() -> void:
	_show_panel("settings")


func _on_credits_pressed() -> void:
	_show_panel("credits")


func _on_back_to_main() -> void:
	_show_panel("main")


func _on_quit_pressed() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: get_tree().quit())


func _on_world_play(world_index: int) -> void:
	_fade_out_and_load(func() -> void:
		LevelManager.load_world(world_index)
	)


func _on_master_vol_changed(val: float) -> void:
	master_vol = val


func _on_music_vol_changed(val: float) -> void:
	music_vol = val
	GameState.music_muted = (val < 0.01)


func _on_sfx_vol_changed(val: float) -> void:
	sfx_vol = val
	GameState.sfx_muted = (val < 0.01)


func _on_fullscreen_toggled(pressed: bool) -> void:
	fullscreen = pressed
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_shake_toggled(pressed: bool) -> void:
	screen_shake = pressed


func _on_reset_progress() -> void:
	GameState.reset()
	# Rebuild world panel to reflect cleared progress
	for child in world_panel.get_children():
		child.queue_free()
	await get_tree().process_frame
	_build_world_panel()


# ═══════════════════════════════════════════════════════════════
# INPUT
# ═══════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	# ESC returns to main menu from any sub-panel
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if current_state != MenuState.MAIN:
				_on_back_to_main()
