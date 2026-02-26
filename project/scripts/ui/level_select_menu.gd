extends Control
class_name LevelSelectMenu

## ═══════════════════════════════════════════════════════════════════════════════
## LevelSelectMenu — World & Level Picker
## ═══════════════════════════════════════════════════════════════════════════════
##
## Generates a grid of buttons for selecting levels.
## Highlights locked/unlocked status, stars earned, and best times.
## Supports multiple worlds via tabs or pagination.

const LEVELS_PER_WORLD = 10

@onready var world_title: Label = %WorldTitle
@onready var level_grid: GridContainer = %LevelGrid
@onready var prev_world_btn: Button = %PrevWorldBtn
@onready var next_world_btn: Button = %NextWorldBtn
@onready var total_stars_lbl: Label = %TotalStarsLabel

var _current_world_index: int = 1
var _max_world_index: int = 5

func _ready() -> void:
	if prev_world_btn: prev_world_btn.pressed.connect(_on_prev_world)
	if next_world_btn: next_world_btn.pressed.connect(_on_next_world)
	
	_refresh_view()


func _refresh_view() -> void:
	if not GameState: return
	
	if world_title:
		world_title.text = "World %d" % _current_world_index
		# Ideally fetch world name from a config
	
	if total_stars_lbl:
		total_stars_lbl.text = "Total Stars: %d" % GameState._save_data.meta.get("total_stars", 0)
	
	_populate_grid()
	_update_nav_buttons()


func _populate_grid() -> void:
	if not level_grid: return
	
	# Clear existing
	for child in level_grid.get_children():
		child.queue_free()
	
	for i in range(1, LEVELS_PER_WORLD + 1):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(80, 80)
		btn.text = str(i)
		
		var unlocked = GameState.is_level_unlocked(_current_world_index, i)
		btn.disabled = not unlocked
		
		if unlocked:
			var data = GameState.get_level_data(_current_world_index, i)
			var stars = data.get("stars", 0)
			
			# Add star icons
			if stars > 0:
				var star_str = ""
				for s in stars: star_str += "★"
				btn.text += "\n" + star_str
			
			btn.pressed.connect(_on_level_selected.bind(i))
		else:
			btn.text = "🔒"
			btn.modulate = Color(0.5, 0.5, 0.5, 0.5)
		
		level_grid.add_child(btn)


func _update_nav_buttons() -> void:
	if prev_world_btn:
		prev_world_btn.disabled = _current_world_index <= 1
	if next_world_btn:
		next_world_btn.disabled = _current_world_index >= _max_world_index


func _on_prev_world() -> void:
	if _current_world_index > 1:
		_current_world_index -= 1
		_refresh_view()


func _on_next_world() -> void:
	if _current_world_index < _max_world_index:
		_current_world_index += 1
		_refresh_view()


func _on_level_selected(level_idx: int) -> void:
	print("Selected Level %d-%d" % [_current_world_index, level_idx])
	
	# Transition logic
	if MenuManager:
		MenuManager.clear_menus()
	
	# In a real game, you'd use a SceneManager
	# get_tree().change_scene_to_file("res://scenes/levels/world%d_level%d.tscn" % [_current_world_index, level_idx])
	GameState.start_level(_current_world_index, level_idx)
