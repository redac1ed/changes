extends Node2D

## Template for level scenes
## Handles ball spawning, goal setup, and level completion

@export var level_number: int = 1
@export var world_number: int = 1

var ball_scene: PackedScene = preload("res://scenes/ball.tscn")
var goal_scene: PackedScene = preload("res://scenes/goal.tscn")

@onready var ball_spawn: Marker2D = $BallSpawn
@onready var goal_zone: Area2D = $GoalZone

@export var camera_limits: Rect2 = Rect2(0, 0, 1200, 800)

var ball: RigidBody2D
var camera: Camera2D

func _ready() -> void:
	print("[LevelTemplate] _ready() — world=%d level=%d" % [world_number, level_number])
	# Spawn ball at spawn point
	if ball_spawn:
		ball = ball_scene.instantiate()
		ball.position = ball_spawn.position
		ball.world_bounds = camera_limits
		add_child(ball)
		print("[LevelTemplate] Ball spawned at %s" % str(ball_spawn.position))
	else:
		print("[LevelTemplate] WARNING: No BallSpawn node found!")
	
	# Set up goal
	if goal_zone:
		goal_zone.body_entered.connect(_on_goal_entered)
		print("[LevelTemplate] GoalZone connected at %s" % str(goal_zone.position))
	else:
		print("[LevelTemplate] WARNING: No GoalZone node found!")
	
	# Set up camera to follow ball
	camera = Camera2D.new()
	var camera_script = load("res://scripts/game_camera_advanced.gd")
	camera.set_script(camera_script)
	
	# Configure camera BEFORE adding to tree so _ready sees correct values
	camera.world_bounds = camera_limits
	camera.use_limits = true
	camera.center_if_missized = true
	if ball:
		camera.target_path = NodePath()  # will resolve in _ready via fallback
		camera.global_position = ball.global_position
	
	add_child(camera)
	camera.make_current()
	print("[LevelTemplate] Camera added, limits=%s" % str(camera_limits))
	
	# Resolve target path now that both are in tree
	if ball and "target_path" in camera:
		camera.target_path = camera.get_path_to(ball)
		print("[LevelTemplate] Camera target set to: %s" % str(camera.target_path))

func _on_goal_entered(body: Node2D) -> void:
	print("[LevelTemplate] _on_goal_entered: body=%s (class=%s)" % [body.name, body.get_class()])
	if body == ball:
		print("[LevelTemplate] GOAL! world=%d level=%d shots=%d" % [world_number, level_number, ball.shot_count])
		# Level complete — defer to avoid removing CollisionObjects during physics callback
		GameState.complete_level(world_number, level_number, ball.shot_count)
		LevelManager.call_deferred("load_next_level")
	else:
		print("[LevelTemplate] body != ball, ignoring")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("reset"):
		# Reset ball position
		if ball:
			ball.position = ball_spawn.position
			ball.linear_velocity = Vector2.ZERO
			ball.shot_count = 0
