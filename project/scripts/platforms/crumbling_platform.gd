extends PlatformBase
class_name CrumblingPlatform

signal platform_crumbled()
signal platform_rebuilt()

@export_category("Crumble Behavior")
@export var crack_delay: float = 0.3
@export var crumble_delay: float = 0.8
@export var fragment_count: int = 8
@export var fragment_speed: float = 180.0
@export var fragment_gravity: float = 600.0
@export var can_respawn: bool = true
@export var respawn_delay: float = 4.0

enum CrumbleState { INTACT, CRACKING, CRUMBLING, DESTROYED, REBUILDING }
var _crumble_state: CrumbleState = CrumbleState.INTACT
var _state_timer: float = 0.0
var _crack_progress: float = 0.0
var _fragments: Array[Dictionary] = []
var _fragment_nodes: Array[ColorRect] = []
var _rebuild_alpha: float = 0.0
var _dust_particles: CPUParticles2D

func _platform_ready() -> void:
	platform_type = PlatformType.CRUMBLING
	platform_color = Color(0.65, 0.55, 0.45, 1.0)
	outline_color = Color(0.45, 0.35, 0.25, 1.0)
	particle_color = Color(0.7, 0.6, 0.5, 0.6)
	glow_intensity = 0.15
	glow_color = Color(0.9, 0.7, 0.3, 0.3)
	_setup_dust_particles()

func _setup_dust_particles() -> void:
	_dust_particles = CPUParticles2D.new()
	_dust_particles.emitting = false
	_dust_particles.one_shot = true
	_dust_particles.amount = 20
	_dust_particles.lifetime = 0.8
	_dust_particles.direction = Vector2(0, -1)
	_dust_particles.spread = 180.0
	_dust_particles.gravity = Vector2(0, 100)
	_dust_particles.initial_velocity_min = 20.0
	_dust_particles.initial_velocity_max = 80.0
	_dust_particles.scale_amount_min = 2.0
	_dust_particles.scale_amount_max = 5.0
	_dust_particles.color = Color(0.6, 0.5, 0.4, 0.5)
	_dust_particles.position = Vector2(0, -platform_size.y / 2.0)
	add_child(_dust_particles)

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

	var shake := _crack_progress * 3.0
	position = _original_position + Vector2(
		randf_range(-shake, shake),
		randf_range(-shake * 0.4, shake * 0.4)
	)

	glow_intensity = _crack_progress * 0.4

	if _state_timer <= 0.0:
		_start_crumbling()

func _start_crumbling() -> void:
	_crumble_state = CrumbleState.CRUMBLING
	_state_timer = 0.6
	_collision_shape.disabled = true
	visible = false
	position = _original_position

	_create_fragments()
	_emit_dust_cloud()
	platform_crumbled.emit()

	if _particles:
		_particles.amount = 24
		_particles.initial_velocity_min = 80.0
		_particles.initial_velocity_max = 200.0
		_particles.spread = 200.0
		_particles.restart()
		_particles.emitting = true

func _emit_dust_cloud() -> void:
	if _dust_particles:
		_dust_particles.restart()
		_dust_particles.emitting = true

func _create_fragments() -> void:
	for fnode in _fragment_nodes:
		fnode.queue_free()
	_fragment_nodes.clear()
	_fragments.clear()

	var half := platform_size / 2.0
	var frag_w := platform_size.x / float(fragment_count)
	var frag_h := platform_size.y

	var center_i := fragment_count / 2

	for i in range(fragment_count):
		var frag_rect := ColorRect.new()
		frag_rect.size = Vector2(frag_w - 3, frag_h - 2)
		var shade := randf_range(0.0, 0.2)
		frag_rect.color = platform_color.darkened(shade)
		var x_offset := -half.x + i * frag_w + frag_w / 2.0
		var y_offset := -half.y + 1.0
		frag_rect.position = Vector2(x_offset - (frag_w - 3) / 2.0, y_offset)
		frag_rect.pivot_offset = Vector2((frag_w - 3) / 2.0, (frag_h - 2) / 2.0)
		frag_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(frag_rect)
		_fragment_nodes.append(frag_rect)

		var x_vel := randf_range(-fragment_speed, fragment_speed) * 0.7
		if i < center_i:
			x_vel -= randf_range(50, 100)
		else:
			x_vel += randf_range(50, 100)
		_fragments.append({
			"velocity": Vector2(x_vel, randf_range(-fragment_speed * 1.8, -fragment_speed * 0.5)),
			"rotation_speed": randf_range(-10.0, 10.0),
			"alpha": 1.0,
		})

func _process_crumbling(delta: float) -> void:
	_state_timer -= delta

	for i in range(_fragment_nodes.size()):
		var fnode: ColorRect = _fragment_nodes[i]
		var fdata: Dictionary = _fragments[i]

		fdata["velocity"] = (fdata["velocity"] as Vector2) + Vector2(0, fragment_gravity * delta)
		fnode.position += (fdata["velocity"] as Vector2) * delta
		fnode.rotation += (fdata["rotation_speed"] as float) * delta

		var alpha_decay := delta * 1.2
		fdata["alpha"] = maxf(0.0, (fdata["alpha"] as float) - alpha_decay)
		fnode.modulate.a = fdata["alpha"] as float

		var scale := 1.0 + (1.0 - (fdata["alpha"] as float)) * 0.3
		fnode.scale = Vector2(scale, scale)

	if _state_timer <= 0.0:
		_finish_crumbling()

func _finish_crumbling() -> void:
	_crumble_state = CrumbleState.DESTROYED

	for fnode in _fragment_nodes:
		fnode.queue_free()
	_fragment_nodes.clear()
	_fragments.clear()

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
	glow_intensity = 0.5

func _process_rebuilding(delta: float) -> void:
	_rebuild_alpha += delta / 0.6

	var pulse := _rebuild_alpha * (0.7 + sin(_rebuild_alpha * PI * 5) * 0.3)
	modulate.a = clampf(pulse, 0.0, 1.0)

	glow_intensity = (1.0 - _rebuild_alpha) * 0.5

	if _rebuild_alpha >= 1.0:
		_crumble_state = CrumbleState.INTACT
		_collision_shape.disabled = false
		_crack_progress = 0.0
		modulate.a = 1.0
		glow_intensity = 0.15
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
	var crack_alpha := 0.25 + _crack_progress * 0.65
	var cc := Color(0.25, 0.15, 0.08, crack_alpha)

	var main_crack_x := rect.position.x + rect.size.x * 0.5
	var main_crack_segments := 5
	var seg_height := rect.size.y / main_crack_segments
	for s in range(main_crack_segments):
		var y1 := rect.position.y + s * seg_height
		var y2 := rect.position.y + (s + 1) * seg_height
		var x_off := randf_range(-3, 3) if s > 0 else 0.0
		draw_line(
			Vector2(main_crack_x + x_off, y1),
			Vector2(main_crack_x + x_off + randf_range(-2, 2), y2),
			cc, 1.5 + _crack_progress * 0.5
		)

	if _crack_progress > 0.2:
		var cx := rect.position.x + rect.size.x * 0.25
		draw_line(
			Vector2(cx, rect.position.y + 1),
			Vector2(cx - 4 + randf_range(-2, 2), rect.position.y + rect.size.y * 0.4),
			cc, 1.0 + _crack_progress * 0.5
		)
		draw_line(
			Vector2(cx - 4, rect.position.y + rect.size.y * 0.4),
			Vector2(cx + 3, rect.position.y + rect.size.y * 0.7),
			cc, 1.0
		)

	if _crack_progress > 0.4:
		var cx2 := rect.position.x + rect.size.x * 0.75
		draw_line(
			Vector2(cx2, rect.position.y + 2),
			Vector2(cx2 + 2 + randf_range(-2, 2), rect.position.y + rect.size.y * 0.5),
			cc, 1.0 + _crack_progress * 0.5
		)
		draw_line(
			Vector2(cx2 + 2, rect.position.y + rect.size.y * 0.5),
			Vector2(cx2 - 3, rect.position.y + rect.size.y - 1),
			cc, 1.0
		)

	if _crack_progress > 0.6:
		var y_mid := rect.position.y + rect.size.y * 0.5
		draw_line(
			Vector2(rect.position.x + 3, y_mid),
			Vector2(rect.position.x + rect.size.x * 0.35, y_mid + randf_range(-2, 2)),
			cc, 1.5
		)
		draw_line(
			Vector2(rect.position.x + rect.size.x * 0.65, y_mid),
			Vector2(rect.position.x + rect.size.x - 3, y_mid + randf_range(-2, 2)),
			cc, 1.5
		)

		draw_rect(
			Rect2(rect.position + Vector2(rect.size.x * 0.15, 2), Vector2(5, 4)),
			cc, true
		)
		draw_rect(
			Rect2(rect.position + Vector2(rect.size.x * 0.8, rect.size.y - 6), Vector2(4, 4)),
			cc, true
		)

	if _crack_progress > 0.8:
		var edge_cc := Color(cc.r, cc.g, cc.b, crack_alpha * 0.7)
		draw_rect(
			Rect2(rect.position + Vector2(1, 1), Vector2(3, 3)),
			edge_cc, true
		)
		draw_rect(
			Rect2(rect.position + Vector2(rect.size.x - 4, rect.size.y - 4), Vector2(3, 3)),
			edge_cc, true
		)

func _draw_rebuild_effect(rect: Rect2) -> void:
	var glow_a := 0.4 + sin(_time_elapsed * 8.0) * 0.25
	var glow := Color(0.95, 0.75, 0.4, glow_a)
	draw_rect(
		Rect2(rect.position - Vector2(3, 3), rect.size + Vector2(6, 6)),
		glow, false, 2.5
	)
	draw_rect(
		Rect2(rect.position - Vector2(1, 1), rect.size + Vector2(2, 2)),
		Color(glow.r, glow.g, glow.b, glow_a * 0.5), false, 1.0
	)

func reset() -> void:
	_crumble_state = CrumbleState.INTACT
	position = _original_position
	visible = true
	modulate.a = 1.0
	_collision_shape.disabled = false
	_crack_progress = 0.0
	glow_intensity = 0.15
	for fnode in _fragment_nodes:
		fnode.queue_free()
	_fragment_nodes.clear()
	_fragments.clear()
