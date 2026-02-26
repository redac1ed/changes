extends LevelTemplateEnhanced

## Level 1 Improved
## Adds fireflies, grass animation, and tutorial hints to the standard level template.

# ═══════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════

var _time: float = 0.0
var _fireflies: Array[Dictionary] = []

# Tutorial state
var _has_moved: bool = false
var _hint_timer: float = 0.0

# ═══════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════

func _ready() -> void:
	# Initialize base class (sets up camera, hud, etc)
	super._ready()
	
	print("[Level1] Enhanced level ready")
	
	# Add visual flair
	_build_fireflies(30)
	
	# Hook up tutorial triggers if they exist in the scene
	# (The scene already has labels, we can animate them or use HUD)
	if hud:
		hud.show_notification("Welcome to Meadow!", Color(0.4, 0.8, 0.5))
		
	# Connect existing goal zone if not already handled by template
	var gz = get_node_or_null("GoalZone")
	if gz and not gz.body_entered.is_connected(on_goal_reached):
		gz.body_entered.connect(on_goal_reached)
		print("[Level1] Connected GoalZone manually")

func _process(delta: float) -> void:
	# Call base process (handles time limit, cooldowns)
	super._process(delta)
	
	_time += delta
	_update_fireflies(delta)
	
	# Tutorial logic
	if not _has_moved and ball:
		if ball.linear_velocity.length() > 10.0:
			_has_moved = true
		else:
			_hint_timer += delta
			if _hint_timer > 3.0:
				_hint_timer = 0.0
				_show_tutorial_hint()

func _show_tutorial_hint() -> void:
	if hud:
		hud.show_notification("Click & Drag to Shoot!", Color(1.0, 1.0, 0.8))
	
	# Pulse the StartHint label if it exists
	var hint_label = get_node_or_null("StartHint")
	if hint_label:
		var tw = create_tween()
		tw.tween_property(hint_label, "scale", Vector2(1.2, 1.2), 0.2)
		tw.tween_property(hint_label, "scale", Vector2(1.0, 1.0), 0.2)

# ═══════════════════════════════════════════════════════════════
# AUDIO
# ═══════════════════════════════════════════════════════════════

func _play_world_music() -> void:
	if not AudioManager:
		return
	
	# Try to use the constant from AudioManager if available
	if "WORLD_MUSIC" in AudioManager:
		var track = AudioManager.WORLD_MUSIC.get(world_number, "")
		if track:
			AudioManager.play_music(track)
			return
            
    # Fallback
	AudioManager.play_music("res://assets/audio/music/meadow_theme.ogg")

# ═══════════════════════════════════════════════════════════════
# FIREFLIES
# ═══════════════════════════════════════════════════════════════

func _build_fireflies(count: int) -> void:
	for i in count:
		var fly := ColorRect.new()
		var sz := randf_range(2.0, 4.0)
		fly.size = Vector2(sz, sz)
		fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fly.z_index = -1 # Behind platforms but in front of bg
		
		var glow_hue := randf_range(0.2, 0.4)  # green-yellow range
		fly.color = Color.from_hsv(glow_hue, 0.6, 1.0, 0.0) # Start invisible
		
		add_child(fly)
		
		var bounds = camera_limits
		var data := {
			"node": fly,
			"x": randf_range(bounds.position.x, bounds.end.x),
			"y": randf_range(bounds.position.y, bounds.end.y),
			"vx": randf_range(-10, 10),
			"vy": randf_range(-5, 5),
			"phase": randf_range(0, TAU),
			"blink_speed": randf_range(1.0, 3.0),
			"max_alpha": randf_range(0.3, 0.7),
			"wobble": randf_range(10, 30),
		}
		_fireflies.append(data)

func _update_fireflies(delta: float) -> void:
	var bounds = camera_limits
	for ff in _fireflies:
		var node: ColorRect = ff["node"]
		ff["x"] += ff["vx"] * delta + sin(_time * 0.5 + ff["phase"]) * ff["wobble"] * delta
		ff["y"] += ff["vy"] * delta + cos(_time * 0.3 + ff["phase"]) * ff["wobble"] * 0.5 * delta
		
		# Wrap around logic based on camera limits
		if ff["x"] < bounds.position.x - 50: ff["x"] = bounds.end.x + 50
		elif ff["x"] > bounds.end.x + 50: ff["x"] = bounds.position.x - 50
		
		if ff["y"] < bounds.position.y - 50: ff["y"] = bounds.end.y + 50
		elif ff["y"] > bounds.end.y + 50: ff["y"] = bounds.position.y - 50
		
		node.position = Vector2(ff["x"], ff["y"])
		
		# Blink effect
		var blink := (sin(_time * ff["blink_speed"] + ff["phase"]) + 1.0) * 0.5
		node.color.a = blink * ff["max_alpha"]
