extends LevelTemplate

## Level 2 — Stepping Stones
## The ball spawns on the left; a chain of elevated stepping-stone platforms
## leads to the goal, which sits higher and further right than in level 1.

func _ready() -> void:
	super._ready()
	if hud:
		hud.show_notification("Level 2 — Stepping Stones", Color(0.5, 0.9, 0.7))


func _build_level() -> void:
	# Move goal to a higher, harder-to-reach spot
	var goal_zone := get_node_or_null("GoalZone")
	if goal_zone:
		goal_zone.position = Vector2(980, 130)

	# Chain of stepping-stone platforms leading up to the goal
	_add_platform(Vector2(300, 480), Vector2(120, 16))
	_add_platform(Vector2(480, 390), Vector2(100, 16))
	_add_platform(Vector2(660, 310), Vector2(90, 16))
	_add_platform(Vector2(830, 230), Vector2(100, 16))

	# Dead-end lure platform (off to the side, not on the path)
	_add_platform(Vector2(200, 300), Vector2(80, 16), Color(0.55, 0.45, 0.25))


func _play_world_music() -> void:
	if not AudioManager:
		return
	if "WORLD_MUSIC" in AudioManager:
		var track = AudioManager.WORLD_MUSIC.get(world_number, "")
		if track:
			AudioManager.play_music(track)
			return
	AudioManager.play_music("res://assets/audio/music/meadow_theme.ogg")


# ── helpers ──────────────────────────────────────────────────────────────────

func _add_platform(pos: Vector2, size: Vector2,
		color: Color = Color(0.32, 0.58, 0.22)) -> void:
	var body := StaticBody2D.new()
	body.position = pos

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)

	var vis := ColorRect.new()
	vis.offset_left  = -size.x * 0.5
	vis.offset_top   = -size.y * 0.5
	vis.offset_right =  size.x * 0.5
	vis.offset_bottom = size.y * 0.5
	vis.color = color
	body.add_child(vis)

	# Grass strip on top
	var grass := ColorRect.new()
	grass.offset_left  = -size.x * 0.5
	grass.offset_top   = -size.y * 0.5 - 4
	grass.offset_right =  size.x * 0.5
	grass.offset_bottom = -size.y * 0.5
	grass.color = Color(0.42, 0.72, 0.28)
	body.add_child(grass)

	add_child(body)
