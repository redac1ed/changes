extends Control

const ShopMenuScene := preload("res://scripts/ui/shop_menu.gd")

enum MenuState { MAIN, WORLD_SELECT, SETTINGS, CREDITS, SHOP }
var current_state: MenuState = MenuState.MAIN

const WORLDS = [
	{"name": "Meadow", "subtitle": "Rolling green hills", "color": Color(0.45, 0.82, 0.45), "icon": "M", "levels": 3},
	{"name": "Volcano", "subtitle": "Fiery obstacles", "color": Color(0.95, 0.35, 0.2), "icon": "V", "levels": 3},
	{"name": "Sky", "subtitle": "Wind-swept heights", "color": Color(0.55, 0.78, 0.95), "icon": "S", "levels": 3},
	{"name": "Ocean", "subtitle": "Deep currents", "color": Color(0.2, 0.5, 0.85), "icon": "O", "levels": 3},
	{"name": "Space", "subtitle": "Zero gravity", "color": Color(0.6, 0.4, 0.9), "icon": "X", "levels": 3},
]

var bg_layer: Control
var title_label: Label
var subtitle_label: Label
var version_label: Label
var main_panel: Control
var world_panel: Control
var settings_panel: Control
var credits_panel: Control
var panels: Dictionary = {}
var visualizer_bars: Array[ColorRect] = []
var visualizer_index_order: Array[int] = []
var menu_buttons: Array[Button] = []

var rolling_ball: ColorRect
var ball_x: float = -40.0
var ball_rotation: float = 0.0

var tv_top_bar: ColorRect
var tv_bottom_bar: ColorRect
var tv_overlay: Control

var time_elapsed: float = 0.0
var is_transitioning: bool = false
var title_bob_offset: float = 0.0

var _spectrum_bus_idx: int = -1
var _spectrum_effect_idx: int = -1
var _spectrum_inst: AudioEffectSpectrumAnalyzerInstance = null

var mute_btn: Button

var master_vol: float = 1.0
var music_vol: float = 0.8
var sfx_vol: float = 1.0
var screen_shake: bool = true
var fullscreen: bool = false

const SCREEN_W: float = 1200.0
const SCREEN_H: float = 800.0
const VISUALIZER_BAR_COUNT: int = 18
const VISUALIZER_CENTER_X: float = SCREEN_W / 2.0
const VISUALIZER_CENTER_Y: float = SCREEN_H / 2.0
const BALL_SIZE: float = 26.0
const BALL_SPEED: float = 120.0
const BALL_Y: float = SCREEN_H - 60.0

const LEFT_MARGIN: float = 80.0
const TITLE_Y: float = 140.0
const BUTTONS_START_Y: float = 380.0

func _ready() -> void:
	_build_background()
	_build_rolling_ball()
	_build_main_panel()
	_build_world_panel()
	_build_settings_panel()
	_build_credits_panel()
	_build_tv_overlay()
	_show_panel("main")
	_setup_spectrum()
	_build_mute_button()
	if AudioManager:
		AudioManager.play_music("res://assets/audio/lobby.mp3")
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT)

func _exit_tree() -> void:
	# Stop title screen music when leaving the title screen
	if AudioManager:
		AudioManager.stop_music()

func _process(delta: float) -> void:
	time_elapsed += delta
	_update_background(delta)
	_update_title_animation(delta)
	_update_rolling_ball(delta)

func _build_background() -> void:
	bg_layer = Control.new()
	bg_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_layer)
	# Pure black base
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_layer.add_child(bg)
	# Starfield — greyscale, subtle
	var starfield_tex := TextureRect.new()
	starfield_tex.texture = load("res://assets/sprites/pixelart_starfield.png")
	starfield_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	starfield_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	starfield_tex.modulate = Color(0.55, 0.55, 0.55, 0.75)
	starfield_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(starfield_tex)
	# Visualizer bars — centered, white, translucent
	var bar_width := 6.0
	var bar_spacing := bar_width + 4.0
	var total_visualizer_width := bar_spacing * VISUALIZER_BAR_COUNT
	var start_x := VISUALIZER_CENTER_X - (total_visualizer_width / 2.0)
	# create bars and record their logical frequency index order
	visualizer_index_order.resize(VISUALIZER_BAR_COUNT)
	for i in VISUALIZER_BAR_COUNT:
		visualizer_index_order[i] = i
	for i in VISUALIZER_BAR_COUNT:
		var bar := ColorRect.new()
		bar.size = Vector2(bar_width, 4)
		bar.color = Color(1.0, 1.0, 1.0, 0.4)
		bar.position = Vector2(start_x + i * bar_spacing, VISUALIZER_CENTER_Y)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visualizer_bars.append(bar)
		bg_layer.add_child(bar)
	# randomize mapping so bars don't update sequentially left-to-right
	visualizer_index_order.shuffle()

func _setup_spectrum() -> void:
	# Find Music bus, fall back to Master
	var bus_idx := AudioServer.get_bus_index("Music")
	if bus_idx < 0:
		bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx < 0:
		return
	# Remove duplicate spectrum effects from previous loads
	for i in range(AudioServer.get_bus_effect_count(bus_idx) - 1, -1, -1):
		if AudioServer.get_bus_effect(bus_idx, i) is AudioEffectSpectrumAnalyzer:
			AudioServer.remove_bus_effect(bus_idx, i)
	var spectrum := AudioEffectSpectrumAnalyzer.new()
	spectrum.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_1024
	spectrum.tap_back_pos = 0.3
	AudioServer.add_bus_effect(bus_idx, spectrum)
	_spectrum_bus_idx = bus_idx
	_spectrum_effect_idx = AudioServer.get_bus_effect_count(bus_idx) - 1

func _update_background(_delta: float) -> void:
	# Lazily resolve the instance (only valid after the bus effect is added)
	if _spectrum_inst == null and _spectrum_bus_idx >= 0 and _spectrum_effect_idx >= 0:
		_spectrum_inst = AudioServer.get_bus_effect_instance(
			_spectrum_bus_idx, _spectrum_effect_idx) as AudioEffectSpectrumAnalyzerInstance
	var bar_spacing := 10.0
	for i in visualizer_bars.size():
		var bar: ColorRect = visualizer_bars[i]
		var height: float
		var idx: int = visualizer_index_order[i]
		if _spectrum_inst:
			# Spread frequencies logarithmically for better visual response
			var t := float(idx) / float(VISUALIZER_BAR_COUNT)
			var freq_lo := 40.0 * pow(500.0, t)
			var freq_hi := freq_lo * (1.0 + 1.5 / VISUALIZER_BAR_COUNT * 20.0)
			var mag := _spectrum_inst.get_magnitude_for_frequency_range(
				freq_lo, freq_hi, AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE)
			var db := linear_to_db(mag.length())
			height = clampf(remap(db, -80.0, -10.0, 3.0, 180.0), 3.0, 180.0)
		else:
			height = 6.0 + sin(time_elapsed * 2.5 + idx * 0.35) * 4.0
		# Center bars: grow both up and down from center
		bar.size.y = height
		bar.position.y = VISUALIZER_CENTER_Y - (height / 2.0)
		# White translucent, dims slightly on silence
		var alpha := clampf(height / 100.0, 0.3, 0.7)
		bar.color = Color(1.0, 1.0, 1.0, alpha)
	# periodically reshuffle to avoid static patterns
	if int(time_elapsed) % 5 == 0:
		visualizer_index_order.shuffle()

func _build_rolling_ball() -> void:
	rolling_ball = ColorRect.new()
	rolling_ball.size = Vector2(BALL_SIZE, BALL_SIZE)
	rolling_ball.color = Color(1.0, 1.0, 1.0, 0.9)
	rolling_ball.pivot_offset = Vector2(BALL_SIZE / 2.0, BALL_SIZE / 2.0)
	rolling_ball.position = Vector2(ball_x, BALL_Y)
	rolling_ball.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rolling_ball)

func _update_rolling_ball(delta: float) -> void:
	ball_x += BALL_SPEED * delta
	if ball_x > SCREEN_W + 60.0:
		ball_x = -BALL_SIZE - 40.0
	rolling_ball.position.x = ball_x
	rolling_ball.position.y = BALL_Y + sin(time_elapsed * 2.5) * 3.0
	ball_rotation += delta * (BALL_SPEED / (BALL_SIZE * 0.5))
	rolling_ball.rotation = ball_rotation

func _build_mute_button() -> void:
	mute_btn = Button.new()
	mute_btn.text = "[♪]"
	mute_btn.position = Vector2(SCREEN_W - 70, 18)
	mute_btn.size = Vector2(52, 32)
	mute_btn.add_theme_font_size_override("font_size", 14)
	var ms := StyleBoxFlat.new()
	ms.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	ms.border_width_left = 1
	ms.border_width_top = 1
	ms.border_width_right = 1
	ms.border_width_bottom = 1
	ms.border_color = Color(1.0, 1.0, 1.0, 0.3)
	var mh := ms.duplicate()
	mh.bg_color = Color(1.0, 1.0, 1.0, 0.1)
	mh.border_color = Color(1.0, 1.0, 1.0, 0.8)
	mute_btn.add_theme_stylebox_override("normal", ms)
	mute_btn.add_theme_stylebox_override("hover", mh)
	mute_btn.add_theme_stylebox_override("pressed", ms)
	mute_btn.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	mute_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	mute_btn.pressed.connect(_on_mute_pressed)
	add_child(mute_btn)

func _update_title_animation(_delta: float) -> void:
	if title_label and title_label.has_meta("base_y"):
		title_bob_offset = sin(time_elapsed * 1.5) * 3.0
		title_label.position.y = title_label.get_meta("base_y") + title_bob_offset
	if subtitle_label and subtitle_label.has_meta("base_y"):
		var sub_bob := sin(time_elapsed * 1.2 + 0.5) * 2.0
		subtitle_label.position.y = subtitle_label.get_meta("base_y") + sub_bob

func _build_main_panel() -> void:
	main_panel = Control.new()
	main_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(main_panel)
	panels["main"] = main_panel
	title_label = Label.new()
	title_label.text = "CHANGES"
	title_label.position = Vector2(LEFT_MARGIN, TITLE_Y)
	title_label.size = Vector2(500, 100)
	title_label.add_theme_font_size_override("font_size", 80)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	main_panel.add_child(title_label)
	subtitle_label = Label.new()
	subtitle_label.text = "the game"
	subtitle_label.position = Vector2(LEFT_MARGIN + 4, TITLE_Y + 92)
	subtitle_label.size = Vector2(500, 40)
	subtitle_label.add_theme_font_size_override("font_size", 22)
	subtitle_label.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45))
	main_panel.add_child(subtitle_label)
	var rule := ColorRect.new()
	rule.position = Vector2(LEFT_MARGIN, TITLE_Y + 140)
	rule.size = Vector2(320, 1)
	rule.color = Color(1.0, 1.0, 1.0, 0.18)
	main_panel.add_child(rule)

	var play_btn := Button.new()
	play_btn.text = "PLAY"
	play_btn.custom_minimum_size = Vector2(200, 48)
	play_btn.position = Vector2(LEFT_MARGIN, BUTTONS_START_Y)
	play_btn.size = Vector2(200, 48)
	play_btn.add_theme_font_size_override("font_size", 22)
	var play_n := StyleBoxFlat.new()
	play_n.bg_color = Color(1.0, 1.0, 1.0, 1.0)
	play_n.border_width_left = 0
	play_n.border_width_top = 0
	play_n.border_width_right = 0
	play_n.border_width_bottom = 0
	play_n.content_margin_left = 20
	play_n.content_margin_right = 20
	var play_h := play_n.duplicate()
	play_h.bg_color = Color(0.82, 0.82, 0.82, 1.0)
	var play_p := play_n.duplicate()
	play_p.bg_color = Color(0.65, 0.65, 0.65, 1.0)
	play_btn.add_theme_stylebox_override("normal", play_n)
	play_btn.add_theme_stylebox_override("hover", play_h)
	play_btn.add_theme_stylebox_override("pressed", play_p)
	play_btn.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0))
	play_btn.add_theme_color_override("font_hover_color", Color(0.0, 0.0, 0.0))
	play_btn.pressed.connect(_on_play_pressed)
	play_btn.mouse_entered.connect(_on_button_hover.bind(play_btn))
	menu_buttons.append(play_btn)
	main_panel.add_child(play_btn)

	var btn_data := [
		{"text": "Continue", "cb": "_on_continue_pressed"},
		{"text": "Worlds",   "cb": "_on_worlds_pressed"},
		{"text": "Shop",     "cb": "_on_shop_pressed"},
		{"text": "Settings", "cb": "_on_settings_pressed"},
		{"text": "Credits",  "cb": "_on_credits_pressed"},
		{"text": "Quit",     "cb": "_on_quit_pressed"},
	]

	var btn_y := BUTTONS_START_Y + 62.0
	for d in btn_data:
		var btn := _create_menu_button(d["text"], 15)
		btn.custom_minimum_size = Vector2(280, 42)
		btn.position = Vector2(LEFT_MARGIN, btn_y)
		btn.size = Vector2(280, 42)
		btn.pressed.connect(Callable(self, d["cb"]))
		if d["text"] == "Continue" and GameState.get_levels_completed() == 0:
			btn.disabled = true
			btn.modulate.a = 0.4
		main_panel.add_child(btn)
		btn_y += 50.0

	version_label = Label.new()
	version_label.text = "v0.2.0 / godot 4.2"
	version_label.position = Vector2(LEFT_MARGIN, SCREEN_H - 30)
	version_label.size = Vector2(300, 20)
	version_label.add_theme_font_size_override("font_size", 11)
	version_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	main_panel.add_child(version_label)

	await get_tree().process_frame
	if is_instance_valid(title_label):
		title_label.set_meta("base_y", title_label.position.y)
	if is_instance_valid(subtitle_label):
		subtitle_label.set_meta("base_y", subtitle_label.position.y)


func _build_world_panel() -> void:
	world_panel = Control.new()
	world_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	world_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_panel.visible = false
	add_child(world_panel)
	panels["world"] = world_panel

	var header := Label.new()
	header.text = "Select World"
	header.position = Vector2(0, 25)
	header.size = Vector2(SCREEN_W, 50)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 40)
	header.add_theme_color_override("font_color", Color.WHITE)
	world_panel.add_child(header)

	var sub_header := Label.new()
	sub_header.text = "choose your world"
	sub_header.position = Vector2(0, 72)
	sub_header.size = Vector2(SCREEN_W, 25)
	sub_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_header.add_theme_font_size_override("font_size", 14)
	sub_header.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	world_panel.add_child(sub_header)

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
	var back_btn := _create_menu_button("<- back", 16)
	back_btn.position = Vector2(SCREEN_W / 2.0 - 190, SCREEN_H - 65)
	back_btn.pressed.connect(_on_back_to_main)
	world_panel.add_child(back_btn)

func _build_world_card(data: Dictionary, idx: int, x: float, y: float, w: float, h: float) -> void:
	var card := Panel.new()
	card.position = Vector2(x, y)
	card.size = Vector2(w, h)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1.0, 1.0, 1.0, 0.2)
	card.add_theme_stylebox_override("panel", style)
	world_panel.add_child(card)

	var icon_lbl := Label.new()
	icon_lbl.text = data["icon"]
	icon_lbl.position = Vector2(0, 12)
	icon_lbl.size = Vector2(w, 45)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 30)
	icon_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	card.add_child(icon_lbl)

	var name_lbl := Label.new()
	name_lbl.text = data["name"]
	name_lbl.position = Vector2(0, 55)
	name_lbl.size = Vector2(w, 30)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	card.add_child(name_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = data["subtitle"]
	sub_lbl.position = Vector2(0, 84)
	sub_lbl.size = Vector2(w, 22)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 11)
	sub_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	card.add_child(sub_lbl)

	var bar_x: float = 20.0
	var bar_w: float = w - 40.0
	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2(bar_x, 118)
	bar_bg.size = Vector2(bar_w, 2)
	bar_bg.color = Color(1.0, 1.0, 1.0, 0.1)
	card.add_child(bar_bg)

	var world_number: int = idx + 1
	var unlocked: bool = true
	if LevelManager:
		unlocked = LevelManager.is_world_unlocked(world_number)
	elif GameState:
		unlocked = (world_number <= 1) or (GameState.worlds_completed >= (world_number - 1))

	var pct: float = 1.0 if unlocked else 0.0
	var bar_fill := ColorRect.new()
	bar_fill.position = Vector2(bar_x, 118)
	bar_fill.size = Vector2(bar_w * pct, 2)
	bar_fill.color = Color(1.0, 1.0, 1.0, 0.7)
	card.add_child(bar_fill)

	var count_lbl := Label.new()
	count_lbl.text = "0 / %d" % data["levels"]
	count_lbl.position = Vector2(0, 130)
	count_lbl.size = Vector2(w, 18)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_lbl.add_theme_font_size_override("font_size", 11)
	count_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
	card.add_child(count_lbl)

	var pbtn := Button.new()
	pbtn.text = "Enter"
	pbtn.position = Vector2(w / 2.0 - 50, h - 48)
	pbtn.size = Vector2(100, 34)
	pbtn.add_theme_font_size_override("font_size", 13)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	bs.border_width_left = 1
	bs.border_width_top = 1
	bs.border_width_right = 1
	bs.border_width_bottom = 1
	bs.border_color = Color(1.0, 1.0, 1.0, 0.4)
	var bh := bs.duplicate()
	bh.bg_color = Color(1.0, 1.0, 1.0, 0.15)
	bh.border_color = Color(1.0, 1.0, 1.0, 0.9)
	pbtn.add_theme_stylebox_override("normal", bs)
	pbtn.add_theme_stylebox_override("hover", bh)
	pbtn.add_theme_stylebox_override("pressed", bs)
	pbtn.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	pbtn.add_theme_color_override("font_hover_color", Color.WHITE)
	pbtn.disabled = not unlocked
	pbtn.text = "Enter" if unlocked else "Locked"
	pbtn.pressed.connect(_on_world_play.bind(world_number))
	card.add_child(pbtn)


func _build_settings_panel() -> void:
	settings_panel = Control.new()
	settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_panel.visible = false
	add_child(settings_panel)
	panels["settings"] = settings_panel
	var card := Panel.new()
	card.position = Vector2(SCREEN_W / 2.0 - 250, 100)
	card.size = Vector2(500, 520)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.border_color = Color(1.0, 1.0, 1.0, 0.2)
	card.add_theme_stylebox_override("panel", card_style)
	settings_panel.add_child(card)
	var stitle := Label.new()
	stitle.text = "Settings"
	stitle.position = Vector2(0, 20)
	stitle.size = Vector2(500, 40)
	stitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stitle.add_theme_font_size_override("font_size", 32)
	stitle.add_theme_color_override("font_color", Color.WHITE)
	card.add_child(stitle)
	var sdiv := ColorRect.new()
	sdiv.position = Vector2(50, 65)
	sdiv.size = Vector2(400, 1)
	sdiv.color = Color(1.0, 1.0, 1.0, 0.12)
	card.add_child(sdiv)
	var audio_hdr := Label.new()
	audio_hdr.text = "Audio"
	audio_hdr.position = Vector2(40, 85)
	audio_hdr.size = Vector2(200, 25)
	audio_hdr.add_theme_font_size_override("font_size", 18)
	audio_hdr.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	card.add_child(audio_hdr)
	_build_slider(card, "Master Volume", 120, master_vol, "_on_master_vol_changed")
	_build_slider(card, "Music Volume",  175, music_vol,  "_on_music_vol_changed")
	_build_slider(card, "SFX Volume",    230, sfx_vol,    "_on_sfx_vol_changed")
	var disp_hdr := Label.new()
	disp_hdr.text = "Display"
	disp_hdr.position = Vector2(40, 295)
	disp_hdr.size = Vector2(200, 25)
	disp_hdr.add_theme_font_size_override("font_size", 18)
	disp_hdr.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	card.add_child(disp_hdr)
	var fs_label := Label.new()
	fs_label.text = "Fullscreen"
	fs_label.position = Vector2(40, 330)
	fs_label.size = Vector2(200, 25)
	fs_label.add_theme_font_size_override("font_size", 15)
	fs_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	card.add_child(fs_label)
	var fs_btn := CheckButton.new()
	fs_btn.position = Vector2(380, 328)
	fs_btn.button_pressed = fullscreen
	fs_btn.toggled.connect(_on_fullscreen_toggled)
	card.add_child(fs_btn)
	var shake_label := Label.new()
	shake_label.text = "Screen Shake"
	shake_label.position = Vector2(40, 370)
	shake_label.size = Vector2(200, 25)
	shake_label.add_theme_font_size_override("font_size", 15)
	shake_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	card.add_child(shake_label)
	var shake_btn := CheckButton.new()
	shake_btn.position = Vector2(380, 368)
	shake_btn.button_pressed = screen_shake
	shake_btn.toggled.connect(_on_shake_toggled)
	card.add_child(shake_btn)
	var reset_btn := Button.new()
	reset_btn.text = "Reset All Progress"
	reset_btn.position = Vector2(125, 430)
	reset_btn.size = Vector2(250, 38)
	reset_btn.add_theme_font_size_override("font_size", 14)
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	rs.border_width_left = 1
	rs.border_width_top = 1
	rs.border_width_right = 1
	rs.border_width_bottom = 1
	rs.border_color = Color(1.0, 1.0, 1.0, 0.25)
	var rh := rs.duplicate()
	rh.bg_color = Color(1.0, 1.0, 1.0, 0.08)
	rh.border_color = Color(1.0, 1.0, 1.0, 0.6)
	reset_btn.add_theme_stylebox_override("normal", rs)
	reset_btn.add_theme_stylebox_override("hover", rh)
	reset_btn.add_theme_stylebox_override("pressed", rs)
	reset_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	reset_btn.add_theme_color_override("font_hover_color", Color(0.85, 0.85, 0.85))
	reset_btn.pressed.connect(_on_reset_progress)
	card.add_child(reset_btn)
	var back_btn := _create_menu_button("<- back", 16)
	back_btn.position = Vector2(SCREEN_W / 2.0 - 190, SCREEN_H - 65)
	back_btn.pressed.connect(_on_back_to_main)
	settings_panel.add_child(back_btn)

func _build_slider(parent: Control, label_text: String, y_pos: float, initial: float, callback: String) -> void:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.position = Vector2(40, y_pos)
	lbl.size = Vector2(150, 25)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
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
	val_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	parent.add_child(val_lbl)
	slider.value_changed.connect(func(val: float) -> void:
		val_lbl.text = "%d%%" % int(val * 100)
	)

func _build_credits_panel() -> void:
	credits_panel = Control.new()
	credits_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	credits_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	credits_panel.visible = false
	add_child(credits_panel)
	panels["credits"] = credits_panel
	var card := Panel.new()
	card.position = Vector2(SCREEN_W / 2.0 - 280, 80)
	card.size = Vector2(560, 560)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	cs.border_width_left = 1
	cs.border_width_top = 1
	cs.border_width_right = 1
	cs.border_width_bottom = 1
	cs.border_color = Color(1.0, 1.0, 1.0, 0.2)
	card.add_theme_stylebox_override("panel", cs)
	credits_panel.add_child(card)
	var cr_title := Label.new()
	cr_title.text = "Credits"
	cr_title.position = Vector2(0, 25)
	cr_title.size = Vector2(560, 45)
	cr_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cr_title.add_theme_font_size_override("font_size", 34)
	cr_title.add_theme_color_override("font_color", Color.WHITE)
	card.add_child(cr_title)
	var cdiv := ColorRect.new()
	cdiv.position = Vector2(60, 75)
	cdiv.size = Vector2(440, 1)
	cdiv.color = Color(1.0, 1.0, 1.0, 0.12)
	card.add_child(cdiv)
	var entries := [
		{"role": "Game Design & Development", "name": "Changes Team"},
		{"role": "Engine",                    "name": "Godot 4.2 (godotengine.org)"},
		{"role": "Physics Puzzles",           "name": "Pull-and-Shoot Mechanic"},
		{"role": "World Design",              "name": "Meadow - Volcano - Sky - Ocean - Space"},
		{"role": "Sound Design",              "name": "To be added"},
		{"role": "Music",                     "name": "To be added"},
		{"role": "Art Style",                 "name": "Abstract Minimalist"},
		{"role": "Special Thanks",            "name": "The Godot Community"},
	]
	var y_offset: float = 100.0
	for entry in entries:
		var role_lbl := Label.new()
		role_lbl.text = entry["role"]
		role_lbl.position = Vector2(40, y_offset)
		role_lbl.size = Vector2(480, 20)
		role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_lbl.add_theme_font_size_override("font_size", 12)
		role_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		card.add_child(role_lbl)
		var name_lbl := Label.new()
		name_lbl.text = entry["name"]
		name_lbl.position = Vector2(40, y_offset + 18)
		name_lbl.size = Vector2(480, 25)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		card.add_child(name_lbl)
		y_offset += 52.0

	var love_lbl := Label.new()
	love_lbl.text = "Made with patience and curiosity"
	love_lbl.position = Vector2(0, 510)
	love_lbl.size = Vector2(560, 25)
	love_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	love_lbl.add_theme_font_size_override("font_size", 13)
	love_lbl.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
	card.add_child(love_lbl)
	var back_btn := _create_menu_button("<- back", 16)
	back_btn.position = Vector2(SCREEN_W / 2.0 - 190, SCREEN_H - 65)
	back_btn.pressed.connect(_on_back_to_main)
	credits_panel.add_child(back_btn)

func _build_shop_panel() -> void:
	var shop = ShopMenuScene.new()
	shop.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop.visible = false
	add_child(shop)
	panels["shop"] = shop
	
	# Add a back button manually since ShopMenu might not have one in its base
	var back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.position = Vector2(40, 40)
	back_btn.size = Vector2(100, 40)
	back_btn.pressed.connect(_on_back_pressed)
	shop.add_child(back_btn)

func _on_shop_pressed() -> void:
	if not panels.has("shop"):
		_build_shop_panel()
	_show_panel("shop")

func _create_menu_button(text: String, font_size: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 42)
	btn.add_theme_font_size_override("font_size", font_size)
	var style_n := StyleBoxFlat.new()
	style_n.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style_n.border_width_left = 1
	style_n.border_width_top = 0
	style_n.border_width_right = 0
	style_n.border_width_bottom = 0
	style_n.border_color = Color(1.0, 1.0, 1.0, 0.5)
	style_n.content_margin_left = 16
	style_n.content_margin_right = 16
	var style_h := style_n.duplicate()
	style_h.bg_color = Color(1.0, 1.0, 1.0, 0.12)
	style_h.border_color = Color(1.0, 1.0, 1.0, 1.0)
	var style_p := style_n.duplicate()
	style_p.bg_color = Color(1.0, 1.0, 1.0, 0.06)
	var style_d := style_n.duplicate()
	style_d.border_color = Color(1.0, 1.0, 1.0, 0.15)
	btn.add_theme_stylebox_override("normal", style_n)
	btn.add_theme_stylebox_override("hover", style_h)
	btn.add_theme_stylebox_override("pressed", style_p)
	btn.add_theme_stylebox_override("disabled", style_d)
	btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	btn.add_theme_color_override("font_disabled_color", Color(0.3, 0.3, 0.3))
	btn.mouse_entered.connect(_on_button_hover.bind(btn))
	menu_buttons.append(btn)
	return btn

func _build_tv_overlay() -> void:
	tv_overlay = Control.new()
	tv_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	tv_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv_overlay.visible = false
	add_child(tv_overlay)
	tv_top_bar = ColorRect.new()
	tv_top_bar.color = Color.BLACK
	tv_top_bar.position = Vector2(0, -SCREEN_H / 2.0)
	tv_top_bar.size = Vector2(SCREEN_W, SCREEN_H / 2.0)
	tv_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv_overlay.add_child(tv_top_bar)
	tv_bottom_bar = ColorRect.new()
	tv_bottom_bar.color = Color.BLACK
	tv_bottom_bar.position = Vector2(0, SCREEN_H)
	tv_bottom_bar.size = Vector2(SCREEN_W, SCREEN_H / 2.0)
	tv_bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv_overlay.add_child(tv_bottom_bar)

func _play_tv_close_and_load(callback: Callable) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	tv_overlay.visible = true
	tv_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	tv_top_bar.position.y = -SCREEN_H / 2.0
	tv_bottom_bar.position.y = SCREEN_H
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(tv_top_bar,    "position:y", 0.0,             0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(tv_bottom_bar, "position:y", SCREEN_H / 2.0,  0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.set_parallel(false)
	tw.tween_interval(0.15)
	tw.tween_callback(callback)

func _show_panel(panel_name: String) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	for key in panels:
		var panel: Control = panels[key]
		if key == panel_name:
			continue
		if panel.visible:
			var tw := create_tween()
			tw.tween_property(panel, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
			tw.tween_callback(func() -> void: panel.visible = false)

	var target: Control = panels[panel_name]
	target.modulate.a = 0.0
	target.visible = true
	await get_tree().create_timer(0.15).timeout
	var tw := create_tween()
	tw.tween_property(target, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: is_transitioning = false)

	match panel_name:
		"main":     current_state = MenuState.MAIN
		"world":    current_state = MenuState.WORLD_SELECT
		"settings": current_state = MenuState.SETTINGS
		"credits":  current_state = MenuState.CREDITS
		"shop":     current_state = MenuState.SHOP

func _on_button_hover(btn: Button) -> void:
	var tw := create_tween()
	tw.tween_property(btn, "scale", Vector2(1.02, 1.02), 0.1).set_ease(Tween.EASE_OUT)
	btn.mouse_exited.connect(func() -> void:
		var tw2 := create_tween()
		tw2.tween_property(btn, "scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_IN)
	, CONNECT_ONE_SHOT)

func _on_play_pressed() -> void:
	_play_tv_close_and_load(func() -> void:
		
		LevelManager.load_world(1)
	)

func _on_continue_pressed() -> void:
	_play_tv_close_and_load(func() -> void:
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
	_play_tv_close_and_load(func() -> void:
		LevelManager.load_world(world_index)
	)

func _on_mute_pressed() -> void:
	if AudioManager:
		AudioManager.music_muted = not AudioManager.music_muted
		mute_btn.text = "[✕]" if AudioManager.music_muted else "[♪]"

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
	for child in world_panel.get_children():
		child.queue_free()
	await get_tree().process_frame
	_build_world_panel()

func _on_back_pressed() -> void:
	if panels.has("shop"):
		panels["shop"].visible = false
	# Or maybe go back to main menu?
	# For now just hide shop as it's the only one adding a back button connected to this
