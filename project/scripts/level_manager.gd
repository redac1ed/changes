extends Node

## Level/World progression manager
## Handles scene transitions, progression through themed worlds, level difficulty,
## performance tracking, and world-specific features

var WORLD_SCENES: Dictionary = {}
var WORLD_CONFIG: Dictionary = {
	1: {"name": "Meadow", "theme": "nature", "difficulty": 1, "levels": 3, "color": Color(0.45, 0.82, 0.45)},
	2: {"name": "Volcano", "theme": "fire", "difficulty": 2, "levels": 3, "color": Color(0.95, 0.35, 0.2)},
	3: {"name": "Sky", "theme": "wind", "difficulty": 2, "levels": 3, "color": Color(0.55, 0.78, 0.95)},
	4: {"name": "Ocean", "theme": "water", "difficulty": 3, "levels": 3, "color": Color(0.2, 0.5, 0.85)},
	5: {"name": "Space", "theme": "gravity", "difficulty": 3, "levels": 3, "color": Color(0.6, 0.4, 0.9)},
	6: {"name": "Bonus", "theme": "infinite", "difficulty": 4, "levels": 1, "color": Color(1.0, 0.85, 0.1)},
}

var _current_scene: Node = null
var _transition_in_progress: bool = false
var _level_start_time: float = 0.0
var _best_times: Dictionary = {}  # world:level -> time in seconds
var _death_count_current: int = 0
var _collectibles_found: Dictionary = {}  # world:level -> count

func _ready():
	# Bonus level removed - commented out
	# WORLD_SCENES[6] = "res://scenes/levels/bonus.tscn"
	
	var dir := DirAccess.open("res://scenes/levels")
	if dir != null:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tscn") and file_name != "bonus.tscn":
				var parts: PackedStringArray = file_name.get_basename().split("_")
				if parts.size() >= 3 and parts[0].begins_with("world") and parts[2].begins_with("level"):
					var world: int = int(parts[0].substr(5))
					var level: int = int(parts[2].substr(5))
					if not WORLD_SCENES.has(world):
						WORLD_SCENES[world] = []
					WORLD_SCENES[world].append("res://scenes/levels/" + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
		
		# Sort each world's levels
		for world_key in WORLD_SCENES.keys():
			if WORLD_SCENES[world_key] is Array:
				WORLD_SCENES[world_key].sort()
	
	print("[LevelManager] Discovered scenes: %s" % str(WORLD_SCENES))


func load_world(world: int) -> void:
	"""Load the first level of a world"""
	if not WORLD_SCENES.has(world):
		if world < 6:
			load_world(world + 1)
		else:
			GameState.game_completed = true
		return
	
	GameState.current_world = world
	GameState.current_level = 0
	
	var scene_path: String
	if WORLD_SCENES[world] is String:
		scene_path = WORLD_SCENES[world]
	else:
		scene_path = WORLD_SCENES[world][0]
	
	_load_scene(scene_path)


func load_next_level() -> void:
	"""Load the next level in the current world"""
	var world = GameState.current_world
	var level = GameState.current_level
	print("[LevelManager] load_next_level: world=%d level=%d" % [world, level])
	
	if WORLD_SCENES[world] is String:
		# Single scene world (bonus)
		if world == 6:
			# Game complete
			GameState.game_completed = true
	else:
		# Multi-level world
		level += 1
		if level < len(WORLD_SCENES[world]):
			GameState.current_level = level
			_load_scene(WORLD_SCENES[world][level])
		else:
			# Move to next world
			load_world(world + 1)


func load_level_by_path(path: String) -> void:
	"""Directly load a scene by path"""
	_load_scene(path)


func _load_scene(path: String) -> void:
	"""Load a scene with transition"""
	print("[LevelManager] Loading: %s" % path)
	if _transition_in_progress:
		return
	_transition_in_progress = true
	_level_start_time = Time.get_ticks_msec() / 1000.0
	_death_count_current = 0
	get_tree().change_scene_to_file(path)
	# Reset the flag once the new scene tree is ready
	get_tree().tree_changed.connect(_on_scene_loaded, CONNECT_ONE_SHOT)


func _on_scene_loaded() -> void:
	_transition_in_progress = false


func get_world_config(world: int) -> Dictionary:
	"""Get configuration for a world"""
	return WORLD_CONFIG.get(world, {})


func get_world_name(world: int) -> String:
	"""Get display name for a world"""
	return WORLD_CONFIG.get(world, {}).get("name", "Unknown")


func get_world_theme(world: int) -> String:
	"""Get theme for a world (affects music, visuals, mechanics)"""
	return WORLD_CONFIG.get(world, {}).get("theme", "core")


func get_difficulty(world: int) -> int:
	"""Get difficulty rating for a world (0-4)"""
	return WORLD_CONFIG.get(world, {}).get("difficulty", 0)


func get_world_color(world: int) -> Color:
	"""Get accent color for a world"""
	return WORLD_CONFIG.get(world, {}).get("color", Color.WHITE)


func get_level_count(world: int) -> int:
	"""Get number of levels in a world"""
	if not WORLD_SCENES.has(world):
		return 0
	if WORLD_SCENES[world] is String:
		return 1
	return len(WORLD_SCENES[world])


func record_level_completion(world: int, level: int, shots: int, time_taken: float) -> void:
	"""Record level performance data"""
	var key = "%d_%d" % [world, level]
	if not _best_times.has(key) or time_taken < _best_times[key]:
		_best_times[key] = time_taken
	GameState.complete_level(world, level, shots)


func get_best_time(world: int, level: int) -> float:
	"""Get best recorded time for a level"""
	var key = "%d_%d" % [world, level]
	return _best_times.get(key, -1.0)


func is_world_unlocked(world: int) -> bool:
	"""Check if a world is unlocked based on progression"""
	if world == 1:
		return true
	return GameState.worlds_completed >= (world - 1)


func get_worlds_completed() -> int:
	"""Get total worlds completed"""
	return GameState.worlds_completed


func get_total_shots() -> int:
	"""Get total shots taken across all levels"""
	return GameState.total_shots


func get_levels_completed() -> int:
	"""Get total levels completed"""
	return GameState.levels_completed


func record_collectible(world: int, level: int) -> void:
	"""Track a collectible found in a level"""
	var key = "%d_%d" % [world, level]
	if not _collectibles_found.has(key):
		_collectibles_found[key] = 0
	_collectibles_found[key] += 1


func get_collectibles_found(world: int, level: int) -> int:
	"""Get collectible count for a level"""
	var key = "%d_%d" % [world, level]
	return _collectibles_found.get(key, 0)


func record_death() -> void:
	"""Track a death/restart in current level"""
	_death_count_current += 1


func get_death_count() -> int:
	"""Get death count in current level"""
	return _death_count_current


func get_level_elapsed_time() -> float:
	"""Get seconds elapsed in current level"""
	return (Time.get_ticks_msec() / 1000.0) - _level_start_time


func reset_all_progress() -> void:
	"""Reset all progression and performance data"""
	_best_times.clear()
	_collectibles_found.clear()
	_death_count_current = 0
	GameState.reset()


func get_world_stats(world: int) -> Dictionary:
	"""Get aggregate stats for a complete world"""
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
			# Perfect = 1 shot (if game tracks this)
		stats["total_collectibles"] += get_collectibles_found(world, level)
	return stats
