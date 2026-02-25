extends Node2D

## ═══════════════════════════════════════════════════════════════════════════════
## ShowcaseLevel — Demo level that exhibits every new gameplay system
## ═══════════════════════════════════════════════════════════════════════════════
##
## A wide scrolling level divided into themed sections:
##   Section 1 — START / Basic Platforms + Coins
##   Section 2 — Special Platforms (ice, conveyor, bounce, crumbling)
##   Section 3 — Hazard Gauntlet (spikes, saw, fire jets, laser)
##   Section 4 — Enemy Encounter (walker, flyer, turret)
##   Section 5 — Finale (disappearing path, acid, door)
##
## Level bounds: 4800×800  •  Camera scrolls right as ball progresses

const SCREEN_W := 1200.0
const SCREEN_H := 800.0
const LEVEL_W := 4800.0
const LEVEL_H := 800.0

# ── Resources ────────────────────────────────────────────────────────────────
var ball_scene: PackedScene = preload("res://scenes/ball.tscn")

# ── Runtime ──────────────────────────────────────────────────────────────────
var ball: RigidBody2D
var camera: Camera2D
var hud: GameHUD
var pause_overlay: PauseOverlay
var complete_screen: LevelCompleteScreen
var transition_fx: SceneTransitionFX
var builder: LevelBuilder

var level_complete: bool = false
var level_time: float = 0.0
var coins_collected: int = 0
var total_coins: int = 0
var deaths: int = 0
var _restart_cooldown: float = 0.0
var _spawn_position: Vector2 = Vector2(120, 620)

var world_number: int = 1
var level_number: int = 99


# ═══════════════════════════════════════════════════════════════════════════════
#  LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	print("[ShowcaseLevel] Initializing showcase / demo level")
	
	# ── Builder ─────────────────────────────────────────────────────────────
	builder = LevelBuilder.new()
	builder.set_level(self)
	add_child(builder)
	
	# ── Background ──────────────────────────────────────────────────────────
	var bg := ParallaxDecoration.create_for_world(1)
	add_child(bg)
	move_child(bg, 0)
	
	# ── Ball ────────────────────────────────────────────────────────────────
	var spawn := Marker2D.new()
	spawn.name = "BallSpawn"
	spawn.position = _spawn_position
	add_child(spawn)
	
	ball = ball_scene.instantiate()
	ball.position = _spawn_position
	ball.world_bounds = Rect2(0, 0, LEVEL_W, LEVEL_H)
	add_child(ball)
	if ball.has_signal("shot_fired"):
		ball.shot_fired.connect(_on_shot_fired)
	
	# ── Camera ──────────────────────────────────────────────────────────────
	var cam_script := load("res://scripts/game_camera_enhanced.gd")
	if not cam_script:
		cam_script = load("res://scripts/game_camera_advanced.gd")
	camera = Camera2D.new()
	if cam_script:
		camera.set_script(cam_script)
	camera.world_bounds = Rect2(0, 0, LEVEL_W, LEVEL_H)
	camera.use_limits = true
	if "center_if_undersized" in camera:
		camera.center_if_undersized = true
	elif "center_if_missized" in camera:
		camera.center_if_missized = true
	camera.global_position = ball.global_position
	add_child(camera)
	camera.make_current()
	if "target_path" in camera:
		camera.target_path = camera.get_path_to(ball)
	
	# ── HUD ─────────────────────────────────────────────────────────────────
	hud = GameHUD.new()
	add_child(hud)
	
	# ── Pause ───────────────────────────────────────────────────────────────
	pause_overlay = PauseOverlay.new()
	pause_overlay.restarted.connect(_restart_level)
	pause_overlay.quit_to_menu.connect(_quit_to_menu)
	add_child(pause_overlay)
	
	# ── Level Complete ──────────────────────────────────────────────────────
	complete_screen = LevelCompleteScreen.new()
	complete_screen.next_level_pressed.connect(_next_level)
	complete_screen.retry_pressed.connect(_restart_level)
	complete_screen.menu_pressed.connect(_quit_to_menu)
	add_child(complete_screen)
	
	# ── Transitions ─────────────────────────────────────────────────────────
	transition_fx = SceneTransitionFX.new()
	add_child(transition_fx)
	
	# ═══════════════════════════════════════════════════════════════════════════
	#  BUILD THE LEVEL
	# ═══════════════════════════════════════════════════════════════════════════
	_build_ground()
	_build_section_1_platforms()
	_build_section_2_special()
	_build_section_3_hazards()
	_build_section_4_enemies()
	_build_section_5_finale()
	_build_decorations()
	
	# Count coins
	total_coins = _count_coins()
	hud.total_coins_in_level = total_coins
	hud.set_level_info(world_number, level_number)
	
	# Transition in
	transition_fx.play_out(SceneTransitionFX.TransitionType.CIRCLE_WIPE, 0.7)
	
	print("[ShowcaseLevel] Ready — %d coins placed" % total_coins)


func _process(delta: float) -> void:
	if level_complete:
		return
	if _restart_cooldown > 0:
		_restart_cooldown -= delta
	level_time += delta


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				if _restart_cooldown <= 0 and not level_complete:
					_restart_level()
			KEY_ENTER:
				if level_complete:
					_next_level()


# ═══════════════════════════════════════════════════════════════════════════════
#  SECTION BUILDERS
# ═══════════════════════════════════════════════════════════════════════════════

func _build_ground() -> void:
	# Main ground runs the entire level width
	builder.add_static_platform(
		Vector2(LEVEL_W / 2.0, LEVEL_H - 10),
		Vector2(LEVEL_W, 20),
		Color(0.28, 0.36, 0.24)
	)
	# Grass stripe
	builder.add_decoration_rect(
		Vector2(LEVEL_W / 2.0, LEVEL_H - 22),
		Vector2(LEVEL_W, 4),
		Color(0.42, 0.72, 0.28)
	)
	# Boundary walls + ceiling
	builder.add_boundary_walls(Rect2(0, 0, LEVEL_W, LEVEL_H))


# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 1  —  Starting area + basic platforms + first coins   (x: 0–1000)
# ──────────────────────────────────────────────────────────────────────────────

func _build_section_1_platforms() -> void:
	# Spawn platform (wide, safe)
	builder.add_static_platform(Vector2(120, 650), Vector2(200, 16), Color(0.38, 0.52, 0.32))
	
	# Stepping-stone platforms (ascending right)
	builder.add_static_platform(Vector2(320, 580), Vector2(100, 14), Color(0.42, 0.56, 0.35))
	builder.add_static_platform(Vector2(500, 520), Vector2(100, 14), Color(0.42, 0.56, 0.35))
	builder.add_static_platform(Vector2(680, 470), Vector2(120, 14), Color(0.42, 0.56, 0.35))
	
	# Coins leading the path
	builder.add_coin_line(Vector2(300, 560), Vector2(500, 500), 4)
	builder.add_coin_line(Vector2(500, 500), Vector2(680, 450), 3)
	
	# One-way pass-through platform above spawn
	builder.add_one_way_platform(Vector2(200, 550), Vector2(80, 8))
	
	# Gold coin reward for exploring up
	builder.add_coin(Vector2(200, 520), 2)  # GOLD
	
	# Bridge to section 2
	builder.add_static_platform(Vector2(880, 450), Vector2(160, 16), Color(0.38, 0.52, 0.32))
	builder.add_coin_line(Vector2(800, 430), Vector2(960, 430), 4)
	
	# Section label decoration
	_add_section_label(Vector2(100, 400), "SECTION 1: BASICS")
	
	# First checkpoint (safe landing before section 2)
	builder.add_checkpoint(Vector2(880, 430))


# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 2  —  Special platforms showcase   (x: 1000–2200)
# ──────────────────────────────────────────────────────────────────────────────

func _build_section_2_special() -> void:
	_add_section_label(Vector2(1020, 350), "SECTION 2: PLATFORMS")
	
	# ── Moving platform (horizontal shuttle) ──
	builder.add_moving_platform(
		Vector2(1050, 500),
		Vector2(1250, 500),
		Vector2(80, 14), 60.0
	)
	
	# Coins riding the moving platform path
	builder.add_coin_line(Vector2(1050, 475), Vector2(1250, 475), 3)
	
	# ── Ice platform (slippery!) ──
	builder.add_ice_platform(Vector2(1350, 480), Vector2(140, 14))
	builder.add_coin(Vector2(1350, 455))
	
	# ── Bounce platform (launches ball upward) ──
	builder.add_bounce_platform(Vector2(1500, 580), Vector2(80, 16), 900.0)
	builder.add_coin_arc(Vector2(1500, 420), 60, 5, PI, 0.0)  # arc of coins above
	
	# ── Conveyor belt (pushes ball right) ──
	builder.add_conveyor_platform(Vector2(1680, 500), Vector2(160, 16), 120.0, 1.0)
	builder.add_coin_line(Vector2(1610, 475), Vector2(1750, 475), 3)
	
	# ── Crumbling platform (falls after contact) ──
	builder.add_crumbling_platform(Vector2(1880, 480), Vector2(100, 14))
	builder.add_coin(Vector2(1880, 455))
	
	# ── Falling platform ──
	builder.add_falling_platform(Vector2(1980, 450), Vector2(80, 14))
	builder.add_coin(Vector2(1980, 425), 1)  # SILVER
	
	# ── Disappearing platforms (tricky timing) ──
	builder.add_disappearing_platform(Vector2(2080, 500), Vector2(70, 12), 2.0, 1.2)
	builder.add_disappearing_platform(Vector2(2160, 480), Vector2(70, 12), 2.0, 1.2)
	
	# Landing platform + checkpoint before hazards
	builder.add_static_platform(Vector2(2280, 480), Vector2(140, 16), Color(0.38, 0.52, 0.32))
	builder.add_checkpoint(Vector2(2280, 460))
	
	# ── Weighted platform (tilts) ──
	builder.add_weighted_platform(Vector2(2080, 600), Vector2(120, 14))


# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 3  —  Hazard gauntlet   (x: 2300–3300)
# ──────────────────────────────────────────────────────────────────────────────

func _build_section_3_hazards() -> void:
	_add_section_label(Vector2(2320, 350), "SECTION 3: HAZARDS")
	
	# ── Floor spikes ──
	builder.add_spikes(Vector2(2450, 770), 100.0)
	# Safe platform arc over spikes
	builder.add_static_platform(Vector2(2400, 550), Vector2(80, 14), Color(0.45, 0.4, 0.35))
	builder.add_static_platform(Vector2(2500, 520), Vector2(80, 14), Color(0.45, 0.4, 0.35))
	builder.add_coin_line(Vector2(2400, 530), Vector2(2500, 500), 3)
	
	# ── Saw blade on a path ──
	var saw_path: Array[Vector2] = [Vector2(0, 0), Vector2(0, -150)]
	builder.add_saw_blade(Vector2(2600, 650), 18.0, saw_path)
	builder.add_static_platform(Vector2(2620, 500), Vector2(90, 14), Color(0.45, 0.4, 0.35))
	builder.add_coin(Vector2(2620, 475), 1)  # SILVER
	
	# ── Fire jets (timed burst from floor) ──
	builder.add_fire_jet(Vector2(2720, 770), Vector2.UP, 130.0)
	# Platform to help skip over
	builder.add_static_platform(Vector2(2720, 480), Vector2(70, 14), Color(0.5, 0.38, 0.3))
	builder.add_coin(Vector2(2720, 455))
	
	# ── Laser beam (horizontal toggle) ──
	builder.add_laser(Vector2(2830, 550), Vector2.RIGHT, 150.0)
	# Go above or below
	builder.add_static_platform(Vector2(2900, 500), Vector2(100, 14), Color(0.45, 0.4, 0.35))
	builder.add_static_platform(Vector2(2900, 620), Vector2(100, 14), Color(0.45, 0.4, 0.35))
	builder.add_coin(Vector2(2900, 475))
	builder.add_coin(Vector2(2900, 595), 2)  # GOLD (risky lower path)
	
	# ── Crusher from ceiling ──
	builder.add_crusher(Vector2(3050, 200), Vector2(60, 50))
	builder.add_static_platform(Vector2(3050, 550), Vector2(80, 14), Color(0.45, 0.4, 0.35))
	builder.add_coin(Vector2(3050, 525))
	
	# ── Acid pool (wide) ──
	builder.add_acid_pool(Vector2(3200, 770), Vector2(160, 20))
	# Platforms to cross over acid
	builder.add_static_platform(Vector2(3140, 550), Vector2(60, 14), Color(0.45, 0.4, 0.35))
	builder.add_static_platform(Vector2(3260, 550), Vector2(60, 14), Color(0.45, 0.4, 0.35))
	builder.add_coin_arc(Vector2(3200, 480), 50, 3)
	
	# Safe zone + checkpoint before enemies
	builder.add_static_platform(Vector2(3380, 500), Vector2(140, 16), Color(0.38, 0.52, 0.32))
	builder.add_checkpoint(Vector2(3380, 480))
	
	# Diamond coin secret below hazards section
	builder.add_coin(Vector2(3200, 720), 3)  # DIAMOND — risky grab above acid


# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 4  —  Enemy encounters   (x: 3400–4200)
# ──────────────────────────────────────────────────────────────────────────────

func _build_section_4_enemies() -> void:
	_add_section_label(Vector2(3420, 380), "SECTION 4: ENEMIES")
	
	# Wide arena platform
	builder.add_static_platform(Vector2(3600, 560), Vector2(300, 16), Color(0.42, 0.38, 0.5))
	
	# ── Walker enemy on platform ──
	builder.add_walker_enemy(Vector2(3600, 540), 120.0)
	builder.add_coin_line(Vector2(3480, 535), Vector2(3720, 535), 5)
	
	# Second platform with flyer
	builder.add_static_platform(Vector2(3850, 500), Vector2(180, 16), Color(0.42, 0.38, 0.5))
	
	# ── Flying enemy above ──
	builder.add_flyer_enemy(Vector2(3850, 400), 100.0)
	builder.add_coin(Vector2(3850, 380), 1)  # SILVER guarded by flyer
	
	# Turret tower
	builder.add_static_platform(Vector2(4050, 460), Vector2(50, 14), Color(0.5, 0.35, 0.35))
	builder.add_static_platform(Vector2(4050, 560), Vector2(60, 120), Color(0.4, 0.35, 0.45))
	
	# ── Turret on tower ──
	builder.add_turret_enemy(Vector2(4050, 440))
	
	# Approach platforms (player needs to dodge turret shots)
	builder.add_static_platform(Vector2(3980, 550), Vector2(80, 14), Color(0.42, 0.38, 0.5))
	builder.add_static_platform(Vector2(4130, 500), Vector2(90, 14), Color(0.42, 0.38, 0.5))
	
	# Coins near turret (risk/reward)
	builder.add_coin(Vector2(4050, 420), 2)  # GOLD on turret
	builder.add_coin_line(Vector2(4090, 480), Vector2(4170, 480), 3)
	
	# Safe landing + checkpoint
	builder.add_static_platform(Vector2(4250, 500), Vector2(140, 16), Color(0.38, 0.52, 0.32))
	builder.add_checkpoint(Vector2(4250, 480))


# ──────────────────────────────────────────────────────────────────────────────
#  SECTION 5  —  Finale: disappearing path → door   (x: 4250–4700)
# ──────────────────────────────────────────────────────────────────────────────

func _build_section_5_finale() -> void:
	_add_section_label(Vector2(4280, 380), "SECTION 5: FINALE")
	
	# Disappearing platform gauntlet (timed jumps)
	builder.add_disappearing_platform(Vector2(4380, 480), Vector2(60, 12), 1.8, 1.0)
	builder.add_disappearing_platform(Vector2(4440, 460), Vector2(60, 12), 1.8, 1.0)
	builder.add_disappearing_platform(Vector2(4500, 440), Vector2(60, 12), 1.8, 1.0)
	
	# Coins along the disappearing path
	builder.add_coin(Vector2(4380, 455))
	builder.add_coin(Vector2(4440, 435))
	builder.add_coin(Vector2(4500, 415), 1)  # SILVER
	
	# Bounce pad to reach high platform
	builder.add_bounce_platform(Vector2(4560, 580), Vector2(60, 14), 1000.0)
	
	# High goal platform
	builder.add_static_platform(Vector2(4650, 350), Vector2(160, 16), Color(0.35, 0.55, 0.4))
	
	# Final coin arc over the door
	builder.add_coin_arc(Vector2(4650, 280), 50, 5, PI, 0.0, 2)  # GOLD arc
	
	# ── The Door ──
	builder.add_door(Vector2(4650, 330))
	
	# Diamond coin — hidden below the finale, hard to reach
	builder.add_coin(Vector2(4600, 700), 3)  # DIAMOND secret


# ──────────────────────────────────────────────────────────────────────────────
#  DECORATIONS
# ──────────────────────────────────────────────────────────────────────────────

func _build_decorations() -> void:
	# Section divider lines (visual only)
	for x_div in [1000.0, 2300.0, 3400.0, 4250.0]:
		_add_divider(x_div)
	
	# Scattered bushes / rocks near ground
	var bush_positions := [240.0, 600.0, 1100.0, 1500.0, 1900.0, 2600.0, 3000.0, 3500.0, 4000.0, 4400.0]
	for bx in bush_positions:
		var bw := randf_range(24, 48)
		var bh := randf_range(12, 24)
		var c := Color(0.3, 0.55, 0.25, 0.4)
		builder.add_decoration_rect(
			Vector2(bx, LEVEL_H - 30 - bh / 2.0),
			Vector2(bw, bh), c
		)
	
	# Floating particles / motes (small white dots)
	for i in range(20):
		var mx := randf_range(50, LEVEL_W - 50)
		var my := randf_range(60, LEVEL_H - 120)
		builder.add_decoration_rect(
			Vector2(mx, my),
			Vector2(3, 3),
			Color(1, 1, 1, randf_range(0.08, 0.18))
		)


# ═══════════════════════════════════════════════════════════════════════════════
#  LEVEL EVENTS
# ═══════════════════════════════════════════════════════════════════════════════

func _on_shot_fired(_count: int) -> void:
	if hud:
		hud.add_shot()
	if GameState:
		GameState.add_shots(1)


func complete_level() -> void:
	if level_complete:
		return
	level_complete = true
	
	var shots: int = ball.shot_count if ball else 0
	var result: Dictionary = {}
	if GameState:
		result = GameState.complete_level(world_number, level_number, shots)
	
	var stars: int = result.get("stars", 0)
	var is_new_record: bool = result.get("is_new_record", false)
	
	if complete_screen:
		complete_screen.show_screen(shots, stars, coins_collected, total_coins, is_new_record, level_time)
	if hud:
		hud.show_notification("Level Complete!", Color(0.3, 0.9, 0.45))


func on_goal_reached(body: Node2D) -> void:
	if body == ball:
		complete_level()


func on_coin_collected(coin_value: int) -> void:
	coins_collected += 1
	if hud:
		hud.add_coin(coin_value)


func reset_ball() -> void:
	if not ball:
		return
	deaths += 1
	
	# Find active checkpoint
	var checkpoint_pos := _spawn_position
	for child in get_children():
		if child is Checkpoint and child._is_activated:
			checkpoint_pos = child.global_position + Vector2(0, -15)
			break
	
	ball.global_position = checkpoint_pos
	ball.linear_velocity = Vector2.ZERO
	ball.angular_velocity = 0.0
	
	if camera and "add_trauma" in camera:
		camera.add_trauma(0.3)
	if hud:
		hud.show_notification("Respawned", Color(0.9, 0.5, 0.2))


func _restart_level() -> void:
	_restart_cooldown = 0.5
	if transition_fx:
		transition_fx.play(SceneTransitionFX.TransitionType.FADE, 0.5, func():
			get_tree().reload_current_scene()
		)
	else:
		get_tree().reload_current_scene()


func _next_level() -> void:
	_restart_cooldown = 0.5
	if transition_fx:
		transition_fx.play(SceneTransitionFX.TransitionType.CIRCLE_WIPE, 0.8, func():
			LevelManager.load_next_level()
		)
	else:
		LevelManager.load_next_level()


func _quit_to_menu() -> void:
	if transition_fx:
		transition_fx.play(SceneTransitionFX.TransitionType.CURTAIN, 0.6, func():
			get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
		)
	else:
		get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")


# ═══════════════════════════════════════════════════════════════════════════════
#  HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _add_section_label(pos: Vector2, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(label)


func _add_divider(x: float) -> void:
	var script := load("res://scripts/levels/divider_draw.gd")
	if script:
		var line := Node2D.new()
		line.position = Vector2(x, 0)
		line.set_script(script)
		line.set_meta("height", LEVEL_H)
		add_child(line)


func _count_coins() -> int:
	var count := 0
	for child in get_children():
		if child is CoinCollectible:
			count += 1
		for grandchild in child.get_children():
			if grandchild is CoinCollectible:
				count += 1
	return count
