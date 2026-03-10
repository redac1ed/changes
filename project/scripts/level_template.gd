extends Node2D
class_name LevelTemplate

@export_category("Level Info")
@export var level_number: int = 1
@export var world_number: int = 1

@export_category("Camera")
@export var camera_limits: Rect2 = Rect2(-2000, -2000, 8000, 6000)
@export var camera_zoom: float = 1.0
@export var use_camera_stop_markers: bool = true
@export var left_stop_marker: NodePath = ^"CameraLeftStop"
@export var right_stop_marker: NodePath = ^"CameraRightStop"
@export var top_stop_marker: NodePath = ^"CameraTopStop"
@export var bottom_stop_marker: NodePath = ^"CameraBottomStop"
@export var bottom_stop_offset: float = -200.0
@export var auto_detect_bottom_offset: float = -200.0

@export_category("Level Settings")
@export var enable_parallax: bool = true
@export var enable_hud: bool = true
@export var enable_pause: bool = true
@export var enable_music: bool = true
@export var music_track: String = ""

var ball_scene: PackedScene = preload("res://scenes/ball.tscn")

var ball: RigidBody2D
var camera: Camera2D
var hud: GameHUD
var pause_overlay: PauseOverlay
var complete_screen: LevelCompleteScreen
var transition_fx: SceneTransitionFX

var level_complete: bool = false
var level_time: float = 0.0
var _restart_cooldown: float = 0.0
var _spawn_position: Vector2


func _ready() -> void:
	print("[Level] Initializing world=%d level=%d" % [world_number, level_number])

	_setup_ball()
	_setup_camera()

	if enable_hud:
		_setup_hud()

	if enable_pause:
		_setup_pause()

	_setup_complete_screen()
	_setup_transitions()

	if GameState:
		GameState.start_level(world_number, level_number)

	if enable_parallax:
		var bg := ParallaxDecoration.create_for_world(world_number)
		add_child(bg)
		move_child(bg, 0)

	if enable_music and AudioManager:
		if music_track.is_empty():
			_play_world_music()
		else:
			AudioManager.play_music(music_track)

	_build_level()
	if not _apply_camera_stop_markers():
		_auto_detect_camera_limits()
	_apply_camera_limits()
	_connect_goal_zone()

	if hud:
		hud.set_level_info(world_number, level_number)

	if transition_fx:
		transition_fx.play_out(SceneTransitionFX.TransitionType.FADE, 0.5)

	print("[Level] Ready — bounds=%s" % [camera_limits])


func _process(delta: float) -> void:
	if level_complete:
		return

	if _restart_cooldown > 0:
		_restart_cooldown -= delta

	level_time += delta
	if hud:
		hud.level_time = level_time


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				if _restart_cooldown <= 0 and not level_complete:
					_restart_level()
			KEY_ENTER:
				if level_complete:
					_next_level()


func _build_level() -> void:
	pass


func _apply_camera_stop_markers() -> bool:
	if not use_camera_stop_markers:
		return false

	var left_node := get_node_or_null(left_stop_marker) as Node2D
	var right_node := get_node_or_null(right_stop_marker) as Node2D
	if left_node == null or right_node == null:
		return false

	var left_x := minf(left_node.global_position.x, right_node.global_position.x)
	var right_x := maxf(left_node.global_position.x, right_node.global_position.x)

	var top_y := camera_limits.position.y
	var bottom_y := camera_limits.end.y

	var top_node := get_node_or_null(top_stop_marker) as Node2D
	if top_node:
		top_y = top_node.global_position.y

	var bottom_node := get_node_or_null(bottom_stop_marker) as Node2D
	if bottom_node:
		bottom_y = bottom_node.global_position.y + bottom_stop_offset

	if bottom_y <= top_y:
		bottom_y = top_y + 800.0

	camera_limits = Rect2(left_x, top_y, right_x - left_x, bottom_y - top_y)
	print("[Level] Camera limits from stop markers: %s" % [camera_limits])
	return true


func _auto_detect_camera_limits() -> void:
	var found := false
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for child in get_children():
		if child is TileMapLayer:
			var tilemap: TileMapLayer = child
			var used := tilemap.get_used_rect()
			if used.size == Vector2i.ZERO:
				continue
			var tile_size := Vector2(tilemap.tile_set.tile_size) if tilemap.tile_set else Vector2(16, 16)
			var sc: Vector2 = tilemap.scale
			var top_left := tilemap.position + Vector2(used.position) * tile_size * sc
			var bottom_right := tilemap.position + Vector2(used.end) * tile_size * sc
			min_pos.x = minf(min_pos.x, minf(top_left.x, bottom_right.x))
			min_pos.y = minf(min_pos.y, minf(top_left.y, bottom_right.y))
			max_pos.x = maxf(max_pos.x, maxf(top_left.x, bottom_right.x))
			max_pos.y = maxf(max_pos.y, maxf(top_left.y, bottom_right.y))
			found = true
	if found:
		var margin := 32.0
		var min_x := min_pos.x - margin
		var min_y := min_pos.y - margin
		var max_x := max_pos.x + margin
		var max_y := max_pos.y + margin + auto_detect_bottom_offset
		if max_y <= min_y + 64.0:
			max_y = min_y + 64.0
		camera_limits = Rect2(
			min_x,
			min_y,
			max_x - min_x,
			max_y - min_y
		)
		print("[Level] Auto camera limits: %s" % [camera_limits])


func _apply_camera_limits() -> void:
	if camera and "world_bounds" in camera:
		camera.world_bounds = camera_limits
	if ball and "world_bounds" in ball:
		ball.world_bounds = camera_limits


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

	if ball.has_signal("shot_fired"):
		ball.shot_fired.connect(_on_shot_fired)


func _setup_camera() -> void:
	var cam_script := load("res://scripts/game_camera.gd")
	camera = Camera2D.new()
	if cam_script:
		camera.set_script(cam_script)

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

	if ball and "target_path" in camera:
		camera.target_path = camera.get_path_to(ball)


func _setup_hud() -> void:
	hud = GameHUD.new()
	hud.is_paused = false
	hud.level_time = 0.0
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


func _connect_goal_zone() -> void:
	var goal_zone := get_node_or_null("GoalZone") as Area2D
	if goal_zone and not goal_zone.body_entered.is_connected(on_goal_reached):
		goal_zone.body_entered.connect(on_goal_reached)


func _on_shot_fired(_count: int) -> void:
	if hud:
		hud.add_shot()

	if GameState:
		GameState.add_shots(1)


func complete_level() -> void:
	if level_complete:
		return

	level_complete = true
	var shots: int = ball.shot_count if ball else 0

	var result: Dictionary = {}
	if GameState:
		result = GameState.complete_level(world_number, level_number, shots)

	var stars: int = result.get("stars", GameState.calculate_stars(shots) if GameState else 0)
	var is_new_record: bool = result.get("new_record", result.get("is_new_record", false))

	if complete_screen:
		complete_screen.show_screen(shots, stars, is_new_record, level_time)

	if hud:
		hud.level_time = level_time
		hud.is_paused = true
		hud.show_notification("Level Complete!", Color(0.3, 0.9, 0.45))


func on_goal_reached(body: Node2D) -> void:
	if body == ball:
		complete_level()


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
