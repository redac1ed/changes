extends LevelTemplate

const SUBTITLE_VICTORY_1 := "I feel like this is gonna be a boss fight..."
const SUBTITLE_DEATH_1 := "Are you that bad? This game is SO easy!"
const SUBTITLE_DEATH_2 := "I.. don't even know what to say."
const SUBTITLE_BOSS_1 := "What the hell is this? Why are some random alien emojis chasing us??"

var _subtitles: SubtitleOverlay
var _main_layer: TileMapLayer

var _aliens: Array[FloatingAlien] = []
var _alien_indicator_layer: CanvasLayer
var _alien_indicator_control: Control
var _has_played_boss_audio: bool = false
var _alien_hit_count: int = 0

class FloatingAlien extends Node2D:
	var label: Label
	var target: Node2D
	var speed: float = 150.0
	var aggro_range: float = 600.0
	var attack_range: float = 40.0
	var attack_cooldown: float = 0.0
	var knockback_force: float = 800.0
	
	var base_pos: Vector2
	var roam_target: Vector2
	var roam_timer: float = 0.0
	var roam_speed: float = 50.0
	var time_passed: float = 0.0
	var random_offset: float
	var is_chasing: bool = false
	
	func _init(start_pos: Vector2, p_target: Node2D) -> void:
		position = start_pos
		base_pos = start_pos
		roam_target = start_pos
		target = p_target
		random_offset = randf() * TAU
		
		label = Label.new()
		label.text = "👽"
		label.add_theme_font_size_override("font_size", 48)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector2(-24, -24)
		add_child(label)
		
	func _process(delta: float) -> void:
		time_passed += delta
		if attack_cooldown > 0:
			attack_cooldown -= delta
			
		if not is_instance_valid(target):
			return
			
		var dist = global_position.distance_to(target.global_position)
		
		if dist < aggro_range:
			var dir = global_position.direction_to(target.global_position)
			global_position += dir * speed * delta
			label.position.y = -24 # Reset bobbing
			if dist < attack_range and attack_cooldown <= 0:
				if target is RigidBody2D:
					var knockback_dir = global_position.direction_to(target.global_position)
					target.apply_central_impulse(knockback_dir * knockback_force)
					attack_cooldown = 2.0
					
					# Try to play the boss audio when hitting the player
					var level = get_parent()
					if level:
						if "play_boss_audio" in level:
							level.play_boss_audio()
						if "register_alien_hit" in level:
							level.register_alien_hit()
						
					var tween = create_tween()
					label.modulate = Color.RED
					tween.tween_property(label, "modulate", Color.WHITE, 0.5)
		else:
			roam_timer -= delta
			if roam_timer <= 0 or global_position.distance_to(roam_target) < 10.0:
				roam_timer = randf_range(2.0, 5.0)
				var random_angle = randf() * TAU
				var random_dist = randf_range(50.0, 200.0)
				roam_target = base_pos + Vector2(cos(random_angle), sin(random_angle)) * random_dist
				
			var dir = global_position.direction_to(roam_target)
			global_position += dir * roam_speed * delta
			label.position.y = -24 + sin(time_passed * 3.0 + random_offset) * 10.0

func _ready() -> void:
	_subtitles = SubtitleOverlay.new()
	add_child(_subtitles)
	_main_layer = get_node_or_null("main_layer")
	
	_setup_alien_indicators()
	
	super._ready()
	if hud:
		hud.show_notification("Level 2", Color(0.5, 0.9, 0.7))
	_play_random_victory_audio()

func _setup_alien_indicators() -> void:
	_alien_indicator_layer = CanvasLayer.new()
	_alien_indicator_layer.layer = 5 
	add_child(_alien_indicator_layer)
	
	_alien_indicator_control = Control.new()
	_alien_indicator_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_alien_indicator_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alien_indicator_control.draw.connect(_on_indicator_draw)
	_alien_indicator_layer.add_child(_alien_indicator_control)

func _play_random_victory_audio() -> void:
	if AudioManager:
		AudioManager.stop_music(0.2)
	var victory_player := AudioStreamPlayer.new()
	victory_player.bus = "Music"
	add_child(victory_player)
	victory_player.stream = load("res://assets/audio/bossfight_2.mp3")
	var victory_subtitle = SUBTITLE_VICTORY_1
	victory_player.play()
	_subtitles.show_line(victory_subtitle)
	victory_player.finished.connect(func():
		_subtitles.hide_line()
		victory_player.queue_free()
		if AudioManager:
			var track: String = AudioManager.WORLD_MUSIC.get(world_number,
					"res://assets/audio/music/meadow_theme.ogg")
			AudioManager.play_music(track)
	, CONNECT_ONE_SHOT)

func _play_world_music() -> void:
	if not AudioManager:
		return
	var track: String = AudioManager.WORLD_MUSIC.get(world_number,
			"res://assets/audio/music/meadow_theme.ogg")
	AudioManager.play_music(track)

func register_alien_hit() -> void:
	_alien_hit_count += 1
	if _alien_hit_count >= 5:
		if is_instance_valid(ball):
			_on_ball_killed(ball)

func play_boss_audio() -> void:
	if _has_played_boss_audio:
		return
	_has_played_boss_audio = true
	
	if AudioManager:
		AudioManager.stop_music(0.2)
		
	var boss_player := AudioStreamPlayer.new()
	boss_player.bus = "Music"
	add_child(boss_player)
	boss_player.stream = load("res://assets/audio/bossfight_1.mp3")
	boss_player.play()
	_subtitles.show_line(SUBTITLE_BOSS_1)
	
	boss_player.finished.connect(func():
		_subtitles.hide_line()
		boss_player.queue_free()
		if AudioManager:
			var track: String = AudioManager.WORLD_MUSIC.get(world_number,
					"res://assets/audio/music/meadow_theme.ogg")
			AudioManager.play_music(track)
	, CONNECT_ONE_SHOT)

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(_alien_indicator_control):
		_alien_indicator_control.queue_redraw()
	if not _main_layer:
		return
	var btn1 = get_node_or_null("button/Area2D")
	var btn2 = get_node_or_null("button2/Area2D")
	var btn3 = get_node_or_null("button3/Area2D")
	var btn4 = get_node_or_null("button4/Area2D")

	var end_hint = get_node_or_null("ending_hint")
	var goal_collision = get_node_or_null("GoalZone/CollisionShape2D")
	var goal = goal_collision.get_parent() if goal_collision else null

	if btn1 and btn2 and btn3 and btn1.button_pressed and btn2.button_pressed and btn3.button_pressed:
		for i in range(43, 51):
			for j in range(18, 22):
				_main_layer.set_cell(Vector2i(i, j), -1, Vector2i(-1, -1))

	if btn4 and btn4.button_pressed and end_hint and goal_collision and goal:
		end_hint.visible = true
		goal_collision.disabled = false
		goal.visible = true

func _build_level() -> void:
	super._build_level()
	for trap in get_tree().get_nodes_in_group("traps"):
		if trap.has_signal("ball_killed"):
			trap.ball_killed.connect(_on_ball_killed)
			
	# Spawn some aliens around the level
	# We'll spawn them relative to the ball's starting position or fixed points
	var spawn_points = [
		Vector2(500, 200),
		Vector2(1200, 300),
		Vector2(800, -100),
		Vector2(1500, 100),
		Vector2(2000, 400)
	]
	
	for p in spawn_points:
		var alien = FloatingAlien.new(p, ball)
		add_child(alien)
		_aliens.append(alien)

func _on_indicator_draw() -> void:
	if not is_instance_valid(camera) or not is_instance_valid(ball):
		return
		
	var viewport_rect = get_viewport_rect()
	var cam_pos = camera.get_screen_center_position()
	var zoom = camera.zoom
	
	# Calculate visible world rect
	var visible_rect = Rect2(
		cam_pos - (viewport_rect.size / 2.0) / zoom,
		viewport_rect.size / zoom
	)
	
	var center = viewport_rect.size / 2.0
	var margin = 40.0 # Distance from screen edge
	
	for alien in _aliens:
		if not is_instance_valid(alien):
			continue
			
		# If alien is on screen, don't draw indicator
		if visible_rect.has_point(alien.global_position):
			continue
			
		# Calculate direction from camera center to alien
		var dir = cam_pos.direction_to(alien.global_position)
		
		# Find intersection with screen edges
		var aspect = viewport_rect.size.x / viewport_rect.size.y
		var dir_aspect = abs(dir.x / dir.y) if dir.y != 0 else 999.0
		
		var indicator_pos = Vector2.ZERO
		
		if dir_aspect > aspect:
			# Intersects left/right
			indicator_pos.x = margin if dir.x < 0 else viewport_rect.size.x - margin
			indicator_pos.y = center.y + (indicator_pos.x - center.x) * (dir.y / dir.x)
		else:
			# Intersects top/bottom
			indicator_pos.y = margin if dir.y < 0 else viewport_rect.size.y - margin
			indicator_pos.x = center.x + (indicator_pos.y - center.y) * (dir.x / dir.y)
			
		# Clamp just in case
		indicator_pos.x = clamp(indicator_pos.x, margin, viewport_rect.size.x - margin)
		indicator_pos.y = clamp(indicator_pos.y, margin, viewport_rect.size.y - margin)
		
		# Draw big red triangle
		var angle = dir.angle()
		var arrow_size = 30.0
		var p1 = indicator_pos + Vector2(cos(angle), sin(angle)) * arrow_size
		var p2 = indicator_pos + Vector2(cos(angle + 2.5), sin(angle + 2.5)) * arrow_size
		var p3 = indicator_pos + Vector2(cos(angle - 2.5), sin(angle - 2.5)) * arrow_size
		
		var points = PackedVector2Array([p1, p2, p3])
		
		var color = Color(1.0, 0.0, 0.0, 0.8)
		
		_alien_indicator_control.draw_colored_polygon(points, color)

func _on_ball_killed(_ball: Node2D) -> void:
	if is_instance_valid(_ball) and _ball is RigidBody2D:
		_ball.freeze = true
		_ball.hide()
		
	if AudioManager:
		AudioManager.stop_music(0.2)
	var death_player := AudioStreamPlayer.new()
	death_player.bus = "Music"
	add_child(death_player)
	var use_intro_5 := randf() < 0.5
	death_player.stream = load("res://assets/audio/intro_5.mp3" if use_intro_5 else "res://assets/audio/intro_6.mp3")
	_subtitles.show_line(SUBTITLE_DEATH_1 if use_intro_5 else SUBTITLE_DEATH_2)
	death_player.play()
	death_player.finished.connect(func():
		_subtitles.hide_line()
		death_player.queue_free()
		if AudioManager:
			var track: String = AudioManager.WORLD_MUSIC.get(world_number,
					"res://assets/audio/music/meadow_theme.ogg")
			AudioManager.play_music(track)
		_restart_level()
	, CONNECT_ONE_SHOT)
