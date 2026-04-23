extends Control
class_name LevelSelectMenu

const LEVELS_PER_WORLD_FALLBACK = 10

@onready var world_title: Label = %WorldTitle
@onready var level_grid: GridContainer = %LevelGrid
@onready var prev_world_btn: Button = %PrevWorldBtn
@onready var next_world_btn: Button = %NextWorldBtn
@onready var total_stars_lbl: Label = %TotalStarsLabel

var _current_world_index: int = 1

func _ready() -> void:
	if prev_world_btn: prev_world_btn.pressed.connect(_on_prev_world)
	if next_world_btn: next_world_btn.pressed.connect(_on_next_world)
	var worlds := _get_available_worlds()
	if worlds.size() > 0:
		_current_world_index = int(worlds[0])
	_refresh_view()

func _refresh_view() -> void:
	if not GameState: return
	if world_title:
		world_title.text = "World %d" % _current_world_index

	if total_stars_lbl:
		total_stars_lbl.text = "Total Stars: %d" % GameState._save_data.meta.get("total_stars", 0)
	_populate_grid()
	_update_nav_buttons()

func _populate_grid() -> void:
	if not level_grid: return

	for child in level_grid.get_children():
		child.queue_free()

	var level_count := _get_level_count_for_current_world()
	for i in range(1, level_count + 1):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(80, 80)
		btn.text = str(i)
		var unlocked = GameState.is_level_unlocked(_current_world_index, i)
		btn.disabled = not unlocked
		if unlocked:
			var data = GameState.get_level_data(_current_world_index, i)
			var stars = data.get("stars", 0)

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
	var worlds := _get_available_worlds()
	var world_pos := worlds.find(_current_world_index)
	if world_pos < 0:
		world_pos = 0
	if prev_world_btn:
		prev_world_btn.disabled = worlds.size() <= 1 or world_pos <= 0
	if next_world_btn:
		next_world_btn.disabled = worlds.size() <= 1 or world_pos >= worlds.size() - 1

func _on_prev_world() -> void:
	var worlds := _get_available_worlds()
	var world_pos := worlds.find(_current_world_index)
	if world_pos > 0:
		_current_world_index = int(worlds[world_pos - 1])
		_refresh_view()

func _on_next_world() -> void:
	var worlds := _get_available_worlds()
	var world_pos := worlds.find(_current_world_index)
	if world_pos >= 0 and world_pos < worlds.size() - 1:
		_current_world_index = int(worlds[world_pos + 1])
		_refresh_view()

func _on_level_selected(level_idx: int) -> void:
	print("Selected Level %d-%d" % [_current_world_index, level_idx])

	if MenuManager:
		MenuManager.clear_menus()

	var scene_path := _get_scene_path_for_level(_current_world_index, level_idx)
	if scene_path != "" and LevelManager:
		GameState.start_level(_current_world_index, level_idx)
		LevelManager.load_level_by_path(scene_path)
		return

	GameState.start_level(_current_world_index, level_idx)

func _get_available_worlds() -> Array:
	var worlds: Array = []
	if LevelManager and LevelManager.WORLD_SCENES:
		for k in LevelManager.WORLD_SCENES.keys():
			var world := int(k)
			if world >= 1:
				worlds.append(world)
	worlds.sort()
	if worlds.is_empty():
		worlds = [1]
	return worlds

func _get_level_count_for_current_world() -> int:
	if LevelManager and LevelManager.WORLD_SCENES.has(_current_world_index):
		return max(1, int(LevelManager.get_level_count(_current_world_index)))
	return LEVELS_PER_WORLD_FALLBACK

func _get_scene_path_for_level(world: int, level: int) -> String:
	if not LevelManager or not LevelManager.WORLD_SCENES.has(world):
		return ""
	var scenes = LevelManager.WORLD_SCENES[world]
	if scenes is String:
		return scenes if level == 1 else ""
	if scenes is Array:
		var idx := level - 1
		if idx >= 0 and idx < scenes.size():
			return str(scenes[idx])
	return ""
