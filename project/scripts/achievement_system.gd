extends Node
# class_name AchievementSystem

## ═══════════════════════════════════════════════════════════════════════════════
## AchievementSystem — Enhanced Achievement Tracker & Display
## ═══════════════════════════════════════════════════════════════════════════════
##
## Centralized manager for all achievements. Handles tracking, unlocking,
## persistence (via GameState), and UI notifications.
##
## How to use:
## 1. Define achievement in ACHIEVEMENTS dict
## 2. Call trigger(id) or increment_progress(id, amount)
## 3. System handles the rest (saving, notifying)

# ─── Signals ─────────────────────────────────────────────────────────────────
signal achievement_unlocked(id: String, title: String, icon: String)
signal progress_updated(id: String, current: int, target: int)

# ─── Constants ───────────────────────────────────────────────────────────────
const ICON_LOCKED := "🔒"
const TOAST_DURATION := 4.0

# ─── Achievement Definitions ────────────────────────────────────────────────
# category: progression, skill, exploration, collection, combat, secret
const ACHIEVEMENTS: Dictionary = {
	# Progression
	"first_steps": {
		"title": "First Steps",
		"desc": "Complete the first level",
		"icon": "🌱",
		"category": "progression",
		"points": 10
	},
	"world_1_complete": {
		"title": "Meadow Master",
		"desc": "Complete all levels in World 1",
		"icon": "🌿",
		"category": "progression",
		"points": 50
	},
	"world_2_complete": {
		"title": "Volcano Victor",
		"desc": "Complete all levels in World 2",
		"icon": "🌋",
		"category": "progression",
		"points": 50
	},
	"world_3_complete": {
		"title": "Sky Scraper",
		"desc": "Complete all levels in World 3",
		"icon": "☁️",
		"category": "progression",
		"points": 50
	},
	
	# Skill
	"hole_in_one": {
		"title": "Hole in One!",
		"desc": "Complete a level with a single shot",
		"icon": "⛳",
		"category": "skill",
		"points": 25
	},
	"precision": {
		"title": "Sniper",
		"desc": "Complete 5 levels with 3 stars",
		"icon": "🎯",
		"category": "skill",
		"points": 30,
		"max_progress": 5
	},
	"speed_demon": {
		"title": "Speed Demon",
		"desc": "Complete a level in under 10 seconds",
		"icon": "⚡",
		"category": "skill",
		"points": 40
	},
	"pacifist": {
		"title": "Pacifist",
		"desc": "Complete a level without destroying any enemies",
		"icon": "🕊️",
		"category": "skill",
		"points": 20
	},
	
	# Collection
	"coin_novice": {
		"title": "Penny Pincher",
		"desc": "Collect 100 coins total",
		"icon": "🪙",
		"category": "collection",
		"points": 10,
		"max_progress": 100
	},
	"coin_master": {
		"title": "Millionaire",
		"desc": "Collect 1000 coins total",
		"icon": "💰",
		"category": "collection",
		"points": 50,
		"max_progress": 1000
	},
	"gem_hunter": {
		"title": "Gem Hunter",
		"desc": "Find a hidden gem",
		"icon": "💎",
		"category": "collection",
		"points": 30
	},
	
	# Combat
	"brawler": {
		"title": "Brawler",
		"desc": "Defeat 10 enemies",
		"icon": "🥊",
		"category": "combat",
		"points": 15,
		"max_progress": 10
	},
	"destroyer": {
		"title": "Destroyer",
		"desc": "Defeat 50 enemies",
		"icon": "💣",
		"category": "combat",
		"points": 40,
		"max_progress": 50
	},
	
	# Secret
	"konami": {
		"title": "Classic Gamer",
		"desc": "???",
		"icon": "🎮",
		"category": "secret",
		"points": 100,
		"hidden": true
	},
	"infinite_void": {
		"title": "Into the Abyss",
		"desc": "Fall out of bounds 10 times in one session",
		"icon": "🕳️",
		"category": "secret",
		"points": 10
	}
}

# ─── Runtime State ──────────────────────────────────────────────────────────
var _progress_cache: Dictionary = {}
var _toast_layer: CanvasLayer

# ─── Lifecycle ──────────────────────────────────────────────────────────────

func _ready() -> void:
	print("[AchievementSystem] Initializing...")
	_setup_ui()
	
	# Connect to GameState signals if available
	if GameState:
		GameState.save_loaded.connect(_on_save_loaded)
		GameState.level_completed_event.connect(_on_level_completed)
		GameState.currency_changed.connect(_on_currency_changed)
		_on_save_loaded() # Load initial state


# ─── Public API ─────────────────────────────────────────────────────────────

func unlock(id: String) -> void:
	if not ACHIEVEMENTS.has(id):
		push_warning("[AchievementSystem] Unknown achievement ID: %s" % id)
		return
	
	if is_unlocked(id):
		return # Already unlocked
	
	# Update GameState
	if GameState:
		if not GameState._save_data.achievements.has(id):
			GameState._save_data.achievements[id] = {
				"unlocked": true,
				"date": Time.get_datetime_string_from_system(),
				"progress": ACHIEVEMENTS[id].get("max_progress", 1)
			}
			GameState._is_dirty = true
			GameState.save_game()
			
			_show_toast(id)
			achievement_unlocked.emit(id, ACHIEVEMENTS[id].title, ACHIEVEMENTS[id].icon)
			print("[AchievementSystem] Unlocked: %s" % ACHIEVEMENTS[id].title)


func increment_progress(id: String, amount: int = 1) -> void:
	if not ACHIEVEMENTS.has(id): return
	if is_unlocked(id): return
	
	var def = ACHIEVEMENTS[id]
	if not def.has("max_progress"):
		unlock(id) # Immediate unlock if no progress bar
		return
	
	var current = _get_progress(id)
	var new_val = current + amount
	var max_val = def.max_progress
	
	_set_progress(id, new_val)
	progress_updated.emit(id, new_val, max_val)
	
	if new_val >= max_val:
		unlock(id)


func is_unlocked(id: String) -> bool:
	if GameState and GameState._save_data.achievements.has(id):
		return GameState._save_data.achievements[id].unlocked
	return false


func get_all_achievements() -> Array:
	var list = []
	for id in ACHIEVEMENTS:
		var data = ACHIEVEMENTS[id].duplicate()
		data["id"] = id
		data["unlocked"] = is_unlocked(id)
		
		if data.unlocked:
			data["unlock_date"] = GameState._save_data.achievements[id].date
		
		# Hide secret ones
		if data.get("hidden", false) and not data.unlocked:
			data["title"] = "???"
			data["desc"] = "Secret Achievement"
			data["icon"] = ICON_LOCKED
			
		list.append(data)
	return list


# ─── Internal Logic ─────────────────────────────────────────────────────────

func _get_progress(id: String) -> int:
	if GameState and GameState._save_data.achievements.has(id):
		return GameState._save_data.achievements[id].get("progress", 0)
	return 0


func _set_progress(id: String, val: int) -> void:
	if GameState:
		if not GameState._save_data.achievements.has(id):
			GameState._save_data.achievements[id] = {"unlocked": false, "progress": 0}
		
		GameState._save_data.achievements[id].progress = val
		GameState._is_dirty = true # Mark for save, but don't force save every increment


func _on_save_loaded() -> void:
	# Resync any cache if needed
	pass


func _on_level_completed(world: int, level: int, stats: Dictionary) -> void:
	# Check level completion achievements
	increment_progress("first_steps")
	
	if stats.get("stars", 0) == 3:
		increment_progress("precision")
	
	if stats.get("time", 999) < 10.0:
		unlock("speed_demon")
		
	if stats.get("shots", 999) == 1:
		unlock("hole_in_one")


func _on_currency_changed(total: int, _delta: int) -> void:
	# Sync coin achievements
	# We use set_progress instead of increment because 'total' is absolute
	var p_novice = _get_progress("coin_novice")
	if total > p_novice:
		increment_progress("coin_novice", total - p_novice)
		
	var p_master = _get_progress("coin_master")
	if total > p_master:
		increment_progress("coin_master", total - p_master)


# ─── UI System ──────────────────────────────────────────────────────────────

func _setup_ui() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 100 # Topmost
	add_child(_toast_layer)


func _show_toast(id: String) -> void:
	var def = ACHIEVEMENTS[id]
	
	# Create toast panel
	var panel = PanelContainer.new()
	panel.name = "Toast_%s" % id
	# Style logic omitted for brevity (assume theme handles it or use stylebox)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.8, 0.2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	panel.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)
	
	# Icon
	var icon_lbl = Label.new()
	icon_lbl.text = def.icon
	icon_lbl.add_theme_font_size_override("font_size", 32)
	hbox.add_child(icon_lbl)
	
	# Text container
	var vbox = VBoxContainer.new()
	hbox.add_child(vbox)
	
	var title = Label.new()
	title.text = def.title
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	vbox.add_child(title)
	
	var desc = Label.new()
	desc.text = def.desc
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(desc)
	
	# Animation
	_toast_layer.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(get_viewport().get_visible_rect().size.x + 20, 20) # Start offscreen
	
	var tw = create_tween()
	var target_x = get_viewport().get_visible_rect().size.x - panel.size.x - 20
	# Wait for size calculation
	await get_tree().process_frame
	target_x = get_viewport().get_visible_rect().size.x - panel.size.x - 20
	
	tw.tween_property(panel, "position:x", target_x, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(TOAST_DURATION)
	tw.tween_property(panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(panel.queue_free)
