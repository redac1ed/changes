extends Node
signal state_changed(what: String, value: Variant)
signal level_completed_event(world: int, level: int, stats: Dictionary)
signal save_loaded
signal save_saved
signal unlockable_acquired(type: String, id: String)
signal currency_changed(new_amount: int, delta: int)
signal setting_changed(category: String, key: String, value: Variant)

const SAVE_PATH_TEMPLATE := "user://save_slot_%d.json"
const SETTINGS_PATH := "user://settings.cfg"
const CURRENT_VERSION := "1.2.0"
const MAX_WORLDS := 6
const LEVELS_PER_WORLD := 10

var _current_slot: int = 1
var _save_data: Dictionary = {
	"version": CURRENT_VERSION,
	"meta": {
		"playtime": 0.0,
		"last_played": "",
		"created_at": "",
		"death_count": 0,
		"total_shots": 0,
		"total_jumps": 0,
	},
	"progression": {
		"current_world": 1,
		"current_level": 1,
		"max_world_reached": 1,
		"max_level_reached": 1,
		"worlds_completed": [],
	},
	"currency": {
		"coins": 0,
		"gems": 0,
		"total_coins_collected": 0,
	},
	"unlockables": {
		"skins": ["default"],
		"trails": ["default"],
		"abilities": ["none"],
		"modes": ["story"],
		"active_skin": "default",
		"active_trail": "default",
		"active_ability": "none"
	},
	"levels": {},
	"achievements": {},
}

var _settings: Dictionary = {
	"audio": {
		"master": 1.0,
		"music": 0.7,
		"sfx": 0.8,
		"ui": 0.6,
		"mute_music": false,
		"mute_sfx": false,
	},
	"video": {
		"fullscreen": false,
		"vsync": true,
		"particles": "high",
		"shake": 1.0,
		"post_process": true,
	},
	"accessibility": {
		"high_contrast": false,
		"text_size": 1.0,
		"photosensitive": false,
	},
	"gameplay": {
		"show_trajectory": true
	},
	"controls": {
		"mouse_sensitivity": 1.0,
		"invert_y": false,
	}
}

var _is_dirty: bool = false
var _auto_save_timer: float = 0.0
const AUTO_SAVE_INTERVAL: float = 60.0
var _session_start_time: float = 0.0
var _level_start_time: float = 0.0

func get_levels_completed() -> int:
	return _save_data.levels.size()

var levels_completed: int:
	get: return get_levels_completed()

var worlds_completed: int:
	get: return _save_data.progression.worlds_completed.size()

var total_shots: int:
	get: return _save_data.meta.total_shots

var shots_total: int:
	get: return _save_data.meta.total_shots
	set(value): _save_data.meta.total_shots = maxi(0, value)

var game_completed: bool:
	get: return _save_data.progression.max_world_reached >= MAX_WORLDS

var current_world: int:
	get: return _save_data.progression.current_world
	set(value): _save_data.progression.current_world = value

var current_level: int:
	get: return _save_data.progression.current_level
	set(value): _save_data.progression.current_level = value

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[GameState] Initializing Enhanced GameState...")
	_session_start_time = Time.get_ticks_msec() / 1000.0
	load_settings()
	load_game(1)
	get_tree().auto_accept_quit = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		save_settings()
		get_tree().quit()

func _process(delta: float) -> void:
	_save_data.meta.playtime += delta
	_auto_save_timer += delta
	if _auto_save_timer >= AUTO_SAVE_INTERVAL:
		_auto_save_timer = 0.0
		if _is_dirty:
			save_game()

func start_level(world: int, level: int) -> void:
	_level_start_time = Time.get_ticks_msec() / 1000.0
	print("[GameState] Starting World %d Level %d" % [world, level])

func add_shots(count: int) -> void:
	if count == 0:
		return
	_save_data.meta.total_shots += count
	_is_dirty = true
	state_changed.emit("shots_total", _save_data.meta.total_shots)

func add_score(points: int) -> void:
	add_currency(points)

func complete_level(world: int, level: int, shots: int, coins: int = 0, forced_stars: int = -1) -> Dictionary:
	var normalized_world := world
	var normalized_level := level
	if current_world > 0:
		normalized_world = current_world
	if normalized_world <= 0:
		normalized_world = 1
	if normalized_level <= 0:
		normalized_level = maxi(1, int(current_level) + 1)

	var level_key := _get_level_key(normalized_world, normalized_level)
	var time_taken := (Time.get_ticks_msec() / 1000.0) - _level_start_time
	var stars := forced_stars if forced_stars >= 0 else calculate_stars(shots, normalized_world, normalized_level)
	if not _save_data.levels.has(level_key):
		_save_data.levels[level_key] = {
			"stars": 0,
			"best_shots": 9999,
			"best_time": 9999.9,
			"times_played": 0,
			"collected_coins": false
		}
	var data = _save_data.levels[level_key]
	var is_new_record := false
	var previous_stars := int(data.get("stars", 0))
	var stars_gained := maxi(0, stars - previous_stars)
	if stars > data.stars:
		data.stars = stars
	add_currency(stars_gained)
	data.times_played += 1
	if shots < data.best_shots:
		data.best_shots = shots
		is_new_record = true
	if time_taken < data.best_time:
		data.best_time = time_taken
	if stars > data.stars:
		data.stars = stars
	_save_data.meta.total_shots += shots
	add_currency(coins)
	_update_progression(normalized_world, normalized_level)
	_is_dirty = true
	save_game()
	var result := {
		"stars": stars,
		"time": time_taken,
		"new_record": is_new_record,
		"total_coins": _save_data.currency.coins,
		"stars_gained": stars_gained,
		"total_stars_currency": _save_data.currency.coins,
	}
	level_completed_event.emit(normalized_world, normalized_level, result)
	return result

func fail_level() -> void:
	_save_data.meta.death_count += 1
	_is_dirty = true

func get_level_data(world: int, level: int) -> Dictionary:
	var key := _get_level_key(world, level)
	return _save_data.levels.get(key, {})

func is_level_unlocked(world: int, level: int) -> bool:
	if world == 1 and level == 1: return true
	var prev_level = level - 1
	var prev_world = world
	if prev_level < 1:
		prev_world -= 1
		prev_level = LEVELS_PER_WORLD
	if prev_world < 1: return true
	var prev_key = _get_level_key(prev_world, prev_level)
	return _save_data.levels.has(prev_key)

func calculate_stars(shots: int, world: int = 1, level: int = 1) -> int:
	var par = 3
	if shots <= par: return 3
	if shots <= par + 2: return 2
	if shots <= par + 4: return 1
	return 0

func _update_progression(world: int, level: int) -> void:
	var total_in_world := LevelManager.get_level_count(world) if LevelManager else LEVELS_PER_WORLD
	if level < total_in_world:
		if world == _save_data.progression.max_world_reached:
			_save_data.progression.max_level_reached = maxi(_save_data.progression.max_level_reached, level + 1)
	else:
		if not _save_data.progression.worlds_completed.has(world):
			_save_data.progression.worlds_completed.append(world)
		_save_data.progression.max_world_reached = maxi(_save_data.progression.max_world_reached, world + 1)
		if world == _save_data.progression.current_world:
			_save_data.progression.max_level_reached = 1

func _get_level_key(world: int, level: int) -> String:
	return "w%d_l%d" % [world, level]

func get_max_world_reached() -> int:
	return int(_save_data.progression.get("max_world_reached", 1))

func add_currency(amount: int) -> void:
	if amount == 0: return
	_save_data.currency.coins += amount
	_save_data.currency.total_coins_collected += amount
	currency_changed.emit(_save_data.currency.coins, amount)
	_is_dirty = true

func spend_currency(amount: int) -> bool:
	if _save_data.currency.coins >= amount:
		_save_data.currency.coins -= amount
		currency_changed.emit(_save_data.currency.coins, -amount)
		_is_dirty = true
		return true
	return false

func unlock_item(category: String, item_id: String, cost: int = 0) -> bool:
	if not _save_data.unlockables.has(category):
		push_error("[GameState] Invalid unlock category: %s" % category)
		return false
	var list: Array = _save_data.unlockables[category]
	if item_id in list:
		return true
	if cost > 0:
		if not spend_currency(cost):
			return false
	list.append(item_id)
	unlockable_acquired.emit(category, item_id)
	_is_dirty = true
	save_game()
	return true

func is_item_unlocked(category: String, item_id: String) -> bool:
	if not _save_data.unlockables.has(category):
		return false
	return item_id in _save_data.unlockables[category]

func equip_item(category: String, item_id: String) -> void:
	if not _save_data.unlockables.has("active_ability"):
		_save_data.unlockables["active_ability"] = "none"
		
	if category == "skins":
		_save_data.unlockables.active_skin = item_id
	elif category == "trails":
		_save_data.unlockables.active_trail = item_id
	elif category == "abilities":
		_save_data.unlockables.active_ability = item_id
	_is_dirty = true
	state_changed.emit("equip_" + category, item_id)
	save_game()

func save_game(slot: int = -1) -> void:
	if slot == -1: slot = _current_slot

	var path := SAVE_PATH_TEMPLATE % slot
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("[GameState] Failed to open save file: %s" % path)
		return

	_save_data.meta.last_played = Time.get_datetime_string_from_system()

	var json_string := JSON.stringify(_save_data, "\t")
	file.store_string(json_string)
	file.close()

	_is_dirty = false
	save_saved.emit()
	print("[GameState] Game saved to slot %d" % slot)

func load_game(slot: int) -> bool:
	var path := SAVE_PATH_TEMPLATE % slot
	if not FileAccess.file_exists(path):
		print("[GameState] No save found for slot %d. Creating new." % slot)
		reset_save_data()
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[GameState] Failed to read save file: %s" % path)
		return false

	var content := file.get_as_text()
	var json = JSON.new()
	var error = json.parse(content)

	if error == OK:
		var loaded_data = json.get_data()
		_save_data = _merge_dict(_save_data, loaded_data)
		_current_slot = slot
		save_loaded.emit()
		print("[GameState] Save loaded successfully from slot %d" % slot)
		return true
	else:
		push_error("[GameState] JSON Parse Error: %s" % json.get_error_message())
		return false

func delete_save(slot: int) -> void:
	var path := SAVE_PATH_TEMPLATE % slot
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("[GameState] Save slot %d deleted" % slot)

func reset_save_data() -> void:
	_save_data = {
		"version": CURRENT_VERSION,
		"meta": {
			"playtime": 0.0,
			"last_played": "",
			"created_at": Time.get_datetime_string_from_system(),
			"death_count": 0,
			"total_shots": 0,
			"total_jumps": 0,
		},
		"progression": {
			"current_world": 1,
			"current_level": 1,
			"max_world_reached": 1,
			"max_level_reached": 1,
			"worlds_completed": [],
		},
		"currency": {
			"coins": 0,
			"gems": 0,
			"total_coins_collected": 0,
		},
		"unlockables": {
			"skins": ["default"],
			"trails": ["default"],
			"modes": ["story"],
			"active_skin": "default",
			"active_trail": "default",
		},
		"levels": {},
		"achievements": {},
	}
	_is_dirty = true

func save_settings() -> void:
	var config = ConfigFile.new()

	for section in _settings:
		for key in _settings[section]:
			config.set_value(section, key, _settings[section][key])

	config.save(SETTINGS_PATH)
	print("[GameState] Settings saved")

func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)

	if err == OK:
		for section in _settings:
			if config.has_section(section):
				for key in _settings[section]:
					if config.has_section_key(section, key):
						_settings[section][key] = config.get_value(section, key)
		print("[GameState] Settings loaded")
		_apply_settings()
	else:
		print("[GameState] No settings found, using defaults")

func get_setting(category: String, key: String):
	if _settings.has(category) and _settings[category].has(key):
		return _settings[category][key]
	return null

func set_setting(category: String, key: String, value: Variant) -> void:
	if _settings.has(category):
		_settings[category][key] = value
		setting_changed.emit(category, key, value)
		_apply_setting_change(category, key, value)

func _apply_settings() -> void:
	if AudioManager:
		AudioManager.master_volume = _settings["audio"]["master"]
		AudioManager.music_volume = _settings["audio"]["music"]
		AudioManager.sfx_volume = _settings["audio"]["sfx"]
		AudioManager.music_muted = _settings["audio"]["mute_music"]
		AudioManager.sfx_muted = _settings["audio"]["mute_sfx"]

	var win_mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if _settings["video"]["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != win_mode:
		DisplayServer.window_set_mode(win_mode)
		
	var vsync_mode = DisplayServer.VSYNC_ENABLED if _settings["video"]["vsync"] else DisplayServer.VSYNC_DISABLED
	if DisplayServer.window_get_vsync_mode() != vsync_mode:
		DisplayServer.window_set_vsync_mode(vsync_mode)

func _apply_setting_change(category: String, key: String, value: Variant) -> void:
	if category == "audio" and AudioManager:
		match key:
			"master": AudioManager.master_volume = value
			"music": AudioManager.music_volume = value
			"sfx": AudioManager.sfx_volume = value
			"mute_music": AudioManager.music_muted = value
			"mute_sfx": AudioManager.sfx_muted = value
	elif category == "video":
		match key:
			"fullscreen":
				var win_mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED
				DisplayServer.window_set_mode(win_mode)
			"vsync":
				var vsync_mode = DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED
				DisplayServer.window_set_vsync_mode(vsync_mode)

func _merge_dict(target: Dictionary, patch: Dictionary) -> Dictionary:
	var result = target.duplicate(true)
	for key in patch:
		if patch[key] is Dictionary and result.has(key) and result[key] is Dictionary:
			result[key] = _merge_dict(result[key], patch[key])
		else:
			result[key] = patch[key]
	return result

func reset() -> void:
	_save_data = {
		"version": CURRENT_VERSION,
		"meta": {
			"playtime": 0.0,
			"last_played": "",
			"created_at": "",
			"death_count": 0,
			"total_shots": 0,
			"total_jumps": 0,
		},
		"progression": {
			"current_world": 1,
			"current_level": 1,
			"max_world_reached": 1,
			"max_level_reached": 1,
			"worlds_completed": [],
		},
		"currency": {
			"coins": 0,
			"gems": 0,
			"total_coins_collected": 0,
		},
		"unlockables": {
			"skins": ["default"],
			"trails": ["default"],
			"modes": ["story"],
			"active_skin": "default",
			"active_trail": "default",
		},
		"levels": {},
		"achievements": {},
	}
	_is_dirty = true
	save_game()

func get_world_name(world: int) -> String:
	if LevelManager:
		return LevelManager.get_world_name(world)
	var world_names := {
		1: "Meadow",
		2: "Volcano",
		3: "Sky",
		4: "Ocean",
		5: "Space",
		6: "Bonus"
	}
	return world_names.get(world, "Unknown")
