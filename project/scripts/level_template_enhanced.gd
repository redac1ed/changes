extends Node2D
class_name LevelTemplateEnhanced

## ═══════════════════════════════════════════════════════════════════════════════
## LevelTemplateEnhanced — Full-featured level template with all systems
## ═══════════════════════════════════════════════════════════════════════════════
##
## Handles ball spawning, camera setup, HUD, pause menu, level completion,
## coin tracking, checkpoints, parallax backgrounds, and scene transitions.
## Replaces the original LevelTemplate with comprehensive integration.
##
## Usage:
##   Extend this script for each level. Override _build_level() to place
##   platforms, enemies, coins, etc. using the integrated LevelBuilder.

# ─── Exports ─────────────────────────────────────────────────────────────────
@export_category("Level Info")
@export var level_number: int = 1
@export var world_number: int = 1
@export var level_name: String = ""

@export_category("Camera")
@export var camera_limits: Rect2 = Rect2(0, 0, 1200, 800)
@export var camera_zoom: float = 1.0

@export_category("Level Settings")
@export var par_shots: int = 3
@export var time_limit: float = 0.0  # 0 = no time limit
@export var enable_parallax: bool = true
@export var enable_hud: bool = true
@export var enable_pause: bool = true
@export var enable_music: bool = true
@export var music_track: String = ""

# ─── Scene References ───────────────────────────────────────────────────────
var ball_scene: PackedScene = preload("res://scenes/ball.tscn")

# ─── Runtime References ─────────────────────────────────────────────────────
var ball: RigidBody2D
var camera: Camera2D
var hud: GameHUD
var pause_overlay: PauseOverlay
var complete_screen: LevelCompleteScreen
var builder: LevelBuilder
var transition_fx: SceneTransitionFX

# ─── Level State ─────────────────────────────────────────────────────────────
var level_complete: bool = false
var level_time: float = 0.0
var coins_collected: int = 0
var total_coins: int = 0
var deaths: int = 0
var _restart_cooldown: float = 0.0
var _spawn_position: Vector2


func _ready() -> void:
	print("[Level] Initializing world=%d level=%d" % [world_number, level_number])
	
	# Initialize builder
	builder = LevelBuilder.new()
	builder.set_level(self)
	add_child(builder)
	
	# Spawn ball
	_setup_ball()
	
	# Camera
	_setup_camera()
	
	# HUD
	if enable_hud:
		_setup_hud()
	
	# Pause
	if enable_pause:
		_setup_pause()
	
	# Level complete screen
	_setup_complete_screen()
	
	# Scene transitions
	_setup_transitions()
	
	# Parallax background
	if enable_parallax:
		var bg := ParallaxDecoration.create_for_world(world_number)
		add_child(bg)
		move_child(bg, 0)
	
	# Music
	if enable_music and AudioManager:
		if music_track.is_empty():
			# Default music based on world
			_play_world_music()
		else:
			AudioManager.play_music(music_track)
	
	# Build the level content (override this in subclasses)
	_build_level()
	
	# Count coins in level
	total_coins = _count_coins()
	if hud:
		hud.total_coins_in_level = total_coins
		hud.set_level_info(world_number, level_number)
	
	# Transition in
	if transition_fx:
		transition_fx.play_out(SceneTransitionFX.TransitionType.FADE, 0.5)
	
	print("[Level] Ready — %d coins, bounds=%s" % [total_coins, camera_limits])


func _process(delta: float) -> void:
	if level_complete:
		return
	
	if _restart_cooldown > 0:
		_restart_cooldown -= delta
	
	level_time += delta
	
	# Time limit
	if time_limit > 0 and level_time >= time_limit:
		_on_time_up()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				if _restart_cooldown <= 0 and not level_complete:
					_restart_level()
			KEY_ENTER:
				if level_complete:
					_next_level()


# ═══════════════════════════════════════════════════════════════════════════════
#  VIRTUAL — Override in subclasses
# ═══════════════════════════════════════════════════════════════════════════════

func _build_level() -> void:
	"""Override this method to construct the level using self.builder."""
	pass


func _on_level_complete_custom() -> void:
	"""Override for custom level complete logic."""
	pass


func _on_ball_reset() -> void:
	"""Override for custom ball reset logic."""
	pass


# ═══════════════════════════════════════════════════════════════════════════════
#  SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func _setup_ball() -> void:
	var spawn: Marker2D = get_node_or_null("BallSpawn")
	if spawn:
		_spawn_position = spawn.position
	else:
		_spawn_position = Vector2(100, 400)
		var marker := Marker2D.new()
		marker.name = "BallSpawn"
		marker.position = _spawn_position
		add_child(marker)
	
	ball = ball_scene.instantiate()
	ball.position = _spawn_position
	if "world_bounds" in ball:
		ball.world_bounds = camera_limits
	add_child(ball)
	
	# Connect ball signals
	if ball.has_signal("shot_fired"):
		ball.shot_fired.connect(_on_shot_fired)


func _setup_camera() -> void:
	var cam_script := load("res://scripts/game_camera_enhanced.gd")
	if cam_script:
		camera = Camera2D.new()
		camera.set_script(cam_script)
	else:
		# Fallback to existing camera
		var cam_script_fallback := load("res://scripts/game_camera_advanced.gd")
		camera = Camera2D.new()
		if cam_script_fallback:
			camera.set_script(cam_script_fallback)
	
	camera.world_bounds = camera_limits
	camera.use_limits = true
	if "center_if_undersized" in camera:
		camera.center_if_undersized = true
	elif "center_if_missized" in camera:
		camera.center_if_missized = true
	
	if camera_zoom != 1.0:
		camera.zoom = Vector2(camera_zoom, camera_zoom)
		if "default_zoom" in camera:
			camera.default_zoom = Vector2(camera_zoom, camera_zoom)
	
	if ball:
		camera.global_position = ball.global_position
	
	add_child(camera)
	camera.make_current()
	
	# Set target
	if ball and "target_path" in camera:
		camera.target_path = camera.get_path_to(ball)


func _setup_hud() -> void:
	hud = GameHUD.new()
	add_child(hud)


func _setup_pause() -> void:
	pause_overlay = PauseOverlay.new()
	pause_overlay.restarted.connect(_restart_level)
	pause_overlay.quit_to_menu.connect(_quit_to_menu)
	add_child(pause_overlay)


func _setup_complete_screen() -> void:
	complete_screen = LevelCompleteScreen.new()
	complete_screen.next_level_pressed.connect(_next_level)
	complete_screen.retry_pressed.connect(_restart_level)
	complete_screen.menu_pressed.connect(_quit_to_menu)
	add_child(complete_screen)


func _setup_transitions() -> void:
	transition_fx = SceneTransitionFX.new()
	add_child(transition_fx)


# ═══════════════════════════════════════════════════════════════════════════════
#  LEVEL EVENTS
# ═══════════════════════════════════════════════════════════════════════════════

func _on_shot_fired(count: int) -> void:
	if hud:
		hud.add_shot()
	
	if GameState:
		GameState.add_shots(1)


func complete_level() -> void:
	if level_complete:
		return
	
	level_complete = true
	var shots: int = ball.shot_count if ball else 0
	
	# GameState tracking
	var result: Dictionary = {}
	if GameState:
		result = GameState.complete_level(world_number, level_number, shots)
	
	var stars: int = result.get("stars", GameState.calculate_stars(shots) if GameState else 0)
	var is_new_record: bool = result.get("is_new_record", false)
	
	# Show completion screen
	if complete_screen:
		complete_screen.show_screen(shots, stars, coins_collected, total_coins, is_new_record, level_time)
	
	# HUD notification
	if hud:
		hud.show_notification("Level Complete!", Color(0.3, 0.9, 0.45))
	
	_on_level_complete_custom()


func on_goal_reached(body: Node2D) -> void:
	"""Connect this to a GoalZone's body_entered signal."""
	if body == ball:
		complete_level()


func on_coin_collected(coin_value: int) -> void:
	coins_collected += 1
	if hud:
		hud.add_coin(coin_value)


func reset_ball() -> void:
	"""Reset ball to last checkpoint or spawn."""
	if not ball:
		return
	
	deaths += 1
	
	# Find active checkpoint
	var checkpoint_pos := _spawn_position
	for child in get_children():
		if child is Checkpoint and child._is_activated:
			checkpoint_pos = child.global_position + Vector2(0, -15)
			break
	
	ball.global_position = checkpoint_pos
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	
	if camera and "add_trauma" in camera:
		camera.add_trauma(0.3)
	
	if hud:
		hud.show_notification("Respawned", Color(0.9, 0.5, 0.2))
	
	_on_ball_reset()


func _on_time_up() -> void:
	if hud:
		hud.show_notification("Time's Up!", Color(1.0, 0.3, 0.2))
	reset_ball()


func _restart_level() -> void:
	_restart_cooldown = 0.5
	if transition_fx:
		transition_fx.play(SceneTransitionFX.TransitionType.FADE, 0.5, func():
			get_tree().reload_current_scene()
		)
	else:
		get_tree().reload_current_scene()


func _next_level() -> void:
	_restart_cooldown = 0.5
	if transition_fx:
		transition_fx.play(SceneTransitionFX.TransitionType.CIRCLE_WIPE, 0.8, func():
			LevelManager.load_next_level()
		)
	else:
		LevelManager.load_next_level()


func _quit_to_menu() -> void:
	if transition_fx:
		transition_fx.play(SceneTransitionFX.TransitionType.CURTAIN, 0.6, func():
			get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
		)
	else:
		get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")


func _play_world_music() -> void:
	if not AudioManager:
		return
	match world_number:
		0: AudioManager.stop_music(0.5)
		1: AudioManager.play_music("meadow")
		2: AudioManager.play_music("volcano")
		3: AudioManager.play_music("sky")
		4: AudioManager.play_music("ocean")
		5: AudioManager.play_music("space")
		6: AudioManager.play_music("bonus")


func _count_coins() -> int:
	var count := 0
	for child in get_children():
		if child is CoinCollectible:
			count += 1
		# Also check nested children
		for grandchild in child.get_children():
			if grandchild is CoinCollectible:
				count += 1
	return count
