extends CanvasLayer
class_name SceneTransitionFX

const SCREEN_W := 1200.0
const SCREEN_H := 800.0

signal transition_midpoint
signal transition_finished

enum TransitionType {
	FADE,
	CIRCLE_WIPE,
	DIAMOND_WIPE,
	HORIZONTAL_SLIDE,
	VERTICAL_SLIDE,
	PIXELATE,
	CURTAIN,
	DIAGONAL_WIPE,
}

@export var default_type: TransitionType = TransitionType.FADE
@export var default_duration: float = 0.8
@export var transition_color: Color = Color(0.02, 0.02, 0.06)

var _active: bool = false
var _type: TransitionType = TransitionType.FADE
var _progress: float = 0.0
var _duration: float = 0.8
var _half_reached: bool = false
var _callback: Callable

var _draw_node: Control
var _pixel_grid: Array[float] = []

func _ready() -> void:
	layer = 50

	_draw_node = Control.new()
	_draw_node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_node.draw.connect(_on_draw)
	_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_draw_node)

	for i in range(600):
		_pixel_grid.append(randf())

func play(type: TransitionType = default_type, duration: float = -1, callback: Callable = Callable()) -> void:
	_type = type
	_duration = duration if duration > 0 else default_duration
	_progress = 0.0
	_half_reached = false
	_active = true
	_callback = callback
	_draw_node.mouse_filter = Control.MOUSE_FILTER_STOP

func play_in(type: TransitionType = default_type, duration: float = -1) -> void:
	_type = type
	_duration = (duration if duration > 0 else default_duration) * 2.0
	_progress = 0.0
	_half_reached = false
	_active = true
	_draw_node.mouse_filter = Control.MOUSE_FILTER_STOP

func play_out(type: TransitionType = default_type, duration: float = -1) -> void:
	_type = type
	_duration = (duration if duration > 0 else default_duration) * 2.0
	_progress = 1.0
	_half_reached = true
	_active = true
	_draw_node.mouse_filter = Control.MOUSE_FILTER_STOP

func _process(delta: float) -> void:
	if not _active:
		return

	_progress += delta / (_duration / 2.0)

	if _progress >= 1.0 and not _half_reached:
		_half_reached = true
		transition_midpoint.emit()
		if _callback.is_valid():
			_callback.call()

	if _progress >= 2.0:
		_active = false
		_progress = 2.0
		_draw_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		transition_finished.emit()

	_draw_node.queue_redraw()

func _on_draw() -> void:
	if not _active and _progress >= 2.0:
		return

	var coverage: float
	if _progress <= 1.0:
		coverage = _ease_in_out(_progress)
	else:
		coverage = _ease_in_out(2.0 - _progress)

	match _type:
		TransitionType.FADE:
			_draw_fade(coverage)
		TransitionType.CIRCLE_WIPE:
			_draw_circle_wipe(coverage)
		TransitionType.DIAMOND_WIPE:
			_draw_diamond_wipe(coverage)
		TransitionType.HORIZONTAL_SLIDE:
			_draw_horizontal_slide(coverage)
		TransitionType.VERTICAL_SLIDE:
			_draw_vertical_slide(coverage)
		TransitionType.PIXELATE:
			_draw_pixelate(coverage)
		TransitionType.CURTAIN:
			_draw_curtain(coverage)
		TransitionType.DIAGONAL_WIPE:
			_draw_diagonal_wipe(coverage)

func _draw_fade(coverage: float) -> void:
	var c := transition_color
	c.a = coverage
	_draw_node.draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), c, true)

func _draw_circle_wipe(coverage: float) -> void:

	var max_radius: float = Vector2(SCREEN_W, SCREEN_H).length() * 0.6
	var radius: float = max_radius * (1.0 - coverage)
	var cx: float = SCREEN_W / 2.0
	var cy: float = SCREEN_H / 2.0

	var c: Color = transition_color

	if coverage >= 0.99:
		_draw_node.draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), c, true)
		return

	var segments: int = 48
	for i in range(segments):
		var angle: float = float(i) / segments * TAU
		var next_angle: float = float(i + 1) / segments * TAU

		var inner_r: float = max(radius, 0)
		var outer_r: float = max_radius * 1.5

		var pts: PackedVector2Array = PackedVector2Array()
		pts.append(Vector2(cx + cos(angle) * inner_r, cy + sin(angle) * inner_r))
		pts.append(Vector2(cx + cos(next_angle) * inner_r, cy + sin(next_angle) * inner_r))
		pts.append(Vector2(cx + cos(next_angle) * outer_r, cy + sin(next_angle) * outer_r))
		pts.append(Vector2(cx + cos(angle) * outer_r, cy + sin(angle) * outer_r))

		_draw_node.draw_colored_polygon(pts, c)

func _draw_diamond_wipe(coverage: float) -> void:
	var max_size := SCREEN_W + SCREEN_H
	var size := max_size * coverage
	var cx := SCREEN_W / 2.0
	var cy := SCREEN_H / 2.0

	if coverage >= 0.99:
		_draw_node.draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), transition_color, true)
		return

	if coverage > 0:
		var diamond := PackedVector2Array()
		diamond.append(Vector2(cx, cy - size * 0.5))
		diamond.append(Vector2(cx + size * 0.5, cy))
		diamond.append(Vector2(cx, cy + size * 0.5))
		diamond.append(Vector2(cx - size * 0.5, cy))
		_draw_node.draw_colored_polygon(diamond, transition_color)

func _draw_horizontal_slide(coverage: float) -> void:
	var w := SCREEN_W * coverage
	_draw_node.draw_rect(Rect2(0, 0, w, SCREEN_H), transition_color, true)

	if coverage > 0 and coverage < 1:
		var edge_x := w
		for i in range(5):
			var alpha := 0.3 * (1.0 - float(i) / 5)
			_draw_node.draw_line(
				Vector2(edge_x + i * 2, 0),
				Vector2(edge_x + i * 2, SCREEN_H),
				Color(0.3, 0.45, 0.7, alpha), 2.0
			)

func _draw_vertical_slide(coverage: float) -> void:
	var h := SCREEN_H * coverage
	_draw_node.draw_rect(Rect2(0, 0, SCREEN_W, h), transition_color, true)

	if coverage > 0 and coverage < 1:
		var edge_y := h
		for i in range(5):
			var alpha := 0.3 * (1.0 - float(i) / 5)
			_draw_node.draw_line(
				Vector2(0, edge_y + i * 2),
				Vector2(SCREEN_W, edge_y + i * 2),
				Color(0.3, 0.45, 0.7, alpha), 2.0
			)

func _draw_pixelate(coverage: float) -> void:
	if coverage <= 0:
		return

	var cell_size: int = max(int(32 * (1.0 - coverage * 0.8)), 4)
	var cols: int = int(SCREEN_W / cell_size) + 1
	var rows: int = int(SCREEN_H / cell_size) + 1

	for row in range(min(rows, 50)):
		for col in range(min(cols, 75)):
			var idx: int = (row * 30 + col) % _pixel_grid.size()
			var threshold: float = _pixel_grid[idx]

			if coverage > threshold:
				var x: float = col * cell_size
				var y: float = row * cell_size
				_draw_node.draw_rect(
					Rect2(x, y, cell_size, cell_size),
					transition_color, true
				)

func _draw_curtain(coverage: float) -> void:

	var hw: float = SCREEN_W * coverage * 0.5
	_draw_node.draw_rect(Rect2(0, 0, hw, SCREEN_H), transition_color, true)
	_draw_node.draw_rect(Rect2(SCREEN_W - hw, 0, hw, SCREEN_H), transition_color, true)

	if hw > 0 and hw < SCREEN_W * 0.5:
		for i in range(3):
			var alpha: float = 0.2 * (1.0 - float(i) / 3)
			_draw_node.draw_line(
				Vector2(hw + i, 0), Vector2(hw + i, SCREEN_H),
				Color(0.2, 0.3, 0.5, alpha), 1.0
			)
			_draw_node.draw_line(
				Vector2(SCREEN_W - hw - i, 0), Vector2(SCREEN_W - hw - i, SCREEN_H),
				Color(0.2, 0.3, 0.5, alpha), 1.0
			)

func _draw_diagonal_wipe(coverage: float) -> void:
	if coverage <= 0:
		return

	var diag: float = (SCREEN_W + SCREEN_H) * coverage
	var pts: PackedVector2Array = PackedVector2Array()

	if diag <= SCREEN_W:
		pts.append(Vector2(0, 0))
		pts.append(Vector2(diag, 0))
		pts.append(Vector2(0, diag))
	elif diag <= SCREEN_H:
		pts.append(Vector2(0, 0))
		pts.append(Vector2(SCREEN_W, 0))
		pts.append(Vector2(SCREEN_W, diag - SCREEN_W))
		pts.append(Vector2(0, diag))
	else:
		pts.append(Vector2(0, 0))
		pts.append(Vector2(SCREEN_W, 0))
		pts.append(Vector2(SCREEN_W, SCREEN_H))
		if coverage < 1.0:
			pts.append(Vector2(diag - SCREEN_H, SCREEN_H))
			var left_y: float = min(diag, SCREEN_H)
			pts.append(Vector2(0, left_y))
		else:
			pts.append(Vector2(0, SCREEN_H))

	if pts.size() >= 3:
		_draw_node.draw_colored_polygon(pts, transition_color)

func _ease_in_out(t: float) -> float:
	if t < 0.5:
		return 2.0 * t * t
	else:
		return 1.0 - pow(-2.0 * t + 2.0, 2) / 2.0

func fade_to_scene(scene_path: String, duration: float = 0.8) -> void:
	play(TransitionType.FADE, duration, func():
		get_tree().change_scene_to_file(scene_path)
	)

func circle_wipe_to_scene(scene_path: String, duration: float = 1.0) -> void:
	play(TransitionType.CIRCLE_WIPE, duration, func():
		get_tree().change_scene_to_file(scene_path)
	)

func random_transition_to_scene(scene_path: String, duration: float = 0.8) -> void:
	var types := [
		TransitionType.FADE,
		TransitionType.CIRCLE_WIPE,
		TransitionType.DIAMOND_WIPE,
		TransitionType.HORIZONTAL_SLIDE,
		TransitionType.CURTAIN,
		TransitionType.DIAGONAL_WIPE,
	]
	var chosen: TransitionType = types[randi() % types.size()]
	play(chosen, duration, func():
		get_tree().change_scene_to_file(scene_path)
	)
