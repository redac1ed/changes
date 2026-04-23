extends Camera2D
class_name GameCamera

signal camera_shake_started(intensity: float)
signal camera_shake_ended
signal zoom_changed(new_zoom: Vector2)
signal cinematic_started
signal cinematic_ended

enum ShakeType { RANDOM, HORIZONTAL, VERTICAL, CIRCULAR, PERLIN }
enum CameraMode { FOLLOW, CINEMATIC, STATIC, LOOK_AT }

@export_group("Target")
@export var target_path: NodePath
@export var smooth_speed: float = 5.0
@export var follow_mode: CameraMode = CameraMode.FOLLOW
@export_group("Look Ahead")
@export var look_ahead_factor: float = 0.15
@export var look_ahead_smoothing: float = 3.0
@export var look_ahead_max: float = 80.0
@export_group("Dead Zone")
@export var use_dead_zone: bool = true
@export var dead_zone_size: Vector2 = Vector2(40, 30)
@export_group("Limits")
@export var use_limits: bool = true
@export var world_bounds: Rect2 = Rect2(0, 0, 1200, 800)
@export var center_if_undersized: bool = true
@export_group("Shake")
@export var shake_enabled: bool = true
@export var shake_decay: float = 8.0
@export var max_shake_offset: Vector2 = Vector2(25, 25)
@export var default_shake_type: ShakeType = ShakeType.RANDOM
@export_group("Zoom")
@export var default_zoom: Vector2 = Vector2(1.0, 1.0)
@export var zoom_smooth_speed: float = 3.0
@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.0

var _target_node: Node2D
var _shake_strength: float = 0.0
var _shake_type: ShakeType = ShakeType.RANDOM
var _shake_time: float = 0.0
var _current_look_ahead: Vector2 = Vector2.ZERO
var _is_first_frame: bool = true
var _target_zoom: Vector2 = Vector2(1.0, 1.0)
var _cinematic_queue: Array[Dictionary] = []
var _cinematic_active: bool = false
var _cinematic_index: int = 0
var _cinematic_timer: float = 0.0
var _cinematic_start_pos: Vector2
var _focus_points: Array[Vector2] = []
var _trauma: float = 0.0
var _perlin_x: float = 0.0
var _perlin_y: float = 0.0

func _ready() -> void:
	if target_path:
		_target_node = get_node_or_null(target_path)
	if not _target_node:
		var ball := _find_ball()
		if ball:
			_target_node = ball
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	position_smoothing_enabled = false
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	_target_zoom = default_zoom
	zoom = default_zoom
	_try_connect_signals()
	if use_limits:
		limit_left = -10000000
		limit_top = -10000000
		limit_right = 10000000
		limit_bottom = 10000000
	if _target_node:
		global_position = _target_node.global_position
		align()

func _process(delta: float) -> void:
	if _shake_strength > 0 or _trauma > 0:
		_process_shake(delta)
	else:
		offset = Vector2.ZERO
	if zoom.distance_to(_target_zoom) > 0.01:
		zoom = zoom.lerp(_target_zoom, zoom_smooth_speed * delta)
		zoom_changed.emit(zoom)

func _physics_process(delta: float) -> void:
	if _cinematic_active:
		_process_cinematic(delta)
		_constrain_to_limits()
		return
	if follow_mode == CameraMode.STATIC:
		return
	if not is_instance_valid(_target_node):
		_target_node = _find_ball()
		if not _target_node:
			return
	var target_pos := _calculate_target_position(delta)
	if _is_first_frame:
		global_position = target_pos
		_is_first_frame = false
	else:
		if use_dead_zone:
			target_pos = _apply_dead_zone(target_pos)
		global_position = global_position.lerp(target_pos, smooth_speed * delta)
	_constrain_to_limits()
	_check_ball_escape()

func add_trauma(amount: float) -> void:
	_trauma = min(_trauma + amount, 1.0)

func shake(intensity: float = 0.5, type: ShakeType = ShakeType.RANDOM) -> void:
	if not shake_enabled:
		return
	_shake_strength = intensity
	_shake_type = type
	_shake_time = 0.0
	camera_shake_started.emit(intensity)

func _process_shake(delta: float) -> void:
	_shake_time += delta
	_shake_strength = move_toward(_shake_strength, 0.0, shake_decay * delta)
	_trauma = move_toward(_trauma, 0.0, delta * 1.5)
	var intensity: float = max(_shake_strength, _trauma * _trauma)
	if intensity <= 0.001:
		offset = Vector2.ZERO
		camera_shake_ended.emit()
		return
	match _shake_type:
		ShakeType.RANDOM:
			offset = Vector2(
				randf_range(-1, 1) * max_shake_offset.x * intensity,
				randf_range(-1, 1) * max_shake_offset.y * intensity
			)
		ShakeType.HORIZONTAL:
			offset = Vector2(
				randf_range(-1, 1) * max_shake_offset.x * intensity,
				0
			)
		ShakeType.VERTICAL:
			offset = Vector2(
				0,
				randf_range(-1, 1) * max_shake_offset.y * intensity
			)
		ShakeType.CIRCULAR:
			var angle := _shake_time * 30.0
			offset = Vector2(
				cos(angle) * max_shake_offset.x * intensity,
				sin(angle) * max_shake_offset.y * intensity
			)
		ShakeType.PERLIN:
			_perlin_x += delta * 12.0
			_perlin_y += delta * 15.0
			offset = Vector2(
				sin(_perlin_x * 1.3 + cos(_perlin_x * 0.7)) * max_shake_offset.x * intensity,
				cos(_perlin_y * 1.1 + sin(_perlin_y * 0.9)) * max_shake_offset.y * intensity
			)

func set_target_zoom(new_zoom: float) -> void:
	_target_zoom = Vector2(
		clamp(new_zoom, min_zoom, max_zoom),
		clamp(new_zoom, min_zoom, max_zoom)
	)

func zoom_in(amount: float = 0.1) -> void:
	set_target_zoom(_target_zoom.x + amount)

func zoom_out(amount: float = 0.1) -> void:
	set_target_zoom(_target_zoom.x - amount)

func reset_zoom() -> void:
	_target_zoom = default_zoom

func punch_zoom(intensity: float = 0.1, duration: float = 0.3) -> void:
	var original := _target_zoom
	_target_zoom = original + Vector2(intensity, intensity)
	var tw := create_tween()
	tw.tween_property(self, "_target_zoom", original, duration)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

func start_cinematic(points: Array[Dictionary]) -> void:
	_cinematic_queue = points
	_cinematic_index = 0
	_cinematic_timer = 0.0
	_cinematic_active = true
	_cinematic_start_pos = global_position
	cinematic_started.emit()

func stop_cinematic() -> void:
	_cinematic_active = false
	_cinematic_queue.clear()
	cinematic_ended.emit()

func _process_cinematic(delta: float) -> void:
	if _cinematic_index >= _cinematic_queue.size():
		stop_cinematic()
		return
	var point: Dictionary = _cinematic_queue[_cinematic_index]
	var target_pos: Vector2 = point.get("position", global_position)
	var target_z: float = point.get("zoom", 1.0)
	var duration: float = point.get("duration", 1.0)
	_cinematic_timer += delta
	var t: float = min(_cinematic_timer / duration, 1.0)
	t = _ease_in_out_cubic(t)
	global_position = _cinematic_start_pos.lerp(target_pos, t)
	_target_zoom = Vector2(target_z, target_z)
	if _cinematic_timer >= duration:
		_cinematic_start_pos = target_pos
		_cinematic_index += 1
		_cinematic_timer = 0.0

func add_focus_point(point: Vector2) -> void:
	_focus_points.append(point)

func remove_focus_point(point: Vector2) -> void:
	_focus_points.erase(point)

func clear_focus_points() -> void:
	_focus_points.clear()

func _calculate_target_position(delta: float) -> Vector2:
	var target_pos := _target_node.global_position
	var look_vec := Vector2.ZERO
	if _target_node is RigidBody2D:
		look_vec = _target_node.linear_velocity * look_ahead_factor
		look_vec = look_vec.limit_length(look_ahead_max)
	_current_look_ahead = _current_look_ahead.lerp(look_vec, look_ahead_smoothing * delta)
	target_pos += _current_look_ahead
	if not _focus_points.is_empty():
		var avg := target_pos
		for fp in _focus_points:
			avg += fp
		avg /= _focus_points.size() + 1
		target_pos = target_pos.lerp(avg, 0.3)
	return target_pos

func _apply_dead_zone(target_pos: Vector2) -> Vector2:
	var diff := target_pos - global_position
	var result := global_position
	if abs(diff.x) > dead_zone_size.x:
		result.x += diff.x - sign(diff.x) * dead_zone_size.x
	if abs(diff.y) > dead_zone_size.y:
		result.y += diff.y - sign(diff.y) * dead_zone_size.y
	return result

func _constrain_to_limits() -> void:
	if not use_limits:
		return
	var vp := get_viewport_rect()
	var visible := vp.size / zoom
	var final := global_position
	if world_bounds.size.x <= visible.x and center_if_undersized:
		final.x = world_bounds.position.x + world_bounds.size.x * 0.5
	else:
		final.x = clampf(final.x,
			world_bounds.position.x + visible.x * 0.5,
			world_bounds.end.x - visible.x * 0.5)
	if world_bounds.size.y <= visible.y and center_if_undersized:
		final.y = world_bounds.position.y + world_bounds.size.y * 0.5
	else:
		final.y = clampf(final.y,
			world_bounds.position.y + visible.y * 0.5,
			world_bounds.end.y - visible.y * 0.5)
	global_position = final

func _check_ball_escape() -> void:
	if not _target_node:
		return
	var pos := _target_node.global_position
	var margin := 300.0
	var out := pos.y > world_bounds.end.y + margin \
		or pos.y < world_bounds.position.y - margin \
		or pos.x > world_bounds.end.x + margin \
		or pos.x < world_bounds.position.x - margin
	if out:
		var spawn := _find_spawn()
		if spawn:
			_target_node.global_position = spawn.global_position
			_target_node.linear_velocity = Vector2.ZERO
			_target_node.angular_velocity = 0.0
			add_trauma(0.4)

func _find_ball() -> Node2D:
	var p := get_parent()
	if p:
		var ball := p.get_node_or_null("Ball")
		if ball:
			_try_connect_signals()
			return ball
	return null

func _find_spawn() -> Node2D:
	var node := get_parent()
	while node:
		var spawn := node.get_node_or_null("BallSpawn")
		if spawn:
			return spawn
		node = node.get_parent()
	return null

func _try_connect_signals() -> void:
	if _target_node and _target_node.has_signal("impact_occurred"):
		if not _target_node.is_connected("impact_occurred", _on_impact):
			_target_node.impact_occurred.connect(_on_impact)
	if _target_node and _target_node.has_signal("shot_fired"):
		if not _target_node.is_connected("shot_fired", _on_shot):
			_target_node.shot_fired.connect(_on_shot)

func _on_impact(strength: float) -> void:
	var intensity := clampf(strength / 800.0, 0.0, 1.0)
	add_trauma(intensity * 0.5)

func _on_shot(_count: int) -> void:
	punch_zoom(0.05, 0.2)

func _ease_in_out_cubic(t: float) -> float:
	if t < 0.5:
		return 4.0 * t * t * t
	else:
		return 1.0 - pow(-2.0 * t + 2.0, 3) / 2.0
