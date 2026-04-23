extends PlatformBase
class_name CrumblingPlatform

signal platform_crumbled()
signal platform_rebuilt()

@export_category("Crumble Behavior")
@export var crack_delay: float = 0.3
@export var crumble_delay: float = 0.8
@export var fragment_count: int = 6
@export var fragment_speed: float = 150.0
@export var fragment_gravity: float = 500.0
@export var can_respawn: bool = true
@export var respawn_delay: float = 4.0

enum CrumbleState { INTACT, CRACKING, CRUMBLING, DESTROYED, REBUILDING }
var _crumble_state: CrumbleState = CrumbleState.INTACT
var _state_timer: float = 0.0
var _crack_progress: float = 0.0
var _fragments: Array[Dictionary] = []
var _fragment_nodes: Array[ColorRect] = []
var _rebuild_alpha: float = 0.0

func _platform_ready() -> void:
	platform_type = PlatformType.CRUMBLING
	platform_color = Color(0.75, 0.6, 0.45, 1.0)
	outline_color = Color(0.55, 0.4, 0.25, 1.0)
	particle_color = Color(0.8, 0.65, 0.45, 0.7)

func _platform_process(delta: float) -> void:
	match _crumble_state:
		CrumbleState.CRACKING:
			_process_cracking(delta)
		CrumbleState.CRUMBLING:
			_process_crumbling(delta)
		CrumbleState.DESTROYED:
			_process_destroyed(delta)
		CrumbleState.REBUILDING:
			_process_rebuilding(delta)

func _process_cracking(delta: float) -> void:
	_state_timer -= delta
	_crack_progress = 1.0 - (_state_timer / crumble_delay)

	var shake := _crack_progress * 2.5
	position = _original_position + Vector2(
		randf_range(-shake, shake),
		randf_range(-shake * 0.3, shake * 0.3)
	)

	if _state_timer <= 0.0:
		_start_crumbling()

func _start_crumbling() -> void:
	_crumble_state = CrumbleState.CRUMBLING
	_state_timer = 0.5
	_collision_shape.disabled = true
	position = _original_position

	_create_fragments()
	platform_crumbled.emit()

	if _particles:
		_particles.amount = 16
		_particles.initial_velocity_min = 60.0
		_particles.initial_velocity_max = 150.0
		_particles.spread = 180.0
		_particles.restart()
		_particles.emitting = true

func _create_fragments() -> void:

	for fnode in _fragment_nodes:
		fnode.queue_free()
	_fragment_nodes.clear()
	_fragments.clear()

	var half := platform_size / 2.0
	var frag_w := platform_size.x / float(fragment_count)
	var frag_h := platform_size.y

	for i in range(fragment_count):
		var frag_rect := ColorRect.new()
		frag_rect.size = Vector2(frag_w - 2, frag_h)
		frag_rect.color = platform_color.darkened(randf_range(0.0, 0.15))
		frag_rect.position = Vector2(-half.x + i * frag_w, -half.y)
		frag_rect.pivot_offset = frag_rect.size / 2.0
		frag_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(frag_rect)
		_fragment_nodes.append(frag_rect)

		_fragments.append({
			"velocity": Vector2(
				randf_range(-fragment_speed, fragment_speed),
				randf_range(-fragment_speed * 1.5, -fragment_speed * 0.3)
			),
			"rotation_speed": randf_range(-8.0, 8.0),
			"alpha": 1.0,
		})

func _process_crumbling(delta: float) -> void:
	_state_timer -= delta

	for i in range(_fragment_nodes.size()):
		var fnode: ColorRect = _fragment_nodes[i]
		var fdata: Dictionary = _fragments[i]

		fdata["velocity"] = fdata["velocity"] as Vector2 + Vector2(0, fragment_gravity * delta)
		fnode.position += (fdata["velocity"] as Vector2) * delta
		fnode.rotation += (fdata["rotation_speed"] as float) * delta
		fdata["alpha"] = maxf(0.0, (fdata["alpha"] as float) - delta * 1.5)
		fnode.modulate.a = fdata["alpha"] as float

	if _state_timer <= 0.0:
		_finish_crumbling()

func _finish_crumbling() -> void:
	_crumble_state = CrumbleState.DESTROYED

	for fnode in _fragment_nodes:
		fnode.queue_free()
	_fragment_nodes.clear()
	_fragments.clear()

	visible = false

	if can_respawn:
		_state_timer = respawn_delay

func _process_destroyed(delta: float) -> void:
	if not can_respawn:
		return
	_state_timer -= delta
	if _state_timer <= 0.0:
		_start_rebuilding()

func _start_rebuilding() -> void:
	_crumble_state = CrumbleState.REBUILDING
	_rebuild_alpha = 0.0
	visible = true
	position = _original_position
	modulate.a = 0.0

func _process_rebuilding(delta: float) -> void:
	_rebuild_alpha += delta / 0.6

	var pulse := _rebuild_alpha * (0.8 + sin(_rebuild_alpha * PI * 4) * 0.2)
	modulate.a = clampf(pulse, 0.0, 1.0)

	if _rebuild_alpha >= 1.0:
		_crumble_state = CrumbleState.INTACT
		_collision_shape.disabled = false
		_crack_progress = 0.0
		modulate.a = 1.0
		platform_rebuilt.emit()

func _on_ball_landed(_ball: RigidBody2D) -> void:
	if _crumble_state == CrumbleState.INTACT:
		_crumble_state = CrumbleState.CRACKING
		_state_timer = crumble_delay

func _draw_platform_details(rect: Rect2) -> void:
	if _crumble_state == CrumbleState.INTACT or _crumble_state == CrumbleState.CRACKING:
		_draw_cracks(rect)
	if _crumble_state == CrumbleState.REBUILDING:
		_draw_rebuild_effect(rect)

func _draw_cracks(rect: Rect2) -> void:
	var crack_alpha := 0.2 + _crack_progress * 0.6
	var cc := Color(0.3, 0.2, 0.1, crack_alpha)

	var cx := rect.position.x + rect.size.x * 0.25
	draw_line(
		Vector2(cx, rect.position.y), Vector2(cx + 5, rect.position.y + rect.size.y),
		cc, 1.0
	)
	cx = rect.position.x + rect.size.x * 0.6
	draw_line(
		Vector2(cx, rect.position.y + 2), Vector2(cx - 3, rect.position.y + rect.size.y - 2),
		cc, 1.0
	)

	if _crack_progress > 0.3:
		cx = rect.position.x + rect.size.x * 0.45
		draw_line(
			Vector2(cx, rect.position.y), Vector2(cx + 8, rect.position.y + rect.size.y),
			cc, 1.5
		)
	if _crack_progress > 0.6:
		cx = rect.position.x + rect.size.x * 0.8
		draw_line(
			Vector2(cx, rect.position.y + 3), Vector2(cx - 4, rect.position.y + rect.size.y),
			cc, 1.5
		)

		draw_rect(
			Rect2(rect.position + Vector2(rect.size.x * 0.15, 1), Vector2(4, 3)),
			cc, true
		)

func _draw_rebuild_effect(rect: Rect2) -> void:

	var glow_a := 0.3 + sin(_time_elapsed * 6.0) * 0.2
	var glow := Color(0.9, 0.7, 0.4, glow_a)
	draw_rect(
		Rect2(rect.position - Vector2(2, 2), rect.size + Vector2(4, 4)),
		glow, false, 2.0
	)

func reset() -> void:
	_crumble_state = CrumbleState.INTACT
	position = _original_position
	visible = true
	modulate.a = 1.0
	_collision_shape.disabled = false
	_crack_progress = 0.0
	for fnode in _fragment_nodes:
		fnode.queue_free()
	_fragment_nodes.clear()
	_fragments.clear()
