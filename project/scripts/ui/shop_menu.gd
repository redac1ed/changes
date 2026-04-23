extends Control
class_name ShopMenu

var coin_label: Label
var carousel: ScrollContainer
var carousel_box: HBoxContainer
var tab_bar: TabBar
var buy_button: Button
var preview_rect: TextureRect
var preview_container: Control
var desc_label: Label
var cost_label: Label
var status_label: Label
var item_buttons: Array[Button] = []
var _current_category: String = "skins"
var _selected_item_id: String = ""
var _selected_button: Button = null
const ANIMATION_DURATION := 0.2
signal back_requested

func _ready() -> void:
	_ensure_ui()
	if tab_bar: tab_bar.tab_changed.connect(_on_tab_changed)
	if buy_button: buy_button.pressed.connect(_on_buy_pressed)
	_refresh_currency()
	_populate_carousel("skins")

func _ensure_ui() -> void:
	coin_label = get_node_or_null("CoinLabel") as Label
	carousel = get_node_or_null("ItemCarousel") as ScrollContainer
	carousel_box = get_node_or_null("CarouselBox") as HBoxContainer
	tab_bar = get_node_or_null("ShopTabs") as TabBar
	buy_button = get_node_or_null("BuyButton") as Button
	preview_rect = get_node_or_null("PreviewRect") as TextureRect
	desc_label = get_node_or_null("DescriptionLabel") as Label
	cost_label = get_node_or_null("CostLabel") as Label
	status_label = get_node_or_null("StatusLabel") as Label
	if coin_label and carousel and carousel_box and tab_bar and buy_button and preview_rect and desc_label and cost_label and status_label:
		return
	for child in get_children():
		child.queue_free()
	var root := VBoxContainer.new()
	root.name = "ShopRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 40
	root.offset_top = 40
	root.offset_right = -40
	root.offset_bottom = -40
	root.add_theme_constant_override("separation", 20)
	add_child(root)
	
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 40)
	root.add_child(header)
	coin_label = Label.new()
	coin_label.name = "CoinLabel"
	coin_label.text = "0"
	coin_label.add_theme_font_size_override("font_size", 24)
	coin_label.add_theme_color_override("font_color", Color.GOLD)
	header.add_child(coin_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	tab_bar = TabBar.new()
	tab_bar.name = "ShopTabs"
	tab_bar.custom_minimum_size = Vector2(0, 40)
	tab_bar.add_tab("Skins")
	tab_bar.add_tab("Trails")
	tab_bar.add_tab("Abilities")
	root.add_child(tab_bar)
	
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 30)
	root.add_child(content)
	
	var carousel_container := VBoxContainer.new()
	carousel_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	carousel_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	carousel_container.custom_minimum_size = Vector2(400, 0)
	content.add_child(carousel_container)
	
	carousel = ScrollContainer.new()
	carousel.name = "ItemCarousel"
	carousel.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	carousel.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	carousel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	carousel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	carousel_container.add_child(carousel)
	
	carousel_box = HBoxContainer.new()
	carousel_box.name = "CarouselBox"
	carousel_box.add_theme_constant_override("separation", 15)
	carousel.add_child(carousel_box)
	
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(280, 0)
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 15)
	content.add_child(side)
	
	var preview_label := Label.new()
	preview_label.text = "Preview"
	preview_label.add_theme_font_size_override("font_size", 16)
	preview_label.add_theme_color_override("font_color", Color.WHITE)
	side.add_child(preview_label)
	
	preview_container = Control.new()
	preview_container.name = "PreviewContainer"
	preview_container.custom_minimum_size = Vector2(260, 180)
	side.add_child(preview_container)
	
	preview_rect = TextureRect.new()
	preview_rect.name = "PreviewRect"
	preview_rect.custom_minimum_size = Vector2(260, 180)
	preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_rect.modulate = Color.WHITE
	preview_container.add_child(preview_rect)
	
	desc_label = Label.new()
	desc_label.name = "DescriptionLabel"
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.text = "Select an item"
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color.WHITE)
	side.add_child(desc_label)
	
	cost_label = Label.new()
	cost_label.name = "CostLabel"
	cost_label.text = ""
	cost_label.add_theme_font_size_override("font_size", 18)
	cost_label.add_theme_color_override("font_color", Color.GOLD)
	side.add_child(cost_label)
	
	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = ""
	status_label.add_theme_font_size_override("font_size", 12)
	side.add_child(status_label)
	
	var spacer2 := Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer2)
	
	buy_button = Button.new()
	buy_button.name = "BuyButton"
	buy_button.text = "Buy"
	buy_button.custom_minimum_size = Vector2(0, 50)
	buy_button.add_theme_font_size_override("font_size", 16)
	side.add_child(buy_button)

func _refresh_currency() -> void:
	if coin_label and GameState:
		coin_label.text = "★ " + str(GameState._save_data.currency.coins)

func _on_tab_changed(idx: int) -> void:
	match idx:
		0: _current_category = "skins"
		1: _current_category = "trails"
		2: _current_category = "abilities"
	_populate_carousel(_current_category)

func _populate_carousel(category: String) -> void:
	if not carousel_box: return
	for child in carousel_box.get_children():
		child.queue_free()
	item_buttons.clear()
	_selected_button = null
	
	var items = _get_items_for_category(category)
	for item in items:
		var item_container := VBoxContainer.new()
		item_container.add_theme_constant_override("separation", 5)
		item_container.custom_minimum_size = Vector2(140, 200)
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(140, 140)
		btn.text = item.name
		btn.add_theme_font_size_override("font_size", 12)
		
		var is_owned = GameState.is_item_unlocked(category, item.id)
		if is_owned:
			btn.modulate = Color.WHITE
			btn.self_modulate = Color.WHITE
		else:
			btn.modulate = Color(0.6, 0.6, 0.6)
			btn.self_modulate = Color(0.6, 0.6, 0.6)
		
		btn.pressed.connect(_on_item_selected.bind(item, btn))
		item_container.add_child(btn)
		
		var cost_label_small := Label.new()
		cost_label_small.text = "★ " + str(item.cost)
		cost_label_small.add_theme_font_size_override("font_size", 11)
		cost_label_small.add_theme_color_override("font_color", Color.GOLD)
		cost_label_small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if not is_owned:
			item_container.add_child(cost_label_small)
		
		carousel_box.add_child(item_container)
		item_buttons.append(btn)

func _get_items_for_category(category: String) -> Array:
	if category == "skins":
		return [
			{"id": "magma", "name": "Magma", "cost": 10},
			{"id": "ice", "name": "Ice", "cost": 10},
			{"id": "gold", "name": "Gold", "cost": 10},
			{"id": "void", "name": "Void", "cost": 10},
		]
	elif category == "trails":
		return [
			{"id": "rainbow", "name": "Rainbow", "cost": 10},
			{"id": "fire", "name": "Fire", "cost": 12},
			{"id": "sparkle", "name": "Sparkle", "cost": 15},
		]
	elif category == "abilities":
		return [
			{"id": "boost", "name": "Speed Boost", "cost": 8},
			{"id": "slow_fall", "name": "Slow Fall", "cost": 6},
		]
	return []

func _on_item_selected(item: Dictionary, button: Button) -> void:
	if _selected_button:
		_animate_button_deselect(_selected_button)
	
	_selected_item_id = item.id
	_selected_button = button
	
	_animate_button_select(button)
	
	if desc_label:
		desc_label.text = item.name
	if cost_label:
		cost_label.text = "★ " + str(item.cost)
	
	var is_owned = GameState.is_item_unlocked(_current_category, item.id)
	
	var is_equipped = false
	if _current_category == "skins":
		is_equipped = GameState._save_data.unlockables.get("active_skin", "default") == item.id
	elif _current_category == "trails":
		is_equipped = GameState._save_data.unlockables.get("active_trail", "default") == item.id
	elif _current_category == "abilities":
		is_equipped = GameState._save_data.unlockables.get("active_ability", "none") == item.id

	if status_label:
		if is_equipped:
			status_label.text = "EQUIPPED"
			status_label.add_theme_color_override("font_color", Color.CYAN)
		elif is_owned:
			status_label.text = "OWNED"
			status_label.add_theme_color_override("font_color", Color.GREEN)
		else:
			status_label.text = "AVAILABLE"
			status_label.add_theme_color_override("font_color", Color.WHITE)
	
	if buy_button:
		buy_button.disabled = is_equipped
		if is_equipped:
			buy_button.text = "Equipped"
		elif is_owned:
			buy_button.text = "Equip"
		else:
			buy_button.text = "Buy"
	
	if _current_category == "skins":
		_update_skin_preview(item.id)
	elif _current_category == "trails":
		_update_trail_preview(item.id)
	elif _current_category == "abilities":
		_update_ability_preview(item.id)

func _animate_button_select(button: Button) -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.1, 1.1), ANIMATION_DURATION)

func _animate_button_deselect(button: Button) -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), ANIMATION_DURATION)

func _update_skin_preview(skin_id: String) -> void:
	if not preview_container:
		return
	
	for child in preview_container.get_children():
		if child != preview_rect:
			child.queue_free()
			
	if preview_rect:
		preview_rect.hide()
	var skin_colors = _get_skin_colors(skin_id)
	var ball_preview = ColorRect.new()
	ball_preview.custom_minimum_size = Vector2(120, 120)
	ball_preview.anchor_left = 0.5
	ball_preview.anchor_top = 0.5
	ball_preview.anchor_right = 0.5
	ball_preview.anchor_bottom = 0.5
	ball_preview.offset_left = -60
	ball_preview.offset_top = -60
	ball_preview.offset_right = 60
	ball_preview.offset_bottom = 60
	ball_preview.color = skin_colors.color
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec3 base_color : source_color;
uniform vec3 highlight_color : source_color;
uniform vec3 outline_color : source_color;

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv);
	
	// Hard circle edge
	if (dist > 0.5) {
		discard;
	}
	
	// Sphere lighting effect
	float light_intensity = (1.0 - dist * 1.2);
	light_intensity = clamp(light_intensity, 0.0, 1.0);
	light_intensity = pow(light_intensity, 1.5);
	
	// Combine base color with lighting
	vec3 lit_color = mix(base_color, highlight_color, light_intensity * 0.6);
	
	// Outline effect
	float outline = smoothstep(0.48, 0.5, dist);
	lit_color = mix(lit_color, outline_color, outline * 0.3);
	
	COLOR = vec4(lit_color, 1.0);
}
"""
	
	var material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("base_color", skin_colors.color)
	material.set_shader_parameter("highlight_color", skin_colors.highlight)
	material.set_shader_parameter("outline_color", skin_colors.outline)
	
	ball_preview.material = material
	preview_container.add_child(ball_preview)

func _get_skin_colors(skin_id: String) -> Dictionary:
	var skins = {
		"default": {
			"color": Color(0.95, 0.88, 0.72),
			"highlight": Color(1.0, 0.97, 0.92),
			"outline": Color(0.6, 0.52, 0.38),
		},
		"magma": {
			"color": Color(0.8, 0.2, 0.1),
			"highlight": Color(1.0, 0.6, 0.2),
			"outline": Color(0.3, 0.05, 0.05),
		},
		"ice": {
			"color": Color(0.4, 0.7, 0.9),
			"highlight": Color(0.8, 0.9, 1.0),
			"outline": Color(0.2, 0.4, 0.6),
		},
		"gold": {
			"color": Color(1.0, 0.84, 0.0),
			"highlight": Color(1.0, 1.0, 0.6),
			"outline": Color(0.6, 0.4, 0.0),
		},
		"void": {
			"color": Color(0.1, 0.0, 0.2),
			"highlight": Color(0.3, 0.0, 0.5),
			"outline": Color(0.5, 0.0, 0.8),
		}
	}
	return skins.get(skin_id, skins["default"])

func _update_trail_preview(trail_id: String) -> void:
	if not preview_container:
		return
	
	for child in preview_container.get_children():
		if child != preview_rect:
			child.queue_free()
			
	if preview_rect:
		preview_rect.hide()
		
	var line = Line2D.new()
	line.width = 15.0
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	
	var curve = Curve2D.new()
	curve.add_point(Vector2(20, 140), Vector2(0, 0), Vector2(50, -50))
	curve.add_point(Vector2(130, 90), Vector2(-50, 50), Vector2(50, 50))
	curve.add_point(Vector2(240, 40), Vector2(-50, -50), Vector2(0, 0))
	
	var points = curve.get_baked_points()
	line.points = points
	
	var gradient = Gradient.new()
	if trail_id == "rainbow":
		gradient.offsets = [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]
		gradient.colors = [Color.RED, Color.ORANGE, Color.YELLOW, Color.GREEN, Color.BLUE, Color.PURPLE]
	elif trail_id == "fire":
		gradient.offsets = [0.0, 0.5, 1.0]
		gradient.colors = [Color.YELLOW, Color.ORANGE, Color.RED]
	elif trail_id == "sparkle":
		gradient.offsets = [0.0, 0.5, 1.0]
		gradient.colors = [Color.WHITE, Color.YELLOW, Color(1, 1, 0, 0)]
	else:
		gradient.offsets = [0.0, 1.0]
		gradient.colors = [Color.WHITE, Color(1, 1, 1, 0)]
		
	line.gradient = gradient
	preview_container.add_child(line)

func _update_ability_preview(ability_id: String) -> void:
	if not preview_container:
		return
	
	for child in preview_container.get_children():
		if child != preview_rect:
			child.queue_free()
			
	if preview_rect:
		preview_rect.hide()
		
	var emoji_label = Label.new()
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	emoji_label.add_theme_font_size_override("font_size", 90)
	
	emoji_label.anchor_left = 0.5
	emoji_label.anchor_top = 0.5
	emoji_label.anchor_right = 0.5
	emoji_label.anchor_bottom = 0.5
	emoji_label.offset_left = -60
	emoji_label.offset_top = -60
	emoji_label.offset_right = 60
	emoji_label.offset_bottom = 60
	
	if ability_id == "boost":
		emoji_label.text = "⚡"
	elif ability_id == "slow_fall":
		emoji_label.text = "🪂"
	else:
		emoji_label.text = "✨"
		
	preview_container.add_child(emoji_label)

func _on_buy_pressed() -> void:
	var cost = 100
	var items = _get_items_for_category(_current_category)
	for i in items:
		if i.id == _selected_item_id:
			cost = i.cost
			break
			
	if GameState.is_item_unlocked(_current_category, _selected_item_id):
		GameState.equip_item(_current_category, _selected_item_id)
		
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_ELASTIC)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(preview_container, "scale", Vector2(1.1, 1.1), 0.2)
		tween.tween_property(preview_container, "scale", Vector2(1.0, 1.0), 0.2)
		
		var old_text = buy_button.text
		buy_button.text = "Equipped!"
		await get_tree().create_timer(1.0).timeout
		if buy_button:
			buy_button.text = old_text
			
		if AudioManager:
			AudioManager.play_ui_sfx("buy_success")
	else:
		if GameState.spend_currency(cost):
			GameState.unlock_item(_current_category, _selected_item_id)
			GameState.equip_item(_current_category, _selected_item_id)
			_refresh_currency()
			
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_ELASTIC)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(preview_container, "scale", Vector2(1.2, 1.2), 0.3)
			tween.tween_property(preview_container, "scale", Vector2(1.0, 1.0), 0.2)
			
			_populate_carousel(_current_category)
			if AudioManager:
				AudioManager.play_ui_sfx("buy_success")
		else:
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_SINE)
			tween.tween_property(buy_button, "offset", Vector2(-5, 0), 0.05)
			tween.tween_property(buy_button, "offset", Vector2(5, 0), 0.05)
			tween.tween_property(buy_button, "offset", Vector2(0, 0), 0.05)
			
			if AudioManager:
				AudioManager.play_ui_sfx("buy_fail")
