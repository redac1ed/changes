extends ParallaxBackground
class_name ParallaxDecoration

enum ParallaxTheme {
	MEADOW,
	VOLCANO,
	SKY,
	OCEAN,
	SPACE,
	CITY,
}

@export var theme: ParallaxTheme = ParallaxTheme.MEADOW
@export var layer_count: int = 4
@export var auto_scroll: bool = false
@export var auto_scroll_speed: float = 10.0

var _layers: Array[ParallaxLayer] = []
var _time: float = 0.0
var _seed_value: int = 0


func _ready() -> void:
	_seed_value = randi()
	_build_layers()


func _process(delta: float) -> void:
	_time += delta
	if auto_scroll:
		scroll_offset.x -= auto_scroll_speed * delta


func _build_layers() -> void:
	# Clear existing
	for child in get_children():
		if child is ParallaxLayer:
			child.queue_free()
	_layers.clear()
	
	match theme:
		ParallaxTheme.MEADOW: _build_meadow()
		ParallaxTheme.VOLCANO: _build_volcano()
		ParallaxTheme.SKY: _build_sky()
		ParallaxTheme.OCEAN: _build_ocean()
		ParallaxTheme.SPACE: _build_space()
		ParallaxTheme.CITY: _build_city()


func _add_layer(motion_scale: Vector2, color: Color, draw_callback: Callable) -> ParallaxLayer:
	var layer := ParallaxLayer.new()
	layer.motion_scale = motion_scale
	
	var canvas := Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.size = Vector2(2400, 800)
	canvas.position = Vector2(-600, 0)
	canvas.draw.connect(draw_callback.bind(canvas, color))
	layer.add_child(canvas)
	
	add_child(layer)
	_layers.append(layer)
	return layer


## Adds a sprite-based parallax layer from a texture file.
## The texture is scaled to fill the viewport height (default 800 px) and
## motion_mirroring is set so it tiles seamlessly when the camera scrolls.
func _add_sprite_layer(tex_path: String, motion_scale: Vector2,
		viewport_h: float = 800.0) -> void:
	var tex: Texture2D = load(tex_path)
	if tex == null:
		push_warning("[ParallaxDecoration] Could not load texture: " + tex_path)
		return

	var tex_w := float(tex.get_width())
	var tex_h := float(tex.get_height())
	var scale_factor := viewport_h / tex_h if tex_h > 0.0 else 1.0
	var scaled_w := tex_w * scale_factor

	var layer := ParallaxLayer.new()
	layer.motion_scale = motion_scale
	layer.motion_mirroring = Vector2(scaled_w, 0.0)

	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.scale = Vector2(scale_factor, scale_factor)
	spr.position = Vector2.ZERO
	layer.add_child(spr)

	add_child(layer)
	_layers.append(layer)

func _build_meadow() -> void:
	# Swamp background — 5 sprite layers from far (sky) to near (foreground trees).
	# motion_scale: how strongly each layer scrolls with the camera.
	# Layer 1 = furthest/sky — barely moves; Layer 5 = nearest — moves most.
	const BG := "res://assets/swamp_assets/2 Background/Layers/"
	_add_sprite_layer(BG + "1.png", Vector2(0.05, 0.0))
	_add_sprite_layer(BG + "2.png", Vector2(0.15, 0.0))
	_add_sprite_layer(BG + "3.png", Vector2(0.3,  0.05))
	_add_sprite_layer(BG + "4.png", Vector2(0.45, 0.1))
	_add_sprite_layer(BG + "5.png", Vector2(0.6,  0.15))


func _build_volcano() -> void:
	_add_layer(Vector2(0.0, 0.0), Color(0.25, 0.08, 0.05), _draw_sky_gradient)
	_add_layer(Vector2(0.1, 0.0), Color(0.9, 0.4, 0.1, 0.15), _draw_embers)
	_add_layer(Vector2(0.2, 0.1), Color(0.4, 0.15, 0.08, 0.6), _draw_mountains)
	_add_layer(Vector2(0.5, 0.2), Color(0.3, 0.1, 0.05, 0.4), _draw_rocky_terrain)


func _build_sky() -> void:
	_add_layer(Vector2(0.0, 0.0), Color(0.6, 0.82, 1.0), _draw_sky_gradient)
	_add_layer(Vector2(0.05, 0.0), Color(1, 1, 1, 0.8), _draw_clouds)
	_add_layer(Vector2(0.15, 0.0), Color(1, 1, 1, 0.5), _draw_clouds)
	_add_layer(Vector2(0.3, 0.1), Color(0.85, 0.9, 1.0, 0.3), _draw_distant_clouds)


func _build_ocean() -> void:
	_add_layer(Vector2(0.0, 0.0), Color(0.1, 0.25, 0.5), _draw_sky_gradient)
	_add_layer(Vector2(0.1, 0.0), Color(1, 1, 1, 0.5), _draw_clouds)
	_add_layer(Vector2(0.3, 0.1), Color(0.15, 0.4, 0.7, 0.4), _draw_waves)
	_add_layer(Vector2(0.5, 0.2), Color(0.1, 0.35, 0.6, 0.3), _draw_waves)


func _build_space() -> void:
	_add_layer(Vector2(0.0, 0.0), Color(0.02, 0.01, 0.05), _draw_sky_gradient)
	_add_layer(Vector2(0.05, 0.05), Color(1, 1, 1, 0.6), _draw_stars)
	_add_layer(Vector2(0.1, 0.1), Color(0.5, 0.3, 0.8, 0.2), _draw_nebula)
	_add_layer(Vector2(0.15, 0.15), Color(1, 1, 1, 0.8), _draw_stars)


func _build_city() -> void:
	_add_layer(Vector2(0.0, 0.0), Color(0.08, 0.06, 0.15), _draw_sky_gradient)
	_add_layer(Vector2(0.05, 0.0), Color(1, 1, 1, 0.3), _draw_stars)
	_add_layer(Vector2(0.2, 0.1), Color(0.15, 0.12, 0.25, 0.7), _draw_buildings_far)
	_add_layer(Vector2(0.4, 0.2), Color(0.1, 0.08, 0.2, 0.5), _draw_buildings_near)


# ─── Drawing Functions ──────────────────────────────────────────────────────

func _draw_sky_gradient(canvas: Control, color: Color) -> void:
	var h := 800.0
	var w := canvas.size.x
	for i in range(int(h)):
		var t := float(i) / h
		var c := color.lerp(color.darkened(0.4), t)
		canvas.draw_line(Vector2(0, i), Vector2(w, i), c, 1.0)


func _draw_clouds(canvas: Control, color: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_value + 100
	var w := canvas.size.x
	
	for _c in range(8):
		var cx := rng.randf_range(0, w)
		var cy := rng.randf_range(50, 250)
		var cw := rng.randf_range(80, 200)
		var ch := rng.randf_range(20, 50)
		
		# Cloud as overlapping ellipses
		for _b in range(5):
			var bx := cx + rng.randf_range(-cw * 0.3, cw * 0.3)
			var by := cy + rng.randf_range(-ch * 0.2, ch * 0.2)
			var br := rng.randf_range(ch * 0.5, ch * 1.2)
			canvas.draw_circle(Vector2(bx, by), br, color)


func _draw_distant_clouds(canvas: Control, color: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_value + 200
	var w := canvas.size.x
	
	for _c in range(12):
		var cx := rng.randf_range(0, w)
		var cy := rng.randf_range(100, 400)
		var br := rng.randf_range(30, 60)
		canvas.draw_circle(Vector2(cx, cy), br, color)


func _draw_mountains(canvas: Control, color: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_value + 300
	var w := canvas.size.x
	var base_y := 600.0
	
	var points := PackedVector2Array()
	points.append(Vector2(0, 800))
	
	var x := 0.0
	while x < w:
		var height := rng.randf_range(100, 350)
		var peak_x := x + rng.randf_range(30, 80)
		var next_x := x + rng.randf_range(100, 250)
		
		points.append(Vector2(x, base_y))
		points.append(Vector2(peak_x, base_y - height))
		x = next_x
	
	points.append(Vector2(w, base_y))
	points.append(Vector2(w, 800))
	
	if points.size() >= 3:
		canvas.draw_colored_polygon(points, color)


func _draw_hills(canvas: Control, color: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_value + 400
	var w := canvas.size.x
	var base_y := 650.0
	
	var points := PackedVector2Array()
	points.append(Vector2(0, 800))
	
	var segments := 40
	for i in range(segments + 1):
		var t := float(i) / segments
		var x := t * w
		var y := base_y - sin(t * PI * 3 + rng.randf() * 2) * rng.randf_range(30, 80)
		points.append(Vector2(x, y))
	
	points.append(Vector2(w, 800))
	
	if points.size() >= 3:
		canvas.draw_colored_polygon(points, color)


func _draw_tree_line(canvas: Control, color: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_value + 500
	var w := canvas.size.x
	var base_y := 700.0
	
	# Ground fill
	canvas.draw_rect(Rect2(0, base_y, w, 100), color.darkened(0.2), true)
	
	# Trees as triangles
	var x := 0.0
	while x < w:
		var tree_h := rng.randf_range(30, 80)
		var tree_w := rng.randf_range(15, 30)
		var tree_y := base_y - rng.randf_range(0, 10)
		
		var tri := PackedVector2Array()
		tri.append(Vector2(x, tree_y))
		tri.append(Vector2(x + tree_w / 2.0, tree_y - tree_h))
		tri.append(Vector2(x + tree_w, tree_y))
		canvas.draw_colored_polygon(tri, color.darkened(rng.randf_range(0, 0.2)))
		
		x += rng.randf_range(20, 60)


func _draw_waves(canvas: Control, color: Color) -> void:
	var w := canvas.size.x
	var base_y := 500.0
	
	var points := PackedVector2Array()
	points.append(Vector2(0, 800))
	
	var segments := 60
	for i in range(segments + 1):
		var t := float(i) / segments
		var x := t * w
		var y := base_y + sin(t * PI * 4 + _time * 0.5) * 15 + sin(t * PI * 7 + _time * 0.8) * 8
		points.append(Vector2(x, y))
	
	points.append(Vector2(w, 800))
	
	if points.size() >= 3:
		canvas.draw_colored_polygon(points, color)


func _draw_stars(canvas: Control, color: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_value + 600
	var w := canvas.size.x
	
	for _s in range(80):
		var sx := rng.randf_range(0, w)
		var sy := rng.randf_range(0, 600)
		var sr := rng.randf_range(1, 3)
		var alpha := rng.randf_range(0.3, 1.0)
		var c := Color(color.r, color.g, color.b, alpha)
		canvas.draw_circle(Vector2(sx, sy), sr, c)


func _draw_nebula(canvas: Control, color: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_value + 700
	var w := canvas.size.x
	
	for _n in range(6):
		var nx := rng.randf_range(100, w - 100)
		var ny := rng.randf_range(100, 500)
		var nr := rng.randf_range(60, 150)
		
		for ring in range(5):
			var r := nr * (1.0 - float(ring) / 5)
			var a := color.a * (1.0 - float(ring) / 5) * 0.3
			var c := Color(color.r, color.g, color.b, a)
			canvas.draw_circle(Vector2(nx, ny), r, c)


func _draw_embers(canvas: Control, color: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_value + int(_time * 2) + 800
	var w := canvas.size.x
	
	for _e in range(20):
		var ex := rng.randf_range(0, w)
		var ey := rng.randf_range(200, 700) - fmod(_time * 30 + rng.randf() * 100, 600)
		var er := rng.randf_range(1.5, 4)
		canvas.draw_circle(Vector2(ex, ey), er, color)


func _draw_rocky_terrain(canvas: Control, color: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_value + 900
	var w := canvas.size.x
	var base_y := 600.0
	
	var points := PackedVector2Array()
	points.append(Vector2(0, 800))
	
	var x := 0.0
	while x <= w:
		var y := base_y + rng.randf_range(-40, 20)
		points.append(Vector2(x, y))
		x += rng.randf_range(20, 60)
	
	points.append(Vector2(w, 800))
	
	if points.size() >= 3:
		canvas.draw_colored_polygon(points, color)


func _draw_buildings_far(canvas: Control, color: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_value + 1000
	var w := canvas.size.x
	var base_y := 650.0
	
	var x := 0.0
	while x < w:
		var bw := rng.randf_range(30, 80)
		var bh := rng.randf_range(100, 300)
		canvas.draw_rect(Rect2(x, base_y - bh, bw, bh + 150), color, true)
		
		# Windows
		var win_color := Color(1.0, 0.9, 0.5, rng.randf_range(0.1, 0.4))
		var rows := int(bh / 20)
		var cols := int(bw / 15)
		for row in range(rows):
			for col in range(cols):
				if rng.randf() > 0.4:
					var wx := x + 5 + col * 15
					var wy := base_y - bh + 8 + row * 20
					canvas.draw_rect(Rect2(wx, wy, 6, 8), win_color, true)
		
		x += bw + rng.randf_range(5, 20)


func _draw_buildings_near(canvas: Control, color: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed_value + 1100
	var w := canvas.size.x
	var base_y := 700.0
	
	var x := 0.0
	while x < w:
		var bw := rng.randf_range(40, 100)
		var bh := rng.randf_range(80, 200)
		canvas.draw_rect(Rect2(x, base_y - bh, bw, bh + 100), color, true)
		x += bw + rng.randf_range(10, 30)

static func create_for_world(world: int) -> ParallaxDecoration:
	var pd := ParallaxDecoration.new()
	match world:
		0: pd.theme = ParallaxTheme.MEADOW   # Tutorial
		1: pd.theme = ParallaxTheme.MEADOW
		2: pd.theme = ParallaxTheme.VOLCANO
		3: pd.theme = ParallaxTheme.SKY
		4: pd.theme = ParallaxTheme.OCEAN
		5: pd.theme = ParallaxTheme.SPACE
		6: pd.theme = ParallaxTheme.CITY     # Bonus
		_: pd.theme = ParallaxTheme.MEADOW
	return pd
