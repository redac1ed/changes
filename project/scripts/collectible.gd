extends Area2D

## Collectible Star/Coin - Can be collected by the ball
## Tracks collection state and provides visual feedback

@export_group("Collectible Settings")
@export var collectible_id: String = ""  # Unique ID for save/load (auto-generated if empty)
@export var points_value: int = 100
@export var is_star: bool = true  # Star (level rating) vs Coin (bonus)

@export_group("Visual Settings")
@export var star_color: Color = Color(1.0, 0.9, 0.3)
@export var coin_color: Color = Color(1.0, 0.75, 0.2)
@export var glow_intensity: float = 1.0
@export var rotation_speed: float = 2.0
@export var bob_amplitude: float = 5.0
@export var bob_speed: float = 2.0

@export_group("Power-Up System")
@export var power_up_type: String = ""  # "" | "speed_boost" | "shield" | "slow_motion" | "multi" | "magnetism"
@export var power_up_duration: float = 10.0
@export var power_up_radius: float = 150.0

@export_group("Rarity & Tier")
@export var rarity: String = "common"  # common | uncommon | rare | epic | legendary
@export var tier_level: int = 1  # 1-5

# --- Internal State ---
var _time: float = 0.0
var _collected: bool = false
var _base_position: Vector2
var _visual_rotation: float = 0.0
var _collect_scale: float = 1.0
var _combo_count: int = 0
var _last_collect_time: float = 0.0
var _combo_timeout: float = 3.0

# --- Class Variables ---
static var _active_collectibles: Array[CollectibleSpec] = []
static var _combo_multiplier: float = 1.0
static var _last_global_collect_time: float = 0.0

signal collected(collectible: Area2D)
signal power_up_triggered(type: String, duration: float)
signal combo_increased(new_combo: int)


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_base_position = position
	
	# Auto-generate ID if not set
	if collectible_id.is_empty():
		collectible_id = "%s_%d_%d" % [get_parent().name, int(position.x), int(position.y)]
	
	# Check if already collected
	if _is_collected_in_save():
		_collected = true
		visible = false
	
	collision_layer = 0
	collision_mask = 2


func _process(delta: float) -> void:
	if _collected:
		return
	
	_time += delta
	_visual_rotation += rotation_speed * delta
	
	# Bob animation
	position.y = _base_position.y + sin(_time * bob_speed) * bob_amplitude
	
	# Collection animation
	if _collect_scale < 1.0:
		_collect_scale = move_toward(_collect_scale, 0.0, delta * 4.0)
		if _collect_scale <= 0.01:
			visible = false
	
	queue_redraw()


func _draw() -> void:
	if _collected:
		return
	
	var base_scale := _collect_scale
	
	if is_star:
		_draw_star(base_scale)
	else:
		_draw_coin(base_scale)


func _draw_star(base_scale: float) -> void:
	var scale := base_scale
	var glow_pulse := (sin(_time * 3.0) + 1.0) * 0.5 * glow_intensity
	
	# Glow layers
	for i in range(4):
		var glow_size := (20 + i * 8) * scale
		var alpha := (0.15 - i * 0.03) * (1.0 + glow_pulse * 0.5)
		var glow_col := Color(star_color.r, star_color.g, star_color.b, alpha)
		draw_circle(Vector2.ZERO, glow_size, glow_col)
	
	# Draw star shape
	var points := PackedVector2Array()
	var inner_radius := 8 * scale
	var outer_radius := 16 * scale
	
	for i in range(10):
		var angle := _visual_rotation + float(i) / 10.0 * TAU - PI / 2
		var radius := outer_radius if i % 2 == 0 else inner_radius
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	
	# Star fill
	var fill_color := star_color
	fill_color.a = 0.9
	draw_colored_polygon(points, fill_color)
	
	# Star outline
	points.append(points[0])  # Close the shape
	draw_polyline(points, Color(1, 1, 0.8, 0.8), 2.0)
	
	# Center highlight
	draw_circle(Vector2(-2, -2) * scale, 4 * scale, Color(1, 1, 1, 0.5))
	
	# Sparkle particles
	_draw_sparkles(scale)


func _draw_coin(base_scale: float) -> void:
	var scale: float = base_scale
	var glow_pulse: float = (sin(_time * 3.0) + 1.0) * 0.5 * glow_intensity
	
	# Ellipse squash for 3D rotation effect
	var squash: float = abs(cos(_visual_rotation * 2))
	var coin_width: float = 14 * scale * (0.3 + squash * 0.7)
	var coin_height: float = 14 * scale
	
	# Glow
	for i in range(3):
		var glow_size := 18 + i * 6
		var alpha := (0.12 - i * 0.03) * (1.0 + glow_pulse * 0.5)
		draw_circle(Vector2.ZERO, glow_size * scale, Color(coin_color.r, coin_color.g, coin_color.b, alpha))
	
	# Coin body (ellipse approximation)
	_draw_ellipse(Vector2.ZERO, coin_width, coin_height, coin_color)
	
	# Edge highlight
	if squash > 0.3:
		var highlight_x: float = -coin_width * 0.5
		draw_line(
			Vector2(highlight_x, -coin_height * 0.6),
			Vector2(highlight_x, coin_height * 0.6),
			Color(1, 0.9, 0.6, 0.4), 2.0
		)
	
	# Inner circle/symbol
	if squash > 0.5:
		_draw_ellipse(Vector2.ZERO, coin_width * 0.6, coin_height * 0.6, Color(0.9, 0.65, 0.15))


func _draw_ellipse(center: Vector2, width: float, height: float, color: Color) -> void:
	var points := PackedVector2Array()
	var segments := 24
	
	for i in range(segments):
		var angle := float(i) / segments * TAU
		points.append(center + Vector2(cos(angle) * width, sin(angle) * height))
	
	draw_colored_polygon(points, color)


func _draw_sparkles(scale: float) -> void:
	var sparkle_count := 3
	for i in range(sparkle_count):
		var angle := _time * 4 + float(i) / sparkle_count * TAU
		var dist := 20 + sin(_time * 6 + i * 2) * 5
		var pos := Vector2(cos(angle), sin(angle)) * dist * scale
		var sparkle_size := 2 + sin(_time * 8 + i * 3) * 1
		
		draw_circle(pos, sparkle_size * scale, Color(1, 1, 1, 0.6))


func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	
	if body.name == "Player" or body.is_in_group("ball"):
		_collect(body)


func _collect(collector: Node2D) -> void:
	_collected = true
	
	# Update combo multiplier
	var current_time := Time.get_ticks_msec() / 1000.0
	_update_combo(current_time)
	
	# Calculate final points value
	var effective_points := get_effective_points()
	
	# Start collection animation
	_collect_scale = 1.0
	
	# Spawn collection particles
	_spawn_collect_particles()
	
	# Play sound
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx("star_collect")
	
	# Activate power-up if present
	if not power_up_type.is_empty():
		_activate_power_up(collector)
	
	# Update game state
	if has_node("/root/GameState"):
		var game_state = get_node("/root/GameState")
		if is_star:
			game_state.add_stars(1)
		game_state.add_collectible(collectible_id, effective_points)
	
	# Track in level manager
	if has_node("/root/LevelManager"):
		get_node("/root/LevelManager").record_collectible(
			GameState.current_world if GameState else 0,
			GameState.current_level if GameState else 0
		)
	
	collected.emit(self)
	
	# Delayed free
	get_tree().create_timer(0.5).timeout.connect(queue_free)


func _spawn_collect_particles() -> void:
	var particles := CPUParticles2D.new()
	particles.position = Vector2.ZERO
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 25
	particles.lifetime = 0.6
	particles.direction = Vector2(0, 0)
	particles.spread = 180.0
	particles.initial_velocity_min = 80.0
	particles.initial_velocity_max = 200.0
	particles.gravity = Vector2(0, -50)
	particles.scale_amount_min = 2.0
	particles.scale_amount_max = 5.0
	particles.color = star_color if is_star else coin_color
	particles.finished.connect(particles.queue_free)
	get_parent().add_child(particles)
	particles.global_position = global_position


func _is_collected_in_save() -> bool:
	if has_node("/root/GameState"):
		var game_state = get_node("/root/GameState")
		if game_state.has_method("is_collectible_collected"):
			return game_state.is_collectible_collected(collectible_id)
	return false


# ═══════════════════════════════════════════════════════════════════════════
# POWER-UP SYSTEM
# ═══════════════════════════════════════════════════════════════════════════

func _activate_power_up(collector: Node2D) -> void:
	"""Activate power-up effect and apply duration"""
	if power_up_type.is_empty():
		return
	
	print("[Collectible] Activating power-up: %s" % power_up_type)
	
	match power_up_type:
		"speed_boost":
			_apply_speed_boost(collector)
		"shield":
			_apply_shield(collector)
		"slow_motion":
			_apply_slow_motion()
		"multi":
			_apply_multi_effect()
		"magnetism":
			_apply_magnetism()


func _apply_speed_boost(collector: Node2D) -> void:
	"""Boost collector velocity by 1.5x"""
	if collector is RigidBody2D:
		var original_vel := collector.linear_velocity
		collector.linear_velocity = original_vel * 1.5
		
		# Visual trail effect
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_SINE)
		tw.tween_property(collector, "modulate:g", 1.5, 0.1)
		tw.tween_callback(func(): tw2_restore_color(collector))
	
	power_up_triggered.emit(power_up_type, power_up_duration)
	_spawn_power_up_effect("speed")


func _apply_shield(collector: Node2D) -> void:
	"""Grant temporary invincibility to collector"""
	# Add marker to collector for shader/visual effect
	if collector.has_meta("shielded"):
		collector.set_meta("shield_time_remaining", power_up_duration)
	else:
		collector.set_meta("shielded", true)
		collector.set_meta("shield_time_remaining", power_up_duration)
	
	# Countdown timer
	var remaining := power_up_duration
	var timer := get_tree().create_timer(power_up_duration)
	timer.timeout.connect(func():
		if collector and collector.has_meta("shielded"):
			collector.remove_meta("shielded")
			print("[Collectible] Shield expired")
	)
	
	power_up_triggered.emit(power_up_type, power_up_duration)
	_spawn_power_up_effect("shield")


func _apply_slow_motion() -> void:
	"""Slow world time by 0.5x for duration"""
	var original_scale := Engine.time_scale
	Engine.time_scale = 0.5
	
	var timer := get_tree().create_timer(power_up_duration, true)
	timer.timeout.connect(func():
		Engine.time_scale = original_scale
		print("[Collectible] Time scale restored")
	)
	
	power_up_triggered.emit(power_up_type, power_up_duration)
	_spawn_power_up_effect("slow_motion")


func _apply_multi_effect() -> void:
	"""Double points multiplier for upcoming collections"""
	_combo_multiplier = 2.0
	
	var timer := get_tree().create_timer(power_up_duration)
	timer.timeout.connect(func():
		_combo_multiplier = 1.0
		print("[Collectible] Multi effect expired")
	)
	
	power_up_triggered.emit(power_up_type, power_up_duration)
	_spawn_power_up_effect("multi")


func _apply_magnetism() -> void:
	"""Auto-collect nearby collectibles"""
	var space_state := get_world_2d().direct_space_state
	
	# Find all collectibles in radius
	var nearby_collectibles := get_tree().get_nodes_in_group("collectible")
	var collected_count := 0
	
	for collectible in nearby_collectibles:
		if collectible == self or collectible._collected:
			continue
		
		var dist := global_position.distance_to(collectible.global_position)
		if dist < power_up_radius:
			# Pull towards collector
			var direction := (global_position - collectible.global_position).normalized()
			var tween := create_tween()
			tween.set_trans(Tween.TRANS_QUAD)
			tween.set_ease(Tween.EASE_IN)
			tween.tween_property(collectible, "global_position", global_position, 0.3)
			collectible._collect(collectible.get_parent())
			collected_count += 1
	
	print("[Collectible] Magnetism collected %d items" % collected_count)
	power_up_triggered.emit(power_up_type, power_up_duration)
	_spawn_power_up_effect("magnetism")


func _spawn_power_up_effect(type: String) -> void:
	"""Emit visual effect for power-up activation"""
	var particles := CPUParticles2D.new()
	particles.position = Vector2.ZERO
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.amount = 40
	particles.lifetime = 1.0
	particles.direction = Vector2(0, 0)
	particles.spread = 360.0
	particles.initial_velocity_min = 100.0
	particles.initial_velocity_max = 250.0
	particles.gravity = Vector2(0, 0)
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.0
	
	# Color by type
	match type:
		"speed": particles.color = Color(0.8, 1.0, 0.4)
		"shield": particles.color = Color(0.4, 0.8, 1.0)
		"slow_motion": particles.color = Color(1.0, 0.6, 0.4)
		"multi": particles.color = Color(1.0, 0.4, 1.0)
		"magnetism": particles.color = Color(1.0, 0.8, 0.2)
	
	particles.finished.connect(particles.queue_free)
	get_parent().add_child(particles)
	particles.global_position = global_position


func tw2_restore_color(node: Node2D) -> void:
	"""Helper to restore node color"""
	var tw := create_tween()
	tw.tween_property(node, "modulate:g", 1.0, 0.1)


# ═══════════════════════════════════════════════════════════════════════════
# RARITY & COMBO SYSTEM
# ═══════════════════════════════════════════════════════════════════════════

func _update_combo(current_time: float) -> void:
	"""Update combo multiplier based on collection timing"""
	var time_since_last := current_time - _last_global_collect_time
	
	if time_since_last < _combo_timeout:
		_combo_count += 1
		_combo_multiplier = 1.0 + (_combo_count * 0.1)  # 1.1x per combo
		combo_increased.emit(_combo_count)
		print("[Collectible] Combo x%.1f! (%d)" % [_combo_multiplier, _combo_count])
	else:
		_combo_count = 0
		_combo_multiplier = 1.0
	
	_last_global_collect_time = current_time


func get_rarity_multiplier() -> float:
	"""Return points multiplier based on rarity"""
	match rarity:
		"common": return 1.0
		"uncommon": return 1.5
		"rare": return 2.0
		"epic": return 3.0
		"legendary": return 5.0
		_: return 1.0


func get_rarity_color() -> Color:
	"""Get visual color for rarity tier"""
	match rarity:
		"common": return Color(0.8, 0.8, 0.8)
		"uncommon": return Color(0.4, 1.0, 0.4)
		"rare": return Color(0.4, 0.8, 1.0)
		"epic": return Color(1.0, 0.4, 1.0)
		"legendary": return Color(1.0, 0.8, 0.2)
		_: return Color.WHITE


func get_effective_points() -> int:
	"""Calculate final points with all multipliers"""
	var base := int(points_value)
	var rarity_mult := get_rarity_multiplier()
	var combo_mult := _combo_multiplier
	var tier_mult := 1.0 + (tier_level * 0.1)
	
	return int(base * rarity_mult * combo_mult * tier_mult)


func get_collectible_info() -> Dictionary:
	"""Return metadata about this collectible"""
	return {
		"id": collectible_id,
		"type": "star" if is_star else "coin",
		"rarity": rarity,
		"tier": tier_level,
		"power_up": power_up_type,
		"base_points": points_value,
		"effective_points": get_effective_points(),
		"combo": _combo_count,
		"collected": _collected,
	}


# --- Public API ---

func reset() -> void:
	_collected = false
	visible = true
	_collect_scale = 1.0
	position = _base_position


# ═══════════════════════════════════════════════════════════════════════════
# COLLECTIBLE FACTORY & PRESET DEFINITIONS
# ═══════════════════════════════════════════════════════════════════════════

class CollectibleSpec:
	"""Specification for creating collectible variants"""
	var name: String
	var is_star: bool = true
	var points: int = 100
	var rarity: String = "common"
	var tier: int = 1
	var power_up: String = ""
	var power_duration: float = 10.0
	var visuals: Dictionary  # color overrides, etc
	
	func _init(p_name: String, p_is_star: bool = true, p_points: int = 100) -> void:
		name = p_name
		is_star = p_is_star
		points = p_points
		visuals = {}


static var PRESET_SPECS: Dictionary = {
	"basic_star": {
		"is_star": true,
		"points": 10,
		"rarity": "common",
		"tier": 1,
		"power_up": "",
	},
	"gold_coin": {
		"is_star": false,
		"points": 5,
		"rarity": "common",
		"tier": 1,
		"power_up": "",
	},
	"treasure": {
		"is_star": false,
		"points": 50,
		"rarity": "rare",
		"tier": 2,
		"power_up": "multi",
	},
	"speed_orb": {
		"is_star": true,
		"points": 25,
		"rarity": "uncommon",
		"tier": 2,
		"power_up": "speed_boost",
		"power_duration": 8.0,
	},
	"shield_gem": {
		"is_star": true,
		"points": 25,
		"rarity": "uncommon",
		"tier": 2,
		"power_up": "shield",
		"power_duration": 12.0,
	},
	"time_crystal": {
		"is_star": true,
		"points": 50,
		"rarity": "epic",
		"tier": 3,
		"power_up": "slow_motion",
		"power_duration": 6.0,
	},
	"magnet_star": {
		"is_star": true,
		"points": 75,
		"rarity": "epic",
		"tier": 3,
		"power_up": "magnetism",
		"power_duration": 5.0,
	},
	"legendary_artifact": {
		"is_star": true,
		"points": 200,
		"rarity": "legendary",
		"tier": 5,
		"power_up": "multi",
		"power_duration": 15.0,
	},
}


static func create_from_preset(preset_name: String, position: Vector2) -> Node:
	"""Factory method to create collectible from preset"""
	if not PRESET_SPECS.has(preset_name):
		push_error("Unknown preset: %s" % preset_name)
		return null
	
	var spec := PRESET_SPECS[preset_name]
	var collectible := Area2D.new()
	collectible.global_position = position
	
	# Apply GDScript
	var script := load("res://scripts/collectible.gd")
	collectible.set_script(script)
	
	# Configure from preset
	collectible.is_star = spec.get("is_star", true)
	collectible.points_value = spec.get("points", 100)
	collectible.rarity = spec.get("rarity", "common")
	collectible.tier_level = spec.get("tier", 1)
	collectible.power_up_type = spec.get("power_up", "")
	collectible.power_up_duration = spec.get("power_duration", 10.0)
	
	# Generate unique ID
	collectible.collectible_id = "%s_%d" % [preset_name, int(position.x) * 1000 + int(position.y)]
	
	# Add to collectible group
	collectible.add_to_group("collectible")
	
	return collectible


static func create_batch(preset_name: String, positions: Array[Vector2]) -> Array[Node]:
	"""Create multiple collectibles from preset"""
	var collectibles: Array[Node] = []
	for pos in positions:
		var c := create_from_preset(preset_name, pos)
		if c:
			collectibles.append(c)
	return collectibles
