extends Area2D
class_name LevelFinishDoor

## ═══════════════════════════════════════════════════════════════════════════════
## LevelFinishDoor — Animated door that triggers level completion
## ═══════════════════════════════════════════════════════════════════════════════
##
## Inspired by the starter kit's LevelFinishDoor but with
## animated visuals, proximity glow, particle effects, and integrated
## scoring/transition.

# ─── Signals ─────────────────────────────────────────────────────────────────
signal door_entered(ball: RigidBody2D)
signal door_opened()

# ─── Exports ─────────────────────────────────────────────────────────────────
@export_category("Door Properties")
@export var door_size: Vector2 = Vector2(40, 60)
@export var door_color: Color = Color(0.85, 0.7, 0.3, 1.0)
@export var frame_color: Color = Color(0.5, 0.35, 0.15, 1.0)
@export var glow_color: Color = Color(1.0, 0.9, 0.5, 0.3)
@export var glow_range: float = 100.0
@export var auto_transition: bool = true
@export var transition_delay: float = 1.5

@export_category("Visual")
@export var animated: bool = true
@export var show_stars: bool = true
@export var show_beacon: bool = true

# ─── Internal ────────────────────────────────────────────────────────────────
var _time_elapsed: float = 0.0
var _is_open: bool = false
var _open_progress: float = 0.0
var _proximity: float = 0.0
var _collision_shape: CollisionShape2D
var _beacon_particles: CPUParticles2D
var _star_particles: CPUParticles2D
var _entered: bool = false


func _ready() -> void:
	# Door collision
	_collision_shape = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = door_size
	_collision_shape.shape = shape
	add_child(_collision_shape)
	
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	
	_setup_beacon()
	_setup_star_particles()


func _process(delta: float) -> void:
	_time_elapsed += delta
	
	# Animate door opening
	if _is_open and _open_progress < 1.0:
		_open_progress = minf(_open_progress + delta * 2.0, 1.0)
	
	# Check proximity to ball for glow effect
	_update_proximity()
	
	queue_redraw()


func _setup_beacon() -> void:
	if not show_beacon:
		return
	_beacon_particles = CPUParticles2D.new()
	_beacon_particles.emitting = true
	_beacon_particles.amount = 8
	_beacon_particles.lifetime = 1.5
	_beacon_particles.direction = Vector2.UP
	_beacon_particles.spread = 15.0
	_beacon_particles.gravity = Vector2(0, -20)
	_beacon_particles.initial_velocity_min = 15.0
	_beacon_particles.initial_velocity_max = 35.0
	_beacon_particles.scale_amount_min = 1.0
	_beacon_particles.scale_amount_max = 2.5
	_beacon_particles.color = Color(1.0, 0.9, 0.5, 0.4)
	_beacon_particles.position = Vector2(0, -door_size.y / 2.0)
	add_child(_beacon_particles)


func _setup_star_particles() -> void:
	_star_particles = CPUParticles2D.new()
	_star_particles.emitting = false
	_star_particles.one_shot = true
	_star_particles.amount = 20
	_star_particles.lifetime = 0.8
	_star_particles.explosiveness = 0.8
	_star_particles.direction = Vector2.UP
	_star_particles.spread = 180.0
	_star_particles.gravity = Vector2(0, 50)
	_star_particles.initial_velocity_min = 50.0
	_star_particles.initial_velocity_max = 150.0
	_star_particles.scale_amount_min = 2.0
	_star_particles.scale_amount_max = 4.0
	_star_particles.color = Color(1.0, 0.85, 0.3, 0.8)
	add_child(_star_particles)


func _update_proximity() -> void:
	# Find nearby ball
	_proximity = 0.0
	var bodies := get_overlapping_bodies()
	for body in bodies:
		if body is RigidBody2D:
			var dist := global_position.distance_to(body.global_position)
			_proximity = clampf(1.0 - dist / glow_range, 0.0, 1.0)
			break


func _on_body_entered(body: Node2D) -> void:
	if _entered:
		return
	if body is RigidBody2D:
		_entered = true
		_is_open = true
		
		# Celebration particles
		_star_particles.restart()
		_star_particles.emitting = true
		
		# Stop the ball
		body.linear_velocity = Vector2.ZERO
		body.angular_velocity = 0.0
		
		# SFX
		if AudioManager and AudioManager.has_method("play_goal_reached"):
			AudioManager.play_goal_reached(0)
		
		door_entered.emit(body)
		door_opened.emit()
		
		# Tween ball into door
		var tw := create_tween()
		tw.tween_property(body, "global_position", global_position, 0.4).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(body, "scale", Vector2(0.3, 0.3), 0.4)
		tw.parallel().tween_property(body, "modulate:a", 0.0, 0.4)
		
		if auto_transition:
			await tw.finished
			await get_tree().create_timer(transition_delay - 0.4).timeout
			_complete_level()


func _complete_level() -> void:
	# Find level info
	var level_root := _find_level_root()
	if level_root:
		var world_num: int = level_root.get("world_number") if level_root.get("world_number") != null else 1
		var level_num: int = level_root.get("level_number") if level_root.get("level_number") != null else 1
		var shots: int = 0
		
		# Find ball shot count
		for child in level_root.get_children():
			if child is RigidBody2D and child.has_method("get") and "shot_count" in child:
				shots = child.shot_count
				break
		
		if GameState:
			GameState.complete_level(world_num, level_num, shots)
		if LevelManager:
			LevelManager.call_deferred("load_next_level")
	else:
		# Fallback
		if LevelManager:
			LevelManager.call_deferred("load_next_level")


func _find_level_root() -> Node:
	var node: Node = get_parent()
	while node != null:
		if "world_number" in node or "level_number" in node:
			return node
		if node.has_node("BallSpawn"):
			return node
		node = node.get_parent()
	return null


# ─── Drawing ─────────────────────────────────────────────────────────────────

func _draw() -> void:
	var half := door_size / 2.0
	
	# Proximity glow
	if _proximity > 0.05:
		var glow_size := door_size + Vector2(20, 20) * _proximity
		var gc := Color(glow_color.r, glow_color.g, glow_color.b, _proximity * 0.2)
		draw_rect(Rect2(-glow_size / 2.0, glow_size), gc, true)
	
	# Door frame
	var frame_rect := Rect2(
		Vector2(-half.x - 4, -half.y - 4),
		Vector2(door_size.x + 8, door_size.y + 4)
	)
	draw_rect(frame_rect, frame_color, true)
	draw_rect(frame_rect, frame_color.darkened(0.2), false, 2.0)
	
	# Frame top decoration (arch)
	var arch_color := frame_color.lightened(0.15)
	draw_rect(
		Rect2(Vector2(-half.x - 6, -half.y - 8), Vector2(door_size.x + 12, 6)),
		arch_color, true
	)
	
	# Door panels
	var door_rect := Rect2(-half, door_size)
	if _is_open:
		_draw_open_door(door_rect)
	else:
		_draw_closed_door(door_rect)
	
	# Floor threshold
	draw_rect(
		Rect2(Vector2(-half.x - 2, half.y), Vector2(door_size.x + 4, 3)),
		frame_color.darkened(0.1), true
	)
	
	# Star above door
	if show_stars and animated:
		_draw_door_star()
	
	# Beacon light
	if show_beacon and not _is_open:
		var beacon_alpha := 0.1 + sin(_time_elapsed * 2.0) * 0.05 + _proximity * 0.1
		var beacon_w := 3.0
		draw_rect(
			Rect2(Vector2(-beacon_w / 2.0, -half.y - 60), Vector2(beacon_w, 56)),
			Color(1.0, 0.9, 0.5, beacon_alpha), true
		)


func _draw_closed_door(rect: Rect2) -> void:
	# Two panels
	var panel_w := rect.size.x / 2.0 - 1
	
	# Left panel
	var left_rect := Rect2(rect.position, Vector2(panel_w, rect.size.y))
	draw_rect(left_rect, door_color, true)
	draw_rect(left_rect, door_color.darkened(0.15), false, 1.0)
	
	# Right panel
	var right_rect := Rect2(
		rect.position + Vector2(panel_w + 2, 0),
		Vector2(panel_w, rect.size.y)
	)
	draw_rect(right_rect, door_color, true)
	draw_rect(right_rect, door_color.darkened(0.15), false, 1.0)
	
	# Panel details
	var detail_color := door_color.darkened(0.1)
	draw_rect(
		Rect2(rect.position + Vector2(3, 4), Vector2(panel_w - 6, rect.size.y * 0.4)),
		detail_color, false, 1.0
	)
	draw_rect(
		Rect2(rect.position + Vector2(panel_w + 5, 4), Vector2(panel_w - 6, rect.size.y * 0.4)),
		detail_color, false, 1.0
	)
	
	# Door handle
	var handle_y := rect.position.y + rect.size.y * 0.55
	draw_circle(Vector2(rect.position.x + panel_w - 5, handle_y), 2.5, frame_color)
	draw_circle(Vector2(rect.position.x + panel_w + 7, handle_y), 2.5, frame_color)


func _draw_open_door(rect: Rect2) -> void:
	# Dark interior
	draw_rect(rect, Color(0.1, 0.08, 0.05, 0.9), true)
	
	# Light from inside
	var inner_glow := Color(1.0, 0.9, 0.5, 0.15 + sin(_time_elapsed * 3.0) * 0.05)
	draw_rect(
		Rect2(rect.position + Vector2(4, 4), rect.size - Vector2(8, 8)),
		inner_glow, true
	)
	
	# Door panels swung open (perspective effect)
	var panel_w := 5.0 * (1.0 - _open_progress * 0.5)
	draw_rect(
		Rect2(rect.position, Vector2(panel_w, rect.size.y)),
		door_color.darkened(0.3), true
	)
	draw_rect(
		Rect2(Vector2(rect.position.x + rect.size.x - panel_w, rect.position.y), Vector2(panel_w, rect.size.y)),
		door_color.darkened(0.3), true
	)


func _draw_door_star() -> void:
	var star_y := -door_size.y / 2.0 - 20
	var star_size := 6.0 + sin(_time_elapsed * 2.0) * 1.5
	var star_color := Color(1.0, 0.9, 0.4, 0.7 + sin(_time_elapsed * 3.0) * 0.2)
	
	# Five-pointed star
	var points := PackedVector2Array()
	for i in range(10):
		var angle := i * TAU / 10.0 - PI / 2.0
		var r := star_size if i % 2 == 0 else star_size * 0.4
		points.append(Vector2(cos(angle), sin(angle)) * r + Vector2(0, star_y))
	draw_colored_polygon(points, star_color)
