extends Control
class_name ShopMenu

## ═══════════════════════════════════════════════════════════════════════════════
## ShopMenu — In-Game Store
## ═══════════════════════════════════════════════════════════════════════════════
##
## Allows players to spend coins on skins, trails, and abilities.
## Dynamically populates grid based on GameState data.

@onready var coin_label: Label = %CoinLabel
@onready var grid: GridContainer = %ItemGrid
@onready var tab_bar: TabBar = %ShopTabs
@onready var buy_button: Button = %BuyButton
@onready var preview_rect: TextureRect = %PreviewRect
@onready var desc_label: Label = %DescriptionLabel

var _current_category: String = "skins"
var _selected_item_id: String = ""

func _ready() -> void:
	if tab_bar: tab_bar.tab_changed.connect(_on_tab_changed)
	if buy_button: buy_button.pressed.connect(_on_buy_pressed)
	
	_refresh_currency()
	_populate_grid("skins")


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

