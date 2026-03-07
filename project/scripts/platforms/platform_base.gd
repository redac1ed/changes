extends StaticBody2D
class_name PlatformBase

## ═══════════════════════════════════════════════════════════════════════════════
## PlatformBase — Foundation class for all platform types in Changes
## ═══════════════════════════════════════════════════════════════════════════════
##
## Provides shared functionality: visual rendering, collision shapes,
## color theming, particle effects, squash/stretch reactions, and audio hooks.
## All specialized platforms (moving, falling, one-way, etc.) inherit from this.

# ─── Signals ─────────────────────────────────────────────────────────────────
signal ball_landed(ball: RigidBody2D)
signal ball_left(ball: RigidBody2D)
signal platform_activated()
signal platform_deactivated()

# ─── Enums ───────────────────────────────────────────────────────────────────
enum PlatformType {
	STATIC,        ## Immovable solid platform
	MOVING,        ## Oscillates between two points
	FALLING,       ## Drops after ball lands on it
	ONE_WAY,       ## Pass through from below
	CRUMBLING,     ## Breaks after brief contact
	ICE,           ## Low friction, slippery surface
	CONVEYOR,      ## Pushes ball along surface
	BOUNCE,        ## Launches ball upward on contact
	DISAPPEARING,  ## Phases in/out on a timer
	WEIGHTED,      ## Tilts based on ball position
}

# ─── Exports ─────────────────────────────────────────────────────────────────
@export_category("Platform Properties")
@export var platform_type: PlatformType = PlatformType.STATIC
@export var platform_size: Vector2 = Vector2(128, 24)
@export var platform_color: Color = Color(0.35, 0.75, 0.35, 1.0)
@export var outline_color: Color = Color(0.2, 0.55, 0.2, 1.0)
@export var outline_width: float = 2.0
@export var corner_radius: float = 4.0
@export var use_shadow: bool = true
@export var shadow_offset: Vector2 = Vector2(3, 4)
@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.2)

@export_category("Visual Effects")
@export var enable_highlight: bool = true
@export var highlight_color: Color = Color(1.0, 1.0, 1.0, 0.15)
@export var enable_particles: bool = true
@export var particle_color: Color = Color(0.5, 0.85, 0.5, 0.6)
@export var glow_intensity: float = 0.0
@export var glow_color: Color = Color(0.4, 0.9, 0.4, 0.3)

@export_category("Behavior")
@export var is_active: bool = true
@export var react_to_ball: bool = true
@export var squash_on_land: bool = true
@export var land_sfx: String = "bounce"

# ─── Internal State ──────────────────────────────────────────────────────────
var _collision_shape: CollisionShape2D
var _shape_rect: RectangleShape2D
var _time_elapsed: float = 0.0
var _squash_scale: Vector2 = Vector2.ONE
var _is_ball_on_platform: bool = false
var _original_position: Vector2
var _flash_timer: float = 0.0
var _particles: CPUParticles2D
var _detection_area: Area2D

# ─── Constants ───────────────────────────────────────────────────────────────
const SQUASH_AMOUNT: float = 0.08
const SQUASH_SPEED: float = 12.0
const FLASH_DURATION: float = 0.15


# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_original_position = position
	_setup_collision()
	_setup_detection_area()
	if enable_particles:
		_setup_particles()
	_platform_ready()


func _process(delta: float) -> void:
	_time_elapsed += delta
	
	# Squash recovery
	if _squash_scale != Vector2.ONE:
		_squash_scale = _squash_scale.lerp(Vector2.ONE, delta * SQUASH_SPEED)
		if _squash_scale.distance_to(Vector2.ONE) < 0.001:
			_squash_scale = Vector2.ONE
	
	# Flash timer
	if _flash_timer > 0.0:
		_flash_timer -= delta
	
	_platform_process(delta)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_platform_physics_process(delta)


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════════════════════

func _setup_collision() -> void:
	# Create collision shape matching platform size
	_collision_shape = CollisionShape2D.new()
	_shape_rect = RectangleShape2D.new()
	_shape_rect.size = platform_size
	_collision_shape.shape = _shape_rect
	add_child(_collision_shape)


func _setup_detection_area() -> void:
	# Area2D slightly larger than platform to detect ball approach/landing
	_detection_area = Area2D.new()
	var area_shape := CollisionShape2D.new()
	var area_rect := RectangleShape2D.new()
	area_rect.size = Vector2(platform_size.x + 8, platform_size.y + 16)
	area_shape.shape = area_rect
	area_shape.position = Vector2(0, -4)
	_detection_area.add_child(area_shape)
	_detection_area.collision_layer = 0
	_detection_area.collision_mask = 3  # Detect ball (layer 1 and 2)
	_detection_area.body_entered.connect(_on_detection_body_entered)
	_detection_area.body_exited.connect(_on_detection_body_exited)
	add_child(_detection_area)


func _setup_particles() -> void:
	_particles = CPUParticles2D.new()
	_particles.emitting = false
	_particles.one_shot = true
	_particles.amount = 8
	_particles.lifetime = 0.4
	_particles.direction = Vector2.UP
	_particles.spread = 45.0
	_particles.gravity = Vector2(0, 200)
	_particles.initial_velocity_min = 30.0
	_particles.initial_velocity_max = 80.0
	_particles.scale_amount_min = 1.5
	_particles.scale_amount_max = 3.0
	_particles.color = particle_color
	add_child(_particles)


# ═══════════════════════════════════════════════════════════════════════════════
# DRAWING
# ═══════════════════════════════════════════════════════════════════════════════

func _draw() -> void:
	if not is_active:
		return
	
	var half := platform_size / 2.0
	var rect := Rect2(-half * _squash_scale, platform_size * _squash_scale)
	
	# Shadow
	if use_shadow:
		var shadow_rect := Rect2(rect.position + shadow_offset, rect.size)
		draw_rect(shadow_rect, shadow_color, true)
	
	# Main body
	var draw_color := platform_color
	if _flash_timer > 0.0:
		draw_color = draw_color.lightened(0.3)
	draw_rect(rect, draw_color, true)
	
	# Outline
	draw_rect(rect, outline_color, false, outline_width)
	
	# Top highlight stripe
	if enable_highlight:
		var highlight_rect := Rect2(
			rect.position + Vector2(outline_width, outline_width),
			Vector2(rect.size.x - outline_width * 2, 4.0)
		)
		draw_rect(highlight_rect, highlight_color, true)
	
	# Surface detail lines (texture-like)
	_draw_surface_details(rect)
	
	# Glow effect
	if glow_intensity > 0.0:
		var glow_rect := Rect2(rect.position - Vector2(4, 4), rect.size + Vector2(8, 8))
		var gc := glow_color
		gc.a = glow_intensity * (0.3 + sin(_time_elapsed * 2.0) * 0.1)
		draw_rect(glow_rect, gc, false, 3.0)
	
	# Type-specific drawing
	_draw_platform_details(rect)


func _draw_surface_details(rect: Rect2) -> void:
	# Subtle horizontal lines for texture
	var line_color := Color(outline_color.r, outline_color.g, outline_color.b, 0.15)
	var line_spacing := 6.0
	var y := rect.position.y + 8
	while y < rect.position.y + rect.size.y - 2:
		draw_line(
			Vector2(rect.position.x + 3, y),
			Vector2(rect.position.x + rect.size.x - 3, y),
			line_color, 1.0
		)
		y += line_spacing
	
	# Corner dots for pixel-art feel
	var dot_color := Color(outline_color.r, outline_color.g, outline_color.b, 0.3)
	var dot_size := 2.0
	draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(dot_size, dot_size)), dot_color, true)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - 4, 2), Vector2(dot_size, dot_size)), dot_color, true)
	draw_rect(Rect2(rect.position + Vector2(2, rect.size.y - 4), Vector2(dot_size, dot_size)), dot_color, true)
	draw_rect(Rect2(rect.position + Vector2(rect.size.x - 4, rect.size.y - 4), Vector2(dot_size, dot_size)), dot_color, true)


# Override in subclasses for type-specific visuals
func _draw_platform_details(_rect: Rect2) -> void:
	pass


# ═══════════════════════════════════════════════════════════════════════════════
# BALL INTERACTION
# ═══════════════════════════════════════════════════════════════════════════════

func _on_detection_body_entered(body: Node2D) -> void:
	if not react_to_ball:
		return
	if body is RigidBody2D:
		_is_ball_on_platform = true
		if squash_on_land:
			_apply_squash()
		if enable_particles:
			_emit_land_particles(body)
		_flash_timer = FLASH_DURATION
		ball_landed.emit(body)
		_on_ball_landed(body)


func _on_detection_body_exited(body: Node2D) -> void:
	if body is RigidBody2D:
		_is_ball_on_platform = false
		ball_left.emit(body)
		_on_ball_left(body)


func _apply_squash() -> void:
	_squash_scale = Vector2(1.0 + SQUASH_AMOUNT, 1.0 - SQUASH_AMOUNT)


func _emit_land_particles(ball: Node2D) -> void:
	if _particles:
		_particles.position = Vector2(
			ball.global_position.x - global_position.x,
			-platform_size.y / 2.0
		)
		_particles.restart()
		_particles.emitting = true


# ═══════════════════════════════════════════════════════════════════════════════
# VIRTUAL METHODS — Override in subclasses
# ═══════════════════════════════════════════════════════════════════════════════

func _platform_ready() -> void:
	pass

func _platform_process(_delta: float) -> void:
	pass

func _platform_physics_process(_delta: float) -> void:
	pass

func _on_ball_landed(_ball: RigidBody2D) -> void:
	pass

func _on_ball_left(_ball: RigidBody2D) -> void:
	pass


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

func activate() -> void:
	is_active = true
	_collision_shape.disabled = false
	platform_activated.emit()

func deactivate() -> void:
	is_active = false
	_collision_shape.disabled = true
	platform_deactivated.emit()

func set_platform_color(color: Color) -> void:
	platform_color = color
	outline_color = color.darkened(0.3)
	particle_color = Color(color.r, color.g, color.b, 0.6)

func get_surface_center() -> Vector2:
	return global_position + Vector2(0, -platform_size.y / 2.0)

func get_surface_rect() -> Rect2:
	return Rect2(
		global_position - platform_size / 2.0,
		platform_size
	)

func resize(new_size: Vector2) -> void:
	platform_size = new_size
	if _shape_rect:
		_shape_rect.size = new_size
	queue_redraw()

func flash(duration: float = 0.2) -> void:
	_flash_timer = duration

func get_platform_info() -> Dictionary:
	return {
		"type": PlatformType.keys()[platform_type],
		"size": platform_size,
		"position": global_position,
		"active": is_active,
		"ball_on": _is_ball_on_platform,
	}
