extends Node

## Global game state manager - tracks progression, worlds, player data, achievements
## Auto-loads as singleton with comprehensive stats and achievement tracking

# ── Current Progression ──
var current_world: int = 0  # 0=tutorial, 1-5=worlds, 6=bonus
var current_level: int = 0

# ── Player Data ──
var shots_total: int = 0
var stars_earned: int = 0
var levels_completed: int = 0
var collectibles_count: int = 0
var total_score: int = 0

# ── Game State ──
var game_completed: bool = false
var playtime_seconds: float = 0.0

# ── Audio Mute ──
var music_muted: bool = false
var sfx_muted: bool = false

# ── Achievement System ──
var _achievements: Dictionary = {}
var _achievement_unlock_times: Dictionary = {}

# ── Performance Tracking ──
var _session_start_time: float = 0.0
var _best_times: Dictionary = {}
var _least_shots: Dictionary = {}
var _death_count: int = 0
var _collectibles_found: Dictionary = {}

# ── Statistics Snapshots ──
var _statistics_history: Array[Dictionary] = []


func _ready() -> void:
	print("[GameState] Initialized")
	_session_start_time = Time.get_ticks_msec() / 1000.0
	_initialize_achievements()


func _process(delta: float) -> void:
	playtime_seconds += delta


func get_world_name() -> String:
	match current_world:
		0: return "Tutorial"
		1: return "Meadow"
		2: return "Volcano"
		3: return "Sky"
		4: return "Ocean"
		5: return "Space"
		6: return "Bonus"
		_: return "Unknown"


func next_world() -> void:
	current_world += 1
	current_level = 0
	print("[GameState] Advanced to World %d: %s" % [current_world, get_world_name()])


func next_level() -> void:
	current_level += 1
	levels_completed += 1


func add_shots(count: int) -> void:
	shots_total += count


func add_stars(count: int) -> void:
	stars_earned += count


func reset() -> void:
	current_world = 0
	current_level = 0
	shots_total = 0
	stars_earned = 0
	levels_completed = 0
	game_completed = false
	collectibles_count = 0
	total_score = 0
	_death_count = 0
	playtime_seconds = 0.0
	_session_start_time = Time.get_ticks_msec() / 1000.0
	print("[GameState] Reset to initial state")


# ═══════════════════════════════════════════════════════════════════════════
# ACHIEVEMENT SYSTEM
# ═══════════════════════════════════════════════════════════════════════════

func _initialize_achievements() -> void:
	"""Set up all achievement definitions"""
	var achievements := {
		"first_shot": {"name": "First Shot", "desc": "Take your first shot", "icon": "🎯"},
		"speed_runner": {"name": "Speed Runner", "desc": "Complete level in <30 seconds", "icon": "⚡"},
		"perfect_aim": {"name": "Perfect Aim", "desc": "Complete level in 1 shot", "icon": "🎪"},
		"collector": {"name": "Collector", "desc": "Collect 10 items", "icon": "⭐"},
		"marathon": {"name": "Marathon", "desc": "Play for 1 hour", "icon": "🏃"},
		"world_master": {"name": "World Master", "desc": "Complete all levels in a world", "icon": "👑"},
		"all_stars": {"name": "All Stars", "desc": "Collect all stars", "icon": "✨"},
		"speedrunner_pro": {"name": "Speedrunner Pro", "desc": "3★ all levels", "icon": "🚀"},
		"no_death": {"name": "Flawless", "desc": "Complete level without dying", "icon": "💎"},
		"ultimate_player": {"name": "Ultimate Player", "desc": "Complete all worlds", "icon": "🏆"},
	}
	
	for achievement_id in achievements.keys():
		_achievements[achievement_id] = false
		_achievement_unlock_times[achievement_id] = 0.0


func unlock_achievement(achievement_id: String) -> bool:
	"""Unlock an achievement"""
	if not _achievements.has(achievement_id):
		push_error("[GameState] Unknown achievement: %s" % achievement_id)
		return false
	
	if _achievements[achievement_id]:
		return false  # Already unlocked
	
	_achievements[achievement_id] = true
	_achievement_unlock_times[achievement_id] = Time.get_ticks_msec() / 1000.0
	print("[GameState] Achievement Unlocked: %s" % achievement_id)
	return true


func is_achievement_unlocked(achievement_id: String) -> bool:
	"""Check if achievement is unlocked"""
	return _achievements.get(achievement_id, false)


func get_achievement_progress(achievement_id: String) -> float:
	"""Get progress toward achievement (0-1)"""
	match achievement_id:
		"collector":
			return minf(float(collectibles_count) / 10.0, 1.0)
		"marathon":
			return minf(playtime_seconds / 3600.0, 1.0)  # 1 hour
		"speedrunner_pro":
			# All levels 3 shots or less
			return 0.5  # Placeholder
		_:
			return 1.0 if is_achievement_unlocked(achievement_id) else 0.0


func get_achievement_info() -> Dictionary:
	"""Return all achievement info"""
	var unlocked_count := 0
	for unlocked in _achievements.values():
		if unlocked:
			unlocked_count += 1
	
	return {
		"total": _achievements.size(),
		"unlocked": unlocked_count,
		"progress": float(unlocked_count) / _achievements.size(),
		"achievements": _achievements.duplicate(),
	}


# ═══════════════════════════════════════════════════════════════════════════
# PERFORMANCE TRACKING
# ═══════════════════════════════════════════════════════════════════════════

func record_level_time(world: int, level: int, time_seconds: float) -> void:
	"""Record level completion time"""
	var key := "%d_%d" % [world, level]
	
	if not _best_times.has(key) or time_seconds < _best_times[key]:
		_best_times[key] = time_seconds
		print("[GameState] New best time for %s: %.2f sec" % [key, time_seconds])


func get_best_time(world: int, level: int) -> float:
	"""Get best time for level"""
	var key := "%d_%d" % [world, level]
	return _best_times.get(key, -1.0)


func record_level_shots(world: int, level: int, shot_count: int) -> void:
	"""Record shot count for level"""
	var key := "%d_%d" % [world, level]
	
	if not _least_shots.has(key) or shot_count < _least_shots[key]:
		_least_shots[key] = shot_count
		print("[GameState] New best shot record for %s: %d shots" % [key, shot_count])


func get_least_shots(world: int, level: int) -> int:
	"""Get best shot count for level"""
	var key := "%d_%d" % [world, level]
	return _least_shots.get(key, -1)


func record_death() -> void:
	"""Increment death counter"""
	_death_count += 1


func get_death_count() -> int:
	"""Get total deaths in session"""
	return _death_count


func add_collectible(collectible_id: String, points: int) -> void:
	"""Record collectible found"""
	collectibles_count += 1
	total_score += points
	_collectibles_found[collectible_id] = true


func add_score(points: int) -> void:
	"""Add to total score"""
	total_score += points
	
	if total_score >= 1000 and not is_achievement_unlocked("collector"):
		unlock_achievement("collector")


func get_session_duration() -> float:
	"""Get current session time in seconds"""
	return Time.get_ticks_msec() / 1000.0 - _session_start_time


# ═══════════════════════════════════════════════════════════════════════════
# STATISTICS & REPORTING
# ═══════════════════════════════════════════════════════════════════════════

func snapshot_statistics() -> Dictionary:
	"""Create snapshot of current statistics"""
	var snapshot := {
		"timestamp": Time.get_ticks_msec(),
		"world": current_world,
		"level": current_level,
		"shots_total": shots_total,
		"stars": stars_earned,
		"score": total_score,
		"deaths": _death_count,
		"collectibles": collectibles_count,
		"playtime": playtime_seconds,
		"achievements_unlocked": get_achievement_info()["unlocked"],
	}
	
	_statistics_history.append(snapshot)
	return snapshot


func get_statistics_summary() -> Dictionary:
	"""Get comprehensive statistics summary"""
	return {
		"total_playtime": playtime_seconds,
		"session_duration": get_session_duration(),
		"shots_fired": shots_total,
		"stars_earned": stars_earned,
		"levels_completed": levels_completed,
		"total_score": total_score,
		"deaths": _death_count,
		"collectibles": collectibles_count,
		"achievements": get_achievement_info(),
		"best_times": _best_times.duplicate(),
		"least_shots": _least_shots.duplicate(),
	}


func get_average_shots_per_level() -> float:
	"""Calculate average shots per completed level"""
	if levels_completed == 0:
		return 0.0
	return float(shots_total) / float(levels_completed)


func get_completion_percentage() -> float:
	"""Estimate game completion based on achievements"""
	var info := get_achievement_info()
	return info["progress"] * 100.0


func is_game_completed() -> bool:
	"""Check if all content completed"""
	return current_world >= 6 and levels_completed >= 15  # Placeholder


func print_session_report() -> void:
	"""Print comprehensive session statistics"""
	var stats := get_statistics_summary()
	var divider := ""
	for i in range(50):
		divider += "═"
	
	print("\n" + divider)
	print("GAME SESSION REPORT")
	print(divider)
	print("Duration: %.1f minutes" % (stats["session_duration"] / 60.0))
	print("Levels Completed: %d" % stats["levels_completed"])
	print("Total Shots: %d (avg %.1f per level)" % [stats["shots_fired"], get_average_shots_per_level()])
	print("Stars Earned: %d" % stats["stars_earned"])
	print("Total Score: %d" % stats["total_score"])
	print("Deaths: %d" % stats["deaths"])
	print("Achievements: %d/%d" % [stats["achievements"]["unlocked"], stats["achievements"]["total"]])
	print(divider + "\n")
