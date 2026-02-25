extends Node
class_name LevelBuilder

## ═══════════════════════════════════════════════════════════════════════════════
## LevelBuilder — Static utility for constructing levels programmatically
## ═══════════════════════════════════════════════════════════════════════════════
##
## Provides factory methods to quickly place platforms, hazards, enemies,
## coins, checkpoints, and doors into a level scene. Simplifies level design
## by encapsulating configuration in concise method calls.
##
## Usage:
##   var builder = LevelBuilder.new()
##   add_child(builder)
##   builder.set_level(self)
##   builder.add_static_platform(Vector2(200, 500), Vector2(200, 20))
##   builder.add_coin_arc(Vector2(300, 400), 80, 5)
##   builder.add_door(Vector2(1000, 460))

var _level: Node2D


func set_level(level: Node2D) -> void:
	_level = level


# ═══════════════════════════════════════════════════════════════════════════════
#  PLATFORMS
# ═══════════════════════════════════════════════════════════════════════════════

func add_static_platform(pos: Vector2, size: Vector2 = Vector2(120, 16),
		color: Color = Color(0.35, 0.45, 0.55)) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = pos
	
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	
	# Visual via _draw proxy
	var visual := _PlatformVisual.new()
	visual.platform_size = size
	visual.platform_color = color
	body.add_child(visual)
	
	_level.add_child(body)
	return body


func add_moving_platform(pos: Vector2, end_pos: Vector2,
		size: Vector2 = Vector2(100, 16), speed: float = 80.0) -> Node:
	var platform_script := load("res://scripts/platforms/moving_platform_advanced.gd")
	if platform_script:
		var p: Node2D = Node2D.new()
		p.set_script(platform_script)
		p.position = pos
		p.platform_size = size
		p.move_speed = speed
		p.waypoints = [Vector2.ZERO, end_pos - pos]
		_level.add_child(p)
		return p
	return null


func add_falling_platform(pos: Vector2, size: Vector2 = Vector2(80, 14)) -> Node:
	var script := load("res://scripts/platforms/falling_platform.gd")
	if script:
		var p := Node2D.new()
		p.set_script(script)
		p.position = pos
		p.platform_size = size
		_level.add_child(p)
		return p
	return null


func add_ice_platform(pos: Vector2, size: Vector2 = Vector2(120, 14)) -> Node:
	var script := load("res://scripts/platforms/ice_platform.gd")
	if script:
		var p := Node2D.new()
		p.set_script(script)
		p.position = pos
		p.platform_size = size
		_level.add_child(p)
		return p
	return null


func add_conveyor_platform(pos: Vector2, size: Vector2 = Vector2(120, 16),
		speed: float = 100.0, direction: float = 1.0) -> Node:
	var script := load("res://scripts/platforms/conveyor_platform.gd")
	if script:
		var p := Node2D.new()
		p.set_script(script)
		p.position = pos
		p.platform_size = size
		p.belt_speed = speed
		p.belt_direction = direction
		_level.add_child(p)
		return p
	return null


func add_bounce_platform(pos: Vector2, size: Vector2 = Vector2(80, 16),
		force: float = 800.0) -> Node:
	var script := load("res://scripts/platforms/bounce_platform.gd")
	if script:
		var p := Node2D.new()
		p.set_script(script)
		p.position = pos
		p.platform_size = size
		p.bounce_force = force
		_level.add_child(p)
		return p
	return null


func add_disappearing_platform(pos: Vector2, size: Vector2 = Vector2(80, 14),
		visible_time: float = 2.0, invisible_time: float = 1.5) -> Node:
	var script := load("res://scripts/platforms/disappearing_platform.gd")
	if script:
		var p := Node2D.new()
		p.set_script(script)
		p.position = pos
		p.platform_size = size
		p.visible_duration = visible_time
		p.invisible_duration = invisible_time
		_level.add_child(p)
		return p
	return null


func add_crumbling_platform(pos: Vector2, size: Vector2 = Vector2(100, 14)) -> Node:
	var script := load("res://scripts/platforms/crumbling_platform.gd")
	if script:
		var p := Node2D.new()
		p.set_script(script)
		p.position = pos
		p.platform_size = size
		_level.add_child(p)
		return p
	return null


func add_one_way_platform(pos: Vector2, size: Vector2 = Vector2(100, 10)) -> Node:
	var script := load("res://scripts/platforms/one_way_platform.gd")
	if script:
		var p := Node2D.new()
		p.set_script(script)
		p.position = pos
		p.platform_size = size
		_level.add_child(p)
		return p
	return null


func add_weighted_platform(pos: Vector2, size: Vector2 = Vector2(150, 14)) -> Node:
	var script := load("res://scripts/platforms/weighted_platform.gd")
	if script:
		var p := Node2D.new()
		p.set_script(script)
		p.position = pos
		p.platform_size = size
		_level.add_child(p)
		return p
	return null


# ═══════════════════════════════════════════════════════════════════════════════
#  GROUND / WALLS
# ═══════════════════════════════════════════════════════════════════════════════

func add_ground(y: float, width: float = 1200.0, color: Color = Color(0.25, 0.3, 0.28)) -> StaticBody2D:
	return add_static_platform(Vector2(width / 2.0, y + 10), Vector2(width, 20), color)


func add_wall(x: float, y: float, height: float = 400.0, color: Color = Color(0.3, 0.3, 0.35)) -> StaticBody2D:
	return add_static_platform(Vector2(x, y), Vector2(16, height), color)


func add_boundary_walls(bounds: Rect2, wall_thickness: float = 20.0) -> void:
	# Left wall
	add_static_platform(
		Vector2(bounds.position.x - wall_thickness / 2, bounds.position.y + bounds.size.y / 2),
		Vector2(wall_thickness, bounds.size.y + wall_thickness * 2),
		Color(0.2, 0.2, 0.25, 0.3)
	)
	# Right wall
	add_static_platform(
		Vector2(bounds.position.x + bounds.size.x + wall_thickness / 2, bounds.position.y + bounds.size.y / 2),
		Vector2(wall_thickness, bounds.size.y + wall_thickness * 2),
		Color(0.2, 0.2, 0.25, 0.3)
	)
	# Ceiling
	add_static_platform(
		Vector2(bounds.position.x + bounds.size.x / 2, bounds.position.y - wall_thickness / 2),
		Vector2(bounds.size.x + wall_thickness * 2, wall_thickness),
		Color(0.2, 0.2, 0.25, 0.3)
	)


# ═══════════════════════════════════════════════════════════════════════════════
#  HAZARDS
# ═══════════════════════════════════════════════════════════════════════════════

func add_spikes(pos: Vector2, width: float = 100.0) -> Node:
	var script := load("res://scripts/hazards/spike_strip.gd")
	if script:
		var s := Area2D.new()
		s.set_script(script)
		s.position = pos
		s.strip_width = width
		_level.add_child(s)
		return s
	return null


func add_saw_blade(pos: Vector2, radius: float = 20.0, path_points: Array[Vector2] = []) -> Node:
	var script := load("res://scripts/hazards/saw_blade.gd")
	if script:
		var s := Area2D.new()
		s.set_script(script)
		s.position = pos
		s.blade_radius = radius
		if not path_points.is_empty():
			s.move_path = path_points
		_level.add_child(s)
		return s
	return null


func add_crusher(pos: Vector2, size: Vector2 = Vector2(60, 40)) -> Node:
	var script := load("res://scripts/hazards/crusher_trap.gd")
	if script:
		var s := Area2D.new()
		s.set_script(script)
		s.position = pos
		s.crusher_size = size
		_level.add_child(s)
		return s
	return null


func add_fire_jet(pos: Vector2, direction: Vector2 = Vector2.UP, length: float = 120.0) -> Node:
	var script := load("res://scripts/hazards/fire_jet.gd")
	if script:
		var s := Area2D.new()
		s.set_script(script)
		s.position = pos
		s.jet_direction = direction
		s.jet_length = length
		_level.add_child(s)
		return s
	return null


func add_laser(pos: Vector2, direction: Vector2 = Vector2.RIGHT, length: float = 200.0) -> Node:
	var script := load("res://scripts/hazards/laser_beam.gd")
	if script:
		var s := Area2D.new()
		s.set_script(script)
		s.position = pos
		s.beam_direction = direction
		s.beam_length = length
		_level.add_child(s)
		return s
	return null


func add_acid_pool(pos: Vector2, size: Vector2 = Vector2(120, 16)) -> Node:
	var script := load("res://scripts/hazards/acid_pool.gd")
	if script:
		var s := Area2D.new()
		s.set_script(script)
		s.position = pos
		s.pool_size = size
		_level.add_child(s)
		return s
	return null


# ═══════════════════════════════════════════════════════════════════════════════
#  COLLECTIBLES
# ═══════════════════════════════════════════════════════════════════════════════

func add_coin(pos: Vector2, coin_type: int = 0) -> Node:
	var script := load("res://scripts/items/coin_collectible.gd")
	if script:
		var c := Area2D.new()
		c.set_script(script)
		c.position = pos
		c.coin_type = coin_type
		_level.add_child(c)
		return c
	return null


func add_coin_line(start: Vector2, end: Vector2, count: int = 5, coin_type: int = 0) -> void:
	for i in range(count):
		var t := float(i) / max(count - 1, 1)
		var pos := start.lerp(end, t)
		add_coin(pos, coin_type)


func add_coin_arc(center: Vector2, radius: float, count: int = 5,
		start_angle: float = PI, end_angle: float = 0.0, coin_type: int = 0) -> void:
	for i in range(count):
		var t := float(i) / max(count - 1, 1)
		var angle := lerp(start_angle, end_angle, t)
		var pos := center + Vector2(cos(angle), sin(angle)) * radius
		add_coin(pos, coin_type)


func add_checkpoint(pos: Vector2) -> Node:
	var script := load("res://scripts/items/checkpoint.gd")
	if script:
		var cp := Area2D.new()
		cp.set_script(script)
		cp.position = pos
		_level.add_child(cp)
		return cp
	return null


func add_door(pos: Vector2) -> Node:
	var script := load("res://scripts/items/level_finish_door.gd")
	if script:
		var d := Area2D.new()
		d.set_script(script)
		d.position = pos
		_level.add_child(d)
		return d
	return null


# ═══════════════════════════════════════════════════════════════════════════════
#  ENEMIES
# ═══════════════════════════════════════════════════════════════════════════════

func add_walker_enemy(pos: Vector2, patrol_dist: float = 100.0) -> Node:
	var enemy := EnemyBase.create_walker(pos)
	enemy.patrol_distance = patrol_dist
	_level.add_child(enemy)
	return enemy


func add_flyer_enemy(pos: Vector2, patrol_dist: float = 80.0) -> Node:
	var enemy := EnemyBase.create_flyer(pos)
	enemy.patrol_distance = patrol_dist
	_level.add_child(enemy)
	return enemy


func add_turret_enemy(pos: Vector2) -> Node:
	var enemy := EnemyBase.create_turret(pos)
	_level.add_child(enemy)
	return enemy


func add_charger_enemy(pos: Vector2, patrol_dist: float = 100.0) -> Node:
	var enemy := EnemyBase.create_charger(pos)
	enemy.patrol_distance = patrol_dist
	_level.add_child(enemy)
	return enemy


# ═══════════════════════════════════════════════════════════════════════════════
#  DECORATION
# ═══════════════════════════════════════════════════════════════════════════════

func add_parallax_background(world: int = 1) -> ParallaxDecoration:
	var pd := ParallaxDecoration.create_for_world(world)
	_level.add_child(pd)
	# Move to back
	_level.move_child(pd, 0)
	return pd


func add_decoration_rect(pos: Vector2, size: Vector2, color: Color) -> Node2D:
	var deco := _DecoRect.new()
	deco.position = pos
	deco.deco_size = size
	deco.deco_color = color
	_level.add_child(deco)
	return deco


# ═══════════════════════════════════════════════════════════════════════════════
#  LEVEL PRESETS
# ═══════════════════════════════════════════════════════════════════════════════

func build_platformer_basics(bounds: Rect2) -> void:
	"""Set up ground, walls, and boundary for a basic platformer level."""
	add_ground(bounds.position.y + bounds.size.y)
	add_boundary_walls(bounds)


# ═══════════════════════════════════════════════════════════════════════════════
#  HELPER CLASSES
# ═══════════════════════════════════════════════════════════════════════════════

class _PlatformVisual extends Node2D:
	var platform_size: Vector2 = Vector2(100, 16)
	var platform_color: Color = Color(0.35, 0.45, 0.55)
	
	func _draw() -> void:
		var hw := platform_size.x / 2.0
		var hh := platform_size.y / 2.0
		
		# Main body
		draw_rect(Rect2(-hw, -hh, platform_size.x, platform_size.y), platform_color, true)
		
		# Top highlight
		draw_line(Vector2(-hw, -hh), Vector2(hw, -hh), platform_color.lightened(0.25), 2.0)
		
		# Bottom shadow
		draw_line(Vector2(-hw, hh), Vector2(hw, hh), platform_color.darkened(0.25), 2.0)
		
		# Outline
		draw_rect(Rect2(-hw, -hh, platform_size.x, platform_size.y), platform_color.darkened(0.35), false, 1.0)


class _DecoRect extends Node2D:
	var deco_size: Vector2 = Vector2(40, 40)
	var deco_color: Color = Color(0.3, 0.4, 0.35, 0.5)
	
	func _draw() -> void:
		draw_rect(Rect2(-deco_size.x / 2, -deco_size.y / 2, deco_size.x, deco_size.y), deco_color, true)
