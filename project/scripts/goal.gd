extends Area2D

## Goal zone with pulsing animation and celebration particle burst.

signal goal_reached

@export var goal_color: Color = Color(0.35, 0.9, 0.5)
@export var goal_radius: float = 28.0

var _time: float = 0.0
var _reached: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	print("[Goal] Ready at %s | monitoring=%s" % [str(global_position), monitoring])


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if _reached:
		return

	var pulse := (sin(_time * 2.5) + 1.0) * 0.5

	# Outer glow rings
	for i in range(3):
		var r := goal_radius + 12.0 + float(i) * 8.0 + pulse * 6.0
		var a := 0.07 - float(i) * 0.018
		_draw_ring(r, Color(goal_color.r, goal_color.g, goal_color.b, a), 1.5)

	# Main filled circle
	var mc := goal_color
	mc.a = 0.55 + pulse * 0.15
	draw_circle(Vector2.ZERO, goal_radius, mc)

	# Bright inner core
	draw_circle(
		Vector2.ZERO, goal_radius * 0.4,
		Color(1, 1, 1, 0.22 + pulse * 0.15)
	)

	# Rotating dashes
	var dash_count := 8
	for i in range(dash_count):
		var angle := float(i) / dash_count * TAU + _time * 0.8
		var inner := Vector2(cos(angle), sin(angle)) * (goal_radius * 0.55)
		var outer := Vector2(cos(angle), sin(angle)) * (goal_radius * 0.85)
		draw_line(inner, outer, Color(1, 1, 1, 0.2 + pulse * 0.1), 1.5)

	# Floating arrows pointing inward (cardinal directions)
	var arrow_dist := goal_radius + 20.0 + sin(_time * 2.0) * 4.0
	for a in [0.0, PI / 2.0, PI, PI * 1.5]:
		var p := Vector2(cos(a), sin(a)) * arrow_dist
		var toward := -Vector2(cos(a), sin(a)) * 6.0
		var perp := Vector2(-sin(a), cos(a)) * 3.0
		draw_line(p, p + toward + perp, Color(goal_color.r, goal_color.g, goal_color.b, 0.2), 1.5)
		draw_line(p, p + toward - perp, Color(goal_color.r, goal_color.g, goal_color.b, 0.2), 1.5)


func _draw_ring(radius: float, color: Color, width: float) -> void:
	var segs := 32
	for i in range(segs):
		var a1 := float(i) / segs * TAU
		var a2 := float(i + 1) / segs * TAU
		draw_line(
			Vector2(cos(a1), sin(a1)) * radius,
			Vector2(cos(a2), sin(a2)) * radius,
			color, width
		)


func _on_body_entered(body: Node2D) -> void:
	print("[Goal] body_entered: %s (class=%s) is_rigid=%s reached=%s" % [body.name, body.get_class(), body is RigidBody2D, _reached])
	if body is RigidBody2D and not _reached:
		print("[Goal] GOAL REACHED! Celebrating...")
		_reached = true
		goal_reached.emit()
		_celebrate()
	else:
		print("[Goal] Ignored (not RigidBody2D or already reached)")


func _celebrate() -> void:
	# Trigger goal particles
	var gp = get_node_or_null("GoalParticles") as CPUParticles2D
	if gp:
		gp.emitting = true

	# Scale up and fade out
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(2.5, 2.5), 0.6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "modulate:a", 0.0, 0.8) \
		.set_ease(Tween.EASE_IN)
