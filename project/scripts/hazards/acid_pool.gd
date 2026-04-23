extends TrapBase
class_name AcidPool

@export_category("Acid Pool")
@export var pool_size: Vector2 = Vector2(120, 16)
@export var acid_color: Color = Color(0.35, 0.85, 0.15, 0.85)
@export var bubble_rate: float = 3.0
@export var wave_speed: float = 2.5
@export var wave_height: float = 3.0

var _bubbles: Array[Dictionary] = []
var _drip_particles: Array[Dictionary] = []
var _surface_points: PackedVector2Array

func _ready() -> void:
	super._ready()
	trap_type = TrapType.ACID_POOL
	if _collision_shape:
		var shape := RectangleShape2D.new()
		shape.size = pool_size
		_collision_shape.shape = shape
	_surface_points = PackedVector2Array()
	var segments := int(pool_size.x / 6)
	for i in range(segments + 1):
		_surface_points.append(Vector2(
			-pool_size.x / 2.0 + float(i) / segments * pool_size.x,
			-pool_size.y / 2.0
		))

func _process(delta: float) -> void:
	_time_elapsed += delta
	var segments := _surface_points.size()
	for i in range(segments):
		var x_norm: float = float(i) / max(segments - 1, 1)
		var wave := sin(_time_elapsed * wave_speed + x_norm * 8.0) * wave_height
		wave += sin(_time_elapsed * wave_speed * 1.7 + x_norm * 12.0) * wave_height * 0.4
		_surface_points[i].y = -pool_size.y / 2.0 + wave
	if randf() < bubble_rate * delta:
		_bubbles.append({
			"x": randf_range(-pool_size.x * 0.45, pool_size.x * 0.45),
			"y": pool_size.y * 0.3,
			"size": randf_range(2.0, 5.0),
			"speed": randf_range(15, 35),
			"time": 0.0,
			"wobble_offset": randf() * TAU,
		})
	var i := _bubbles.size() - 1
	while i >= 0:
		var b := _bubbles[i]
		b["time"] += delta
		b["y"] -= b["speed"] * delta
		b["x"] += sin(_time_elapsed * 3.0 + b["wobble_offset"]) * 0.5
		if b["y"] <= -pool_size.y * 0.5 - 5:
			for _j in range(3):
				_drip_particles.append({
					"x": b["x"], "y": b["y"],
					"vx": randf_range(-15, 15),
					"vy": randf_range(-20, -5),
					"time": 0.0,
					"size": randf_range(1.0, 2.5),
				})
			_bubbles.remove_at(i)
		i -= 1
	i = _drip_particles.size() - 1
	while i >= 0:
		_drip_particles[i]["time"] += delta
		_drip_particles[i]["x"] += _drip_particles[i]["vx"] * delta
		_drip_particles[i]["y"] += _drip_particles[i]["vy"] * delta
		_drip_particles[i]["vy"] += 60 * delta
		if _drip_particles[i]["time"] > 0.5:
			_drip_particles.remove_at(i)
		i -= 1
	queue_redraw()

func _draw() -> void:
	var hw := pool_size.x / 2.0
	var hh := pool_size.y / 2.0
	var body := PackedVector2Array()
	for pt in _surface_points:
		body.append(pt)
	body.append(Vector2(hw, hh))
	body.append(Vector2(-hw, hh))
	draw_colored_polygon(body, acid_color)
	var highlight_color := Color(0.6, 1.0, 0.3, 0.4)
	for seg_i in range(_surface_points.size() - 1):
		if seg_i % 3 == 0:
			var p1 := _surface_points[seg_i]
			var p2 := _surface_points[min(seg_i + 1, _surface_points.size() - 1)]
			draw_line(p1 + Vector2(0, 1), p2 + Vector2(0, 1), highlight_color, 1.5)
	draw_polyline(_surface_points, acid_color, 2.0)
	for b in _bubbles:
		var alpha := 0.6
		if b["y"] < -hh + 5:
			alpha = 0.3
		var bc := Color(acid_color.r, acid_color.g, acid_color.b, alpha)
		draw_circle(Vector2(b["x"], b["y"]), b["size"], bc)
		draw_arc(Vector2(b["x"] - 1, b["y"] - 1), b["size"] * 0.6, PI * 0.8, PI * 1.6, 6, Color(acid_color.r + 0.3, acid_color.g + 0.3, acid_color.b + 0.3, alpha * 0.5), 1.0)
	for dp in _drip_particles:
		var dp_alpha: float = 1.0 - dp["time"] / 0.5
		draw_circle(Vector2(dp["x"], dp["y"]), dp["size"], Color(acid_color.r, acid_color.g, acid_color.b, dp_alpha))
	var warn_c := Color(0.9, 0.8, 0.1, 0.4 + sin(_time_elapsed * 2.0) * 0.1)
