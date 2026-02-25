extends Node
class_name AchievementSystem

## ═══════════════════════════════════════════════════════════════════════════════
## AchievementSystem — Track and display gameplay achievements
## ═══════════════════════════════════════════════════════════════════════════════
##
## Monitors game events and unlocks achievements. Stores progress in
## GameState. Shows toast notifications when achievements are unlocked.
## Can be added as autoload or as child of a persistent node.

# ─── Signals ─────────────────────────────────────────────────────────────────
signal achievement_unlocked(id: String, title: String)

# ─── Achievement Data ────────────────────────────────────────────────────────
const ACHIEVEMENTS := {
	"first_shot": {
		"title": "First Shot",
		"description": "Take your first shot",
		"icon": "🎯",
		"category": "basics",
	},
	"perfect_level": {
		"title": "Perfect!",
		"description": "Complete a level with 1 shot",
		"icon": "⭐",
		"category": "skill",
	},
	"coin_collector": {
		"title": "Coin Collector",
		"description": "Collect 50 coins total",
		"icon": "🪙",
		"category": "collection",
		"threshold": 50,
	},
	"coin_hoarder": {
		"title": "Coin Hoarder",
		"description": "Collect 200 coins total",
		"icon": "💰",
		"category": "collection",
		"threshold": 200,
	},
	"level_5_complete": {
		"title": "Getting Started",
		"description": "Complete 5 levels",
		"icon": "🏁",
		"category": "progress",
		"threshold": 5,
	},
	"level_15_complete": {
		"title": "Seasoned Player",
		"description": "Complete 15 levels",
		"icon": "🏆",
		"category": "progress",
		"threshold": 15,
	},
	"world_2_unlock": {
		"title": "New Horizons",
		"description": "Unlock World 2",
		"icon": "🌋",
		"category": "progress",
	},
	"world_3_unlock": {
		"title": "Sky High",
		"description": "Unlock World 3",
		"icon": "☁️",
		"category": "progress",
	},
	"combo_x4": {
		"title": "Combo Master",
		"description": "Reach a 4x coin combo",
		"icon": "🔥",
		"category": "skill",
	},
	"combo_x8": {
		"title": "Combo King",
		"description": "Reach an 8x coin combo",
		"icon": "👑",
		"category": "skill",
	},
	"enemy_first_kill": {
		"title": "Bounced!",
		"description": "Defeat your first enemy",
		"icon": "💥",
		"category": "combat",
	},
	"enemy_10_kills": {
		"title": "Enemy Crusher",
		"description": "Defeat 10 enemies",
		"icon": "⚔️",
		"category": "combat",
		"threshold": 10,
	},
	"speedrun_30s": {
		"title": "Speed Demon",
		"description": "Complete a level in under 30 seconds",
		"icon": "⚡",
		"category": "skill",
	},
	"all_stars_world1": {
		"title": "Meadow Master",
		"description": "Get 3 stars on every Meadow level",
		"icon": "🌸",
		"category": "mastery",
	},
	"no_death_run": {
		"title": "Untouchable",
		"description": "Complete 5 levels without dying",
		"icon": "🛡️",
		"category": "skill",
	},
	"play_1_hour": {
		"title": "Dedicated",
		"description": "Play for 1 hour total",
		"icon": "⏰",
		"category": "dedication",
		"threshold": 3600,
	},
	"total_100_shots": {
		"title": "Sharp Shooter",
		"description": "Take 100 shots total",
		"icon": "🎯",
		"category": "dedication",
		"threshold": 100,
	},
	"total_500_shots": {
		"title": "Marksman",
		"description": "Take 500 shots total",
		"icon": "🏹",
		"category": "dedication",
		"threshold": 500,
	},
}

# ─── State ───────────────────────────────────────────────────────────────────
var unlocked_achievements: Dictionary = {}  # id -> { "time": float, "unlocked": true }
var _tracked_stats: Dictionary = {
	"total_coins": 0,
	"total_kills": 0,
	"levels_without_death": 0,
	"current_combo": 0,
}

# ─── Toast Display ──────────────────────────────────────────────────────────
var _toast_queue: Array[Dictionary] = []
var _current_toast: Dictionary = {}
var _toast_timer: float = 0.0
var _toast_active: bool = false
var _toast_canvas: CanvasLayer
var _toast_control: Control


func _ready() -> void:
	_load_achievements()
	_connect_signals()
	_setup_toast_display()


func _process(delta: float) -> void:
	# Check time-based achievements
	if GameState and not is_unlocked("play_1_hour"):
		if GameState.play_time_seconds >= 3600:
			unlock("play_1_hour")
	
	# Toast display
	if _toast_active:
		_toast_timer += delta
		if _toast_timer > 4.0:
			_toast_active = false
			if not _toast_queue.is_empty():
				_show_next_toast()
		if _toast_control:
			_toast_control.queue_redraw()
	elif not _toast_queue.is_empty():
		_show_next_toast()


# ─── Public API ──────────────────────────────────────────────────────────────

func unlock(id: String) -> bool:
	if unlocked_achievements.has(id):
		return false
	
	if not ACHIEVEMENTS.has(id):
		push_warning("Unknown achievement: %s" % id)
		return false
	
	unlocked_achievements[id] = {
		"unlocked": true,
		"time": Time.get_unix_time_from_system(),
	}
	
	var data: Dictionary = ACHIEVEMENTS[id]
	achievement_unlocked.emit(id, data.get("title", id))
	
	# Queue toast
	_toast_queue.append({
		"title": data.get("title", id),
		"description": data.get("description", ""),
		"icon": data.get("icon", "🏆"),
	})
	
	_save_achievements()
	print("[Achievement] Unlocked: %s" % data.get("title", id))
	return true


func is_unlocked(id: String) -> bool:
	return unlocked_achievements.has(id)


func get_progress() -> Dictionary:
	var total := ACHIEVEMENTS.size()
	var done := unlocked_achievements.size()
	return {
		"unlocked": done,
		"total": total,
		"percentage": float(done) / max(total, 1) * 100,
	}


func get_all_achievements() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in ACHIEVEMENTS:
		var data: Dictionary = ACHIEVEMENTS[id].duplicate()
		data["id"] = id
		data["unlocked"] = is_unlocked(id)
		result.append(data)
	return result


func check_stat(stat: String, value: int) -> void:
	_tracked_stats[stat] = value
	
	# Check threshold achievements
	for id in ACHIEVEMENTS:
		if is_unlocked(id):
			continue
		var data: Dictionary = ACHIEVEMENTS[id]
		if data.has("threshold"):
			var threshold: int = data["threshold"]
			match id:
				"coin_collector", "coin_hoarder":
					if stat == "total_coins" and value >= threshold:
						unlock(id)
				"level_5_complete", "level_15_complete":
					if stat == "levels_completed" and value >= threshold:
						unlock(id)
				"enemy_10_kills":
					if stat == "total_kills" and value >= threshold:
						unlock(id)
				"total_100_shots", "total_500_shots":
					if stat == "total_shots" and value >= threshold:
						unlock(id)


# ─── Signal Handlers ────────────────────────────────────────────────────────

func _connect_signals() -> void:
	if not GameState:
		return
	
	if GameState.has_signal("level_completed_signal"):
		GameState.level_completed_signal.connect(_on_level_completed)
	if GameState.has_signal("collectible_collected"):
		GameState.collectible_collected.connect(_on_collectible)
	if GameState.has_signal("world_unlocked"):
		GameState.world_unlocked.connect(_on_world_unlocked)


func _on_level_completed(_world: int, _level: int, shots: int, stars: int) -> void:
	# First shot achievement
	if not is_unlocked("first_shot"):
		unlock("first_shot")
	
	# Perfect level
	if stars == 3 and not is_unlocked("perfect_level"):
		unlock("perfect_level")
	
	# Level count
	check_stat("levels_completed", GameState.levels_completed)
	check_stat("total_shots", GameState.total_shots)
	
	# Speed run
	# (would need level_time passed in — check in HUD integration)


func _on_collectible(_id: String, _points: int) -> void:
	_tracked_stats["total_coins"] = _tracked_stats.get("total_coins", 0) + 1
	check_stat("total_coins", _tracked_stats["total_coins"])


func _on_world_unlocked(world: int) -> void:
	match world:
		2:
			if not is_unlocked("world_2_unlock"):
				unlock("world_2_unlock")
		3:
			if not is_unlocked("world_3_unlock"):
				unlock("world_3_unlock")


# ─── Persistence ─────────────────────────────────────────────────────────────

func _save_achievements() -> void:
	var file := FileAccess.open("user://achievements.dat", FileAccess.WRITE)
	if file:
		file.store_var(unlocked_achievements)
		file.close()


func _load_achievements() -> void:
	if not FileAccess.file_exists("user://achievements.dat"):
		return
	var file := FileAccess.open("user://achievements.dat", FileAccess.READ)
	if file:
		var data = file.get_var()
		file.close()
		if data is Dictionary:
			unlocked_achievements = data


# ─── Toast Display ──────────────────────────────────────────────────────────

func _setup_toast_display() -> void:
	_toast_canvas = CanvasLayer.new()
	_toast_canvas.layer = 30
	add_child(_toast_canvas)
	
	_toast_control = Control.new()
	_toast_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_toast_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_control.draw.connect(_draw_toast)
	_toast_canvas.add_child(_toast_control)


func _show_next_toast() -> void:
	if _toast_queue.is_empty():
		return
	_current_toast = _toast_queue.pop_front()
	_toast_timer = 0.0
	_toast_active = true


func _draw_toast() -> void:
	if not _toast_active:
		return
	
	var font := ThemeDB.fallback_font
	
	# Animation
	var slide_in: float = min(_toast_timer * 4.0, 1.0)
	var fade_out: float = 1.0
	if _toast_timer > 3.0:
		fade_out = 1.0 - (_toast_timer - 3.0)
	
	var alpha: float = slide_in * fade_out
	var slide_y: float = (1.0 - slide_in) * -60.0
	
	var tw := 320.0
	var th := 70.0
	var tx := (1200.0 - tw) / 2.0
	var ty: float = 50.0 + slide_y
	
	# Background
	var bg := Color(0.06, 0.08, 0.14, 0.9 * alpha)
	_toast_control.draw_rect(Rect2(tx, ty, tw, th), bg, true)
	
	# Border
	var border := Color(1.0, 0.85, 0.3, 0.6 * alpha)
	_toast_control.draw_rect(Rect2(tx, ty, tw, th), border, false, 2.0)
	
	# Accent bar
	_toast_control.draw_rect(Rect2(tx, ty, 4, th), Color(1.0, 0.85, 0.3, alpha), true)
	
	# Icon
	var icon_text: String = _current_toast.get("icon", "🏆")
	_toast_control.draw_string(font, Vector2(tx + 16, ty + 40), icon_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 1, 1, alpha))
	
	# Title
	_toast_control.draw_string(font, Vector2(tx + 55, ty + 25), "Achievement Unlocked!", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.85, 0.3, alpha * 0.7))
	
	# Name
	var title: String = _current_toast.get("title", "")
	_toast_control.draw_string(font, Vector2(tx + 55, ty + 42), title, HORIZONTAL_ALIGNMENT_LEFT, tw - 70, 16, Color(1.0, 1.0, 1.0, alpha))
	
	# Description
	var desc: String = _current_toast.get("description", "")
	_toast_control.draw_string(font, Vector2(tx + 55, ty + 58), desc, HORIZONTAL_ALIGNMENT_LEFT, tw - 70, 11, Color(0.7, 0.7, 0.75, alpha * 0.7))
