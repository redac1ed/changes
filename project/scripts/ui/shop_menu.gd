extends Control
class_name ShopMenu

var coin_label: Label
var grid: GridContainer
var tab_bar: TabBar
var buy_button: Button
var preview_rect: TextureRect
var desc_label: Label

var _current_category: String = "skins"
var _selected_item_id: String = ""

func _ready() -> void:
	_ensure_ui()
	if tab_bar: tab_bar.tab_changed.connect(_on_tab_changed)
	if buy_button: buy_button.pressed.connect(_on_buy_pressed)
	
	_refresh_currency()
	_populate_grid("skins")


func _ensure_ui() -> void:
	coin_label = get_node_or_null("CoinLabel") as Label
	grid = get_node_or_null("ItemGrid") as GridContainer
	tab_bar = get_node_or_null("ShopTabs") as TabBar
	buy_button = get_node_or_null("BuyButton") as Button
	preview_rect = get_node_or_null("PreviewRect") as TextureRect
	desc_label = get_node_or_null("DescriptionLabel") as Label

	if coin_label and grid and tab_bar and buy_button and preview_rect and desc_label:
		return

	for child in get_children():
		child.queue_free()

	var root := VBoxContainer.new()
	root.name = "ShopRoot"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 60
	root.offset_top = 90
	root.offset_right = -60
	root.offset_bottom = -60
	add_child(root)

	coin_label = Label.new()
	coin_label.name = "CoinLabel"
	coin_label.text = "0"
	coin_label.add_theme_font_size_override("font_size", 20)
	root.add_child(coin_label)

	tab_bar = TabBar.new()
	tab_bar.name = "ShopTabs"
	tab_bar.add_tab("Skins")
	tab_bar.add_tab("Trails")
	tab_bar.add_tab("Abilities")
	root.add_child(tab_bar)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(content)

	grid = GridContainer.new()
	grid.name = "ItemGrid"
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(grid)

	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(240, 0)
	content.add_child(side)

	preview_rect = TextureRect.new()
	preview_rect.name = "PreviewRect"
	preview_rect.custom_minimum_size = Vector2(220, 140)
	preview_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	side.add_child(preview_rect)

	desc_label = Label.new()
	desc_label.name = "DescriptionLabel"
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.text = "Select an item"
	side.add_child(desc_label)

	buy_button = Button.new()
	buy_button.name = "BuyButton"
	buy_button.text = "Buy"
	side.add_child(buy_button)


func _refresh_currency() -> void:
	if coin_label and GameState:
		coin_label.text = str(GameState._save_data.currency.coins)


func _on_tab_changed(idx: int) -> void:
	match idx:
		0: _current_category = "skins"
		1: _current_category = "trails"
		2: _current_category = "abilities"
	_populate_grid(_current_category)


func _populate_grid(category: String) -> void:
	if not grid: return
	
	for child in grid.get_children():
		child.queue_free()
	
	var items = _get_items_for_category(category)
	for item in items:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(100, 100)
		btn.text = item.name
		
		# Check unlock status
		var is_owned = GameState.is_item_unlocked(category, item.id)
		if is_owned:
			btn.modulate = Color.WHITE
		else:
			btn.modulate = Color(0.7, 0.7, 0.7)
			btn.text += "\n" + str(item.cost) + " 💰"
			
		btn.pressed.connect(_on_item_selected.bind(item))
		grid.add_child(btn)


func _get_items_for_category(category: String) -> Array:
	# Mock data - ideally from a Database resource
	if category == "skins":
		return [
			{"id": "magma", "name": "Magma", "cost": 100},
			{"id": "ice", "name": "Ice", "cost": 150},
			{"id": "gold", "name": "Gold", "cost": 500},
			{"id": "void", "name": "Void", "cost": 300},
		]
	elif category == "trails":
		return [
			{"id": "rainbow", "name": "Rainbow", "cost": 200},
			{"id": "fire", "name": "Fire", "cost": 150},
			{"id": "sparkle", "name": "Sparkle", "cost": 100},
		]
	return []


func _on_item_selected(item: Dictionary) -> void:
	_selected_item_id = item.id
	
	if desc_label:
		desc_label.text = item.name + "\n" + "Cost: " + str(item.cost)
	
	if buy_button:
		var is_owned = GameState.is_item_unlocked(_current_category, item.id)
		buy_button.disabled = is_owned
		buy_button.text = "Owned" if is_owned else "Buy"


func _on_buy_pressed() -> void:
	# Logic to buy
	var cost = 100 # Fetch real cost
	if GameState.spend_currency(cost):
		GameState.unlock_item(_current_category, _selected_item_id)
		_refresh_currency()
		_populate_grid(_current_category) # Refresh UI
		
		if AudioManager:
			AudioManager.play_ui_sfx("buy_success")
	else:
		if AudioManager:
			AudioManager.play_ui_sfx("buy_fail")
