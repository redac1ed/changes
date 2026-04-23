extends Area2D
class_name Checkpoint

signal checkpoint_activated(checkpoint_position: Vector2)

@export_category("Checkpoint Properties")
@export var flag_size: Vector2 = Vector2(20, 14)
@export var pole_height: float = 40.0
@export var inactive_color: Color = Color(0.5, 0.5, 0.55, 0.7)
@export var active_color: Color = Color(0.3, 0.85, 0.4, 1.0)
@export var pole_color: Color = Color(0.6, 0.6, 0.65, 1.0)

var _is_activated: bool = false
var _time_elapsed: float = 0.0
var _activation_flash: float = 0.0
var _flag_wave: float = 0.0
var _collision_shape: CollisionShape2D
var _particles: CPUParticles2D

func _ready() -> void:
	_collision_shape = CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, pole_height + 10)
	_collision_shape.shape = shape
	_collision_shape.position = Vector2(0, -pole_height / 2.0)
	add_child(_collision_shape)
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	_particles = CPUParticles2D.new()
	_particles.emitting = false
	_particles.one_shot = true
	_particles.amount = 10
	_particles.lifetime = 0.6
	_particles.explosiveness = 0.8
	_particles.direction = Vector2.UP
	_particles.spread = 120.0
	_particles.gravity = Vector2(0, 100)
	_particles.initial_velocity_min = 40.0
	_particles.initial_velocity_max = 100.0
	_particles.scale_amount_min = 1.5
	_particles.scale_amount_max = 3.0
	_particles.color = active_color
	_particles.position = Vector2(0, -pole_height)
	add_child(_particles)

func _process(delta: float) -> void:
	_time_elapsed += delta
	_flag_wave = sin(_time_elapsed * 3.0) * 0.15
	if _activation_flash > 0:
		_activation_flash -= delta * 3.0
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if _is_activated:
		return
	if body is RigidBody2D:
		_activate(body)

func _activate(ball: RigidBody2D) -> void:
	_is_activated = true
	_activation_flash = 1.0
	var level := get_parent()
	if level:
		for child in level.get_children():
			if child is Checkpoint and child != self and child._is_activated:
				child._is_activated = false
	_particles.restart()
	_particles.emitting = true
	var spawn: Node = null
	var node: Node = get_parent()
	while node:
		spawn = node.get_node_or_null("BallSpawn")
		if spawn:
			break
		node = node.get_parent()
	if spawn and spawn is Marker2D:
		spawn.global_position = global_position + Vector2(0, 10)
	if AudioManager:
		AudioManager.play_sfx("checkpoint")
	checkpoint_activated.emit(global_position)

func _draw() -> void:
	var base_y := 5.0
	draw_rect(Rect2(Vector2(-6, base_y - 4), Vector2(12, 4)), pole_color.darkened(0.2), true)
	var pole_top := -pole_height
	draw_line(Vector2(0, base_y), Vector2(0, pole_top), pole_color, 3.0)
	draw_circle(Vector2(0, pole_top), 3.0, pole_color.lightened(0.2))
	var flag_color := active_color if _is_activated else inactive_color
	var flag_top := pole_top + 3
	var points := PackedVector2Array()
	points.append(Vector2(0, flag_top))
	points.append(Vector2(flag_size.x * (1.0 + _flag_wave), flag_top + 2))
	points.append(Vector2(flag_size.x * (1.0 + _flag_wave * 0.5), flag_top + flag_size.y - 2))
	points.append(Vector2(0, flag_top + flag_size.y))
	draw_colored_polygon(points, flag_color)
	if _is_activated:
		var hl := Color(1.0, 1.0, 1.0, 0.2)
		draw_line(
			Vector2(2, flag_top + 2),
			Vector2(flag_size.x * 0.6, flag_top + 3),
			hl, 1.5
		)
	if _activation_flash > 0:
		var glow := Color(active_color.r, active_color.g, active_color.b, _activation_flash * 0.3)
		draw_circle(Vector2(0, pole_top + flag_size.y / 2.0), 25.0 * _activation_flash, glow)
	var dot_color := Color(0.3, 1.0, 0.4, 0.8) if _is_activated else Color(0.5, 0.5, 0.5, 0.4)
	draw_circle(Vector2(0, base_y - 1), 2.0, dot_color)

func reset() -> void:
	_is_activated = false
	_activation_flash = 0.0