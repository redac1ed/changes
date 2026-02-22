extends Node

## Level/World progression manager
## Handles scene transitions and progression through themed worlds

var WORLD_SCENES = {}

func _ready():
	WORLD_SCENES[0] = "res://scenes/tutorial.tscn"
	WORLD_SCENES[6] = "res://scenes/levels/bonus.tscn"
	
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
		# Single scene world (tutorial/bonus)
		if world == 0:
			load_world(1)
		elif world == 6:
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
	get_tree().change_scene_to_file(path)
