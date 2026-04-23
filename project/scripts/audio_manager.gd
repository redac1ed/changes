extends Node

const MASTER_BUS := "Master"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const UI_BUS := "UI"

var master_volume: float = 1.0:
	set(value):
		master_volume = clampf(value, 0.0, 1.0)
		_apply_bus_volume(MASTER_BUS, master_volume)
		settings_changed.emit()

var music_volume: float = 0.7:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
		_apply_bus_volume(MUSIC_BUS, music_volume)
		settings_changed.emit()

var sfx_volume: float = 0.8:
	set(value):
		sfx_volume = clampf(value, 0.0, 1.0)
		_apply_bus_volume(SFX_BUS, sfx_volume)
		settings_changed.emit()

var ui_volume: float = 0.6:
	set(value):
		ui_volume = clampf(value, 0.0, 1.0)
		_apply_bus_volume(UI_BUS, ui_volume)
		settings_changed.emit()

var music_muted: bool = false:
	set(value):
		music_muted = value
		AudioServer.set_bus_mute(_get_bus_index(MUSIC_BUS), value)
		settings_changed.emit()

var sfx_muted: bool = false:
	set(value):
		sfx_muted = value
		AudioServer.set_bus_mute(_get_bus_index(SFX_BUS), value)
		settings_changed.emit()

signal settings_changed
signal music_started(track_name: String)
signal music_stopped
signal sfx_played(sfx_name: String)

var current_music_track: String = ""
var current_music_player: AudioStreamPlayer = null
var music_fade_tween: Tween = null

const SFX_POOL_SIZE := 16
var sfx_pool: Array[AudioStreamPlayer] = []
var sfx_pool_index: int = 0

const WORLD_MUSIC := {
	0: "res://assets/audio/music/tutorial_theme.ogg",
	1: "res://assets/audio/music/meadow_theme.ogg",
	2: "res://assets/audio/music/volcano_theme.ogg",
	3: "res://assets/audio/music/sky_theme.ogg",
	4: "res://assets/audio/music/ocean_theme.ogg",
	5: "res://assets/audio/music/space_theme.ogg",
	6: "res://assets/audio/music/bonus_theme.ogg",
}

const SFX_LIBRARY := {

	"ball_shoot": "res://assets/audio/sfx/ball_shoot.wav",
	"ball_bounce": "res://assets/audio/sfx/ball_bounce.wav",
	"ball_bounce_soft": "res://assets/audio/sfx/ball_bounce_soft.wav",
	"ball_roll": "res://assets/audio/sfx/ball_roll.wav",

	"goal_reached": "res://assets/audio/sfx/goal_reached.wav",
	"goal_perfect": "res://assets/audio/sfx/goal_perfect.wav",
	"star_collect": "res://assets/audio/sfx/star_collect.wav",

	"lava_sizzle": "res://assets/audio/sfx/lava_sizzle.wav",
	"wind_gust": "res://assets/audio/sfx/wind_gust.wav",
	"water_splash": "res://assets/audio/sfx/water_splash.wav",
	"space_warp": "res://assets/audio/sfx/space_warp.wav",

	"ui_click": "res://assets/audio/sfx/ui_click.wav",
	"ui_hover": "res://assets/audio/sfx/ui_hover.wav",
	"ui_back": "res://assets/audio/sfx/ui_back.wav",
	"ui_confirm": "res://assets/audio/sfx/ui_confirm.wav",
	"ui_pause": "res://assets/audio/sfx/ui_pause.wav",

	"level_complete": "res://assets/audio/sfx/level_complete.wav",
	"level_restart": "res://assets/audio/sfx/level_restart.wav",
	"world_unlock": "res://assets/audio/sfx/world_unlock.wav",
}

var _cached_streams: Dictionary = {}

func _ready() -> void:
	print("[AudioManager] Initializing audio system...")
	_setup_audio_buses()
	_create_sfx_pool()
	_create_music_player()
	_preload_common_sfx()
	print("[AudioManager] Audio system ready")

func _setup_audio_buses() -> void:

	var bus_layout := AudioServer.generate_bus_layout()

	_apply_bus_volume(MASTER_BUS, master_volume)
	_apply_bus_volume(MUSIC_BUS, music_volume)
	_apply_bus_volume(SFX_BUS, sfx_volume)
	_apply_bus_volume(UI_BUS, ui_volume)

func _create_sfx_pool() -> void:
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		sfx_pool.append(player)

func _create_music_player() -> void:
	current_music_player = AudioStreamPlayer.new()
	current_music_player.bus = MUSIC_BUS
	current_music_player.finished.connect(_on_music_finished)
	add_child(current_music_player)

func _preload_common_sfx() -> void:

	var common_sfx := ["ball_shoot", "ball_bounce", "goal_reached", "ui_click"]
	for sfx_name in common_sfx:
		_get_or_load_stream(SFX_LIBRARY.get(sfx_name, ""))

func play_music(track_path: String, fade_in: float = 1.0, loop: bool = true) -> void:
	if track_path == current_music_track and current_music_player.playing:
		return

	var stream := _get_or_load_stream(track_path)
	if not stream:
		push_warning("[AudioManager] Music track not found: %s" % track_path)
		return

	if music_fade_tween and music_fade_tween.is_valid():
		music_fade_tween.kill()

	if current_music_player.playing:
		music_fade_tween = create_tween()
		music_fade_tween.tween_property(current_music_player, "volume_db", -80.0, 0.5)
		music_fade_tween.tween_callback(func():
			current_music_player.stop()
			_start_new_music(stream, fade_in, loop, track_path)
		)
	else:
		_start_new_music(stream, fade_in, loop, track_path)

func _start_new_music(stream: AudioStream, fade_in: float, loop: bool, track_path: String) -> void:
	current_music_player.stream = stream
	current_music_player.volume_db = -80.0 if fade_in > 0 else 0.0
	current_music_player.play()
	current_music_track = track_path

	if fade_in > 0:
		music_fade_tween = create_tween()
		music_fade_tween.tween_property(current_music_player, "volume_db", 0.0, fade_in)

	music_started.emit(track_path.get_file().get_basename())

func stop_music(fade_out: float = 1.0) -> void:
	if not current_music_player.playing:
		return

	if music_fade_tween and music_fade_tween.is_valid():
		music_fade_tween.kill()

	if fade_out > 0:
		music_fade_tween = create_tween()
		music_fade_tween.tween_property(current_music_player, "volume_db", -80.0, fade_out)
		music_fade_tween.tween_callback(func():
			current_music_player.stop()
			current_music_track = ""
			music_stopped.emit()
		)
	else:
		current_music_player.stop()
		current_music_track = ""
		music_stopped.emit()

func pause_music() -> void:
	current_music_player.stream_paused = true

func resume_music() -> void:
	current_music_player.stream_paused = false

func play_world_music(world: int, fade_in: float = 2.0) -> void:
	var track: String = WORLD_MUSIC.get(world, "")
	if track:
		play_music(track, fade_in)

func _on_music_finished() -> void:

	if current_music_track:
		current_music_player.play()

func play_sfx(sfx_name: String, pitch_variation: float = 0.0, volume_offset: float = 0.0) -> void:
	var path: String = SFX_LIBRARY.get(sfx_name, "")
	if path.is_empty():
		push_warning("[AudioManager] Unknown SFX: %s" % sfx_name)
		return

	var stream := _get_or_load_stream(path) as AudioStream
	if not stream:
		return

	var player := _get_available_sfx_player()
	player.stream = stream
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.volume_db = volume_offset
	player.play()

	sfx_played.emit(sfx_name)

func play_sfx_at_position(sfx_name: String, position: Vector2, max_distance: float = 500.0) -> void:

	var camera := get_viewport().get_camera_2d()
	if camera:
		var distance := camera.global_position.distance_to(position)
		var volume_offset := linear_to_db(1.0 - clampf(distance / max_distance, 0.0, 1.0))
		play_sfx(sfx_name, 0.05, volume_offset)
	else:
		play_sfx(sfx_name)

func play_ui_sfx(sfx_name: String) -> void:
	var path: String = SFX_LIBRARY.get(sfx_name, "")
	if path.is_empty():
		return

	var stream := _get_or_load_stream(path) as AudioStream
	if not stream:
		return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = UI_BUS
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()

func _get_available_sfx_player() -> AudioStreamPlayer:

	for player in sfx_pool:
		if not player.playing:
			return player

	var player := sfx_pool[sfx_pool_index]
	sfx_pool_index = (sfx_pool_index + 1) % SFX_POOL_SIZE
	return player

func play_ball_shoot(power_ratio: float) -> void:
	var pitch: float = lerp(0.9, 1.2, power_ratio)
	play_sfx("ball_shoot", 0.05)

func play_ball_bounce(impact_strength: float) -> void:
	if impact_strength < 100:
		play_sfx("ball_bounce_soft", 0.1, -6.0)
	else:
		var volume: float = lerp(-12.0, 0.0, clampf(impact_strength / 500.0, 0.0, 1.0))
		play_sfx("ball_bounce", 0.15, volume)

func play_goal_reached(stars: int) -> void:
	if stars >= 3:
		play_sfx("goal_perfect")
	else:
		play_sfx("goal_reached")

func _get_or_load_stream(path: String) -> AudioStream:
	if path.is_empty():
		return null

	if _cached_streams.has(path):
		var cached: AudioStream = _cached_streams[path]
		return cached

	if ResourceLoader.exists(path):
		var stream: AudioStream = load(path) as AudioStream
		if stream:
			_cached_streams[path] = stream
			return stream

	return null

func preload_sfx(sfx_names: Array) -> void:
	for sfx_name in sfx_names:
		var path: String = SFX_LIBRARY.get(sfx_name, "")
		_get_or_load_stream(path)

func clear_cache() -> void:
	_cached_streams.clear()

func _get_bus_index(bus_name: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		idx = AudioServer.get_bus_index(MASTER_BUS)
	return idx

func _apply_bus_volume(bus_name: String, volume: float) -> void:
	var idx := _get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(volume))

func get_settings() -> Dictionary:
	return {
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"ui_volume": ui_volume,
		"music_muted": music_muted,
		"sfx_muted": sfx_muted,
	}

func apply_settings(settings: Dictionary) -> void:
	master_volume = settings.get("master_volume", 1.0)
	music_volume = settings.get("music_volume", 0.7)
	sfx_volume = settings.get("sfx_volume", 0.8)
	ui_volume = settings.get("ui_volume", 0.6)
	music_muted = settings.get("music_muted", false)
	sfx_muted = settings.get("sfx_muted", false)
