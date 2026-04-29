extends Node

var WORLD_SCENES: Dictionary = {}
var WORLD_CONFIG: Dictionary = {
	1: {"name": "Meadow", "theme": "nature", "difficulty": 1, "levels": 5, "color": Color(0.45, 0.82, 0.45)},
	2: {"name": "Volcano", "theme": "fire", "difficulty": 2, "levels": 3, "color": Color(0.95, 0.35, 0.2)},
	3: {"name": "Snow", "theme": "wind", "difficulty": 2, "levels": 2, "color": Color(0.55, 0.78, 0.95)}
}

var _current_scene: Node = null
var _transition_in_progress: bool = false
var _level_start_time: float = 0.0
var _best_times: Dictionary = {}
var _death_count_current: int = 0
var _collectibles_found: Dictionary = {}

func _ready():
	# Pre-populate WORLD_SCENES with known level paths (works in both editor and exported game)
	# Note: DirAccess.open does not work in exported games because resources are packed
	WORLD_SCENES = {
		1: [
			"res://scenes/levels/world1_main_level1.tscn",
			"res://scenes/levels/world1_main_level2.tscn",
			"res://scenes/levels/world1_main_level3.tscn",
			"res://scenes/levels/world1_main_level4.tscn",
			"res://scenes/levels/world1_main_level5.tscn",
		],
		2: [
			"res://scenes/levels/world2_main_level1.tscn",
			"res://scenes/levels/world2_main_level2.tscn",
			"res://scenes/levels/world2_main_level3.tscn",
		],
		3: [
			"res://scenes/levels/world3_main_level1.tscn",
			"res://scenes/levels/world3_main_level2.tscn",
		],
	}
	print("[LevelManager] Initialized scenes: %s" % str(WORLD_SCENES))

func load_world(world: int, start_level: int = 0) -> void:
	if not WORLD_SCENES.has(world):
		if world < 6:
			load_world(world + 1)
		else:
			GameState.game_completed = true
		return
	GameState.current_world = world
	var scene_path: String
	if WORLD_SCENES[world] is String:
		scene_path = WORLD_SCENES[world]
		GameState.current_level = 0
	else:
		if start_level < len(WORLD_SCENES[world]):
			scene_path = WORLD_SCENES[world][start_level]
			GameState.current_level = start_level
		else:
			scene_path = WORLD_SCENES[world][0]
			GameState.current_level = 0
	_load_scene(scene_path)

func load_next_level() -> void:
	var world = GameState.current_world
	var level = GameState.current_level
	print("[LevelManager] load_next_level: world=%d level=%d" % [world, level])

	if WORLD_SCENES[world] is String:

		if world == 6:

			GameState.game_completed = true
	else:

		level += 1
		if level < len(WORLD_SCENES[world]):
			GameState.current_level = level
			_load_scene(WORLD_SCENES[world][level])
		else:

			load_world(world + 1)

func load_level_by_path(path: String) -> void:
	_load_scene(path)

func _load_scene(path: String) -> void:
	print("[LevelManager] Loading: %s" % path)
	if _transition_in_progress:
		return
	_transition_in_progress = true
	_level_start_time = Time.get_ticks_msec() / 1000.0
	_death_count_current = 0
	get_tree().change_scene_to_file(path)

	get_tree().tree_changed.connect(_on_scene_loaded, CONNECT_ONE_SHOT)

func _on_scene_loaded() -> void:
	_transition_in_progress = false

func get_world_config(world: int) -> Dictionary:
	return WORLD_CONFIG.get(world, {})

func get_world_name(world: int) -> String:
	return WORLD_CONFIG.get(world, {}).get("name", "Unknown")

func get_world_theme(world: int) -> String:
	return WORLD_CONFIG.get(world, {}).get("theme", "core")

func get_difficulty(world: int) -> int:
	return WORLD_CONFIG.get(world, {}).get("difficulty", 0)

func get_world_color(world: int) -> Color:
	return WORLD_CONFIG.get(world, {}).get("color", Color.WHITE)

func get_level_count(world: int) -> int:
	if not WORLD_SCENES.has(world):
		return 0
	if WORLD_SCENES[world] is String:
		return 1
	return len(WORLD_SCENES[world])

func record_level_completion(world: int, level: int, shots: int, time_taken: float) -> void:
	var key = "%d_%d" % [world, level]
	if not _best_times.has(key) or time_taken < _best_times[key]:
		_best_times[key] = time_taken
	GameState.complete_level(world, level, shots)

func get_best_time(world: int, level: int) -> float:
	var key = "%d_%d" % [world, level]
	return _best_times.get(key, -1.0)

func is_world_unlocked(world: int) -> bool:
	if world == 1:
		return true
	return GameState.worlds_completed >= (world - 1)

func get_worlds_completed() -> int:
	return GameState.worlds_completed

func get_total_shots() -> int:
	return GameState.total_shots

func get_levels_completed() -> int:
	return GameState.levels_completed

func record_collectible(world: int, level: int) -> void:
	var key = "%d_%d" % [world, level]
	if not _collectibles_found.has(key):
		_collectibles_found[key] = 0
	_collectibles_found[key] += 1

func get_collectibles_found(world: int, level: int) -> int:
	var key = "%d_%d" % [world, level]
	return _collectibles_found.get(key, 0)

func record_death() -> void:
	_death_count_current += 1

func get_death_count() -> int:
	return _death_count_current

func get_level_elapsed_time() -> float:
	return (Time.get_ticks_msec() / 1000.0) - _level_start_time

func reset_all_progress() -> void:
	_best_times.clear()
	_collectibles_found.clear()
	_death_count_current = 0
	GameState.reset()

func get_world_stats(world: int) -> Dictionary:
	var stats = {
		"best_times": [],
		"total_collectibles": 0,
		"levels_beaten": 0,
		"perfect_levels": 0,
	}
	var level_count = get_level_count(world)
	for level in range(level_count):
		var key = "%d_%d" % [world, level]
		var best_time = get_best_time(world, level)
		if best_time > 0:
			stats["best_times"].append(best_time)
			stats["levels_beaten"] += 1

		stats["total_collectibles"] += get_collectibles_found(world, level)
	return stats
