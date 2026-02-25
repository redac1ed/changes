extends Area2D
class_name CoinCollectible

## ═══════════════════════════════════════════════════════════════════════════════
## CoinCollectible — Floating coin with hover animation and collection effects
## ═══════════════════════════════════════════════════════════════════════════════
##
## Inspired by the starter kit's Coin.gd but enhanced with:
## - Multiple coin types (bronze, silver, gold, diamond)
## - Magnetic pull toward nearby ball
## - Score popup text
## - Combo chain tracking
## - Tween collection animation with particles

# ─── Signals ─────────────────────────────────────────────────────────────────
signal collected(coin_type: String, value: int, combo: int)

# ─── Enums ───────────────────────────────────────────────────────────────────
enum CoinType { BRONZE, SILVER, GOLD, DIAMOND }

# ─── Coin Type Configurations ────────────────────────────────────────────────
const COIN_CONFIG: Dictionary = {
	CoinType.BRONZE: {
		"name": "Bronze",
		"value": 10,
		"color": Color(0.8, 0.55, 0.3, 1.0),
		"outline": Color(0.6, 0.35, 0.15, 1.0),
		"shine": Color(1.0, 0.85, 0.6, 0.4),
		"size": 10.0,
	},
	CoinType.SILVER: {
		"name": "Silver",
		"value": 25,
		"color": Color(0.78, 0.78, 0.82, 1.0),
		"outline": Color(0.55, 0.55, 0.6, 1.0),
		"shine": Color(1.0, 1.0, 1.0, 0.5),
		"size": 11.0,
	},
	CoinType.GOLD: {
		"name": "Gold",
		"value": 50,
		"color": Color(1.0, 0.84, 0.0, 1.0),
		"outline": Color(0.8, 0.6, 0.0, 1.0),
		"shine": Color(1.0, 1.0, 0.7, 0.5),
		"size": 12.0,
	},
	CoinType.DIAMOND: {
		"name": "Diamond",
		"value": 100,
		"color": Color(0.6, 0.85, 1.0, 1.0),
		"outline": Color(0.3, 0.6, 0.9, 1.0),
		"shine": Color(1.0, 1.0, 1.0, 0.7),
		"size": 13.0,
	},
}

# ─── Exports ─────────────────────────────────────────────────────────────────
@export_category("Coin Properties")
@export var coin_type: CoinType = CoinType.GOLD
@export var hover_amplitude: float = 4.0
@export var hover_frequency: float = 2.5
@export var rotation_speed: float = 2.0
@export var magnetic: bool = false
@export var magnet_range: float = 80.0
@export var magnet_strength: float = 200.0

@export_category("Visual")
@export var show_sparkles: bool = true
@export var sparkle_rate: float = 3.0
@export var glow_enabled: bool = true

# ─── Internal ────────────────────────────────────────────────────────────────
var _time_passed: float = 0.0
var _initial_position: Vector2
var _coin_rotation: float = 0.0
var _is_collected: bool = false
var _sparkle_timer: float = 0.0
var _sparkles: Array[Dictionary] = []
var _collect_particles: CPUParticles2D
var _collision_shape: CollisionShape2D
var _config: Dictionary

# ─── Static combo tracking ──────────────────────────────────────────────────
static var _combo_count: int = 0
static var _combo_timer: float = 0.0
const COMBO_WINDOW: float = 2.0


func _ready() -> void:
	_initial_position = position
	_config = COIN_CONFIG[coin_type]
	
	# Collision
	_collision_shape = CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = _config["size"] as float + 4.0
	_collision_shape.shape = shape
	add_child(_collision_shape)
	
	collision_layer = 0
	collision_mask = 1  # Ball layer
	body_entered.connect(_on_body_entered)
	
	# Collection particles
	_setup_particles()
	
	# Random start offset for variety
	_time_passed = randf() * TAU


func _process(delta: float) -> void:
	if _is_collected:
		return
	
	_time_passed += delta
	
	# Hover animation
	position.y = _initial_position.y + hover_amplitude * sin(hover_frequency * _time_passed)
	
	# Rotation (3D coin spin effect)
	_coin_rotation += rotation_speed * delta
	
	# Magnetic pull
	if magnetic:
		_process_magnet(delta)
	
	# Sparkles
	if show_sparkles:
		_process_sparkles(delta)
	
	# Combo timer
	if _combo_timer > 0:
		_combo_timer -= delta
		if _combo_timer <= 0:
			_combo_count = 0
	
	queue_redraw()


func _process_magnet(delta: float) -> void:
	# Find nearby ball
	for body in get_overlapping_bodies():
		if body is RigidBody2D:
			var dir := body.global_position - global_position
			var dist := dir.length()
			if dist < magnet_range and dist > 5.0:
				var pull := dir.normalized() * magnet_strength * (1.0 - dist / magnet_range) * delta
				position += pull


func _process_sparkles(delta: float) -> void:
	_sparkle_timer += delta
	if _sparkle_timer >= 1.0 / sparkle_rate:
		_sparkle_timer = 0.0
		var sz: float = _config["size"] as float
		_sparkles.append({
			"pos": Vector2(randf_range(-sz, sz), randf_range(-sz, sz)),
			"life": randf_range(0.3, 0.6),
			"max_life": 0.5,
			"size": randf_range(1.0, 2.5),
		})
	
	# Update sparkles
	var to_remove: Array[int] = []
	for i in range(_sparkles.size()):
		_sparkles[i]["life"] = (_sparkles[i]["life"] as float) - delta
		if (_sparkles[i]["life"] as float) <= 0:
			to_remove.append(i)
	for i in range(to_remove.size() - 1, -1, -1):
		_sparkles.remove_at(to_remove[i])


func _setup_particles() -> void:
	_collect_particles = CPUParticles2D.new()
	_collect_particles.emitting = false
	_collect_particles.one_shot = true
	_collect_particles.amount = 12
	_collect_particles.lifetime = 0.5
	_collect_particles.explosiveness = 0.9
	_collect_particles.direction = Vector2.UP
	_collect_particles.spread = 180.0
	_collect_particles.gravity = Vector2(0, 100)
	_collect_particles.initial_velocity_min = 60.0
	_collect_particles.initial_velocity_max = 140.0
	_collect_particles.scale_amount_min = 1.5
	_collect_particles.scale_amount_max = 3.0
	_collect_particles.color = _config["color"] as Color
	add_child(_collect_particles)


func _on_body_entered(body: Node2D) -> void:
	if _is_collected:
		return
	if body is RigidBody2D:
		_collect(body)


func _collect(body: Node2D) -> void:
	_is_collected = true
	_collision_shape.disabled = true
	
	# Combo tracking
	_combo_count += 1
	_combo_timer = COMBO_WINDOW
	
	var value: int = _config["value"] as int
	var combo_multiplier: int = mini(_combo_count, 5)
	var total_value: int = value * combo_multiplier
	
	# Particles
	_collect_particles.restart()
	_collect_particles.emitting = true
	
	# Score popup
	_spawn_score_popup(total_value, combo_multiplier)
	
	# Play SFX
	if AudioManager:
		AudioManager.play_sfx("coin_pickup")
	
	# Update game state
	if GameState and GameState.has_method("add_score"):
		GameState.add_score(total_value)
	
	collected.emit((_config["name"] as String), total_value, _combo_count)
	
	# Collection animation — scale to zero
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.08)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_property(self, "scale", Vector2.ZERO, 0.12)
	await tween.finished
	queue_free()


func _spawn_score_popup(value: int, combo: int) -> void:
	var popup := Label.new()
	popup.text = "+%d" % value
	if combo > 1:
		popup.text += " x%d!" % combo
	popup.add_theme_font_size_override("font_size", 14 + combo * 2)
	popup.add_theme_color_override("font_color", _config["color"] as Color)
	popup.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	popup.add_theme_constant_override("outline_size", 3)
	popup.position = Vector2(-20, -30)
	popup.z_index = 100
	add_child(popup)
	
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(popup, "position:y", popup.position.y - 40, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(popup, "modulate:a", 0.0, 0.8).set_delay(0.3)


# ─── Drawing ─────────────────────────────────────────────────────────────────

func _draw() -> void:
	if _is_collected:
		return
	
	var sz: float = _config["size"] as float
	var col: Color = _config["color"] as Color
	var out: Color = _config["outline"] as Color
	var shine: Color = _config["shine"] as Color
	
	# 3D coin effect — squeeze X based on rotation
	var squeeze := abs(cos(_coin_rotation))
	squeeze = maxf(squeeze, 0.15)  # Never fully flat
	
	# Shadow
	draw_circle(Vector2(2, 3), sz, Color(0, 0, 0, 0.2))
	
	# Coin body (ellipse via scale trick)
	var segments := 20
	var points := PackedVector2Array()
	for i in range(segments):
		var angle := i * TAU / segments
		points.append(Vector2(cos(angle) * sz * squeeze, sin(angle) * sz))
	draw_colored_polygon(points, col)
	
	# Outline
	for i in range(segments):
		var from_idx := i
		var to_idx := (i + 1) % segments
		draw_line(points[from_idx], points[to_idx], out, 1.5)
	
	# Inner circle detail
	var inner_points := PackedVector2Array()
	var inner_r := sz * 0.65
	for i in range(segments):
		var angle := i * TAU / segments
		inner_points.append(Vector2(cos(angle) * inner_r * squeeze, sin(angle) * inner_r))
	for i in range(segments):
		draw_line(inner_points[i], inner_points[(i + 1) % segments], out, 0.5)
	
	# Value symbol
	var symbol := ""
	match coin_type:
		CoinType.BRONZE: symbol = "B"
		CoinType.SILVER: symbol = "S"
		CoinType.GOLD: symbol = "G"
		CoinType.DIAMOND: symbol = "D"
	
	if squeeze > 0.5:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-4 * squeeze, 5),
			symbol, HORIZONTAL_ALIGNMENT_CENTER,
			-1, 12, out.darkened(0.2)
		)
	
	# Shine highlight
	if squeeze > 0.3:
		var shine_pos := Vector2(-sz * 0.3 * squeeze, -sz * 0.3)
		draw_circle(shine_pos, sz * 0.2, shine)
	
	# Glow
	if glow_enabled:
		var glow_alpha := 0.12 + sin(_time_passed * 3.0) * 0.05
		draw_circle(Vector2.ZERO, sz + 6, Color(col.r, col.g, col.b, glow_alpha))
	
	# Sparkles
	for sparkle in _sparkles:
		var life_ratio := (sparkle["life"] as float) / 0.5
		var sp: Vector2 = sparkle["pos"] as Vector2
		var ssz: float = (sparkle["size"] as float) * life_ratio
		var sc := Color(1.0, 1.0, 1.0, life_ratio * 0.6)
		draw_line(sp + Vector2(-ssz, 0), sp + Vector2(ssz, 0), sc, 1.0)
		draw_line(sp + Vector2(0, -ssz), sp + Vector2(0, ssz), sc, 1.0)


# ─── Factory Methods ────────────────────────────────────────────────────────

static func create_coin(pos: Vector2, type: CoinType = CoinType.GOLD) -> CoinCollectible:
	var coin := CoinCollectible.new()
	coin.position = pos
	coin.coin_type = type
	return coin

static func create_coin_line(start: Vector2, end: Vector2, count: int = 5, type: CoinType = CoinType.GOLD) -> Array[CoinCollectible]:
	var coins: Array[CoinCollectible] = []
	for i in range(count):
		var t := float(i) / maxf(float(count - 1), 1.0)
		var pos := start.lerp(end, t)
		coins.append(create_coin(pos, type))
	return coins

static func create_coin_arc(center: Vector2, radius: float, start_angle: float, end_angle: float, count: int = 5, type: CoinType = CoinType.GOLD) -> Array[CoinCollectible]:
	var coins: Array[CoinCollectible] = []
	for i in range(count):
		var t := float(i) / maxf(float(count - 1), 1.0)
		var angle := start_angle + (end_angle - start_angle) * t
		var pos := center + Vector2(cos(angle), sin(angle)) * radius
		coins.append(create_coin(pos, type))
	return coins
