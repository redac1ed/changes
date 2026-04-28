extends LevelTemplate

const SUBTITLE_VICTORY_1 := "Good job!"
const SUBTITLE_VICTORY_2 := "Nice! Keep going."
const SUBTITLE_DEATH_1 := "Are you that bad? This game is SO easy!"
const SUBTITLE_DEATH_2 := "I.. don't even know what to say."

var _subtitles: SubtitleOverlay

func get_custom_star_rules() -> Dictionary:
	return {
		"three_shots": 15, "three_time": 3600.0,
		"two_shots": 18,   "two_time": 3600.0,
		"one_shots": 20
	}

func _ready() -> void:
	_subtitles = SubtitleOverlay.new()
	add_child(_subtitles)
	super._ready()
	if hud:
		hud.show_notification("Level 3", Color(0.5, 0.9, 0.7))
	_play_random_victory_audio()

func _play_random_victory_audio() -> void:
	var victory_player := AudioStreamPlayer.new()
	victory_player.bus = "UI"
	add_child(victory_player)
	var use_intro_3 = randf() < 0.5
	victory_player.stream = load("res://assets/audio/intro_3.mp3" if use_intro_3 else "res://assets/audio/intro_4.mp3")
	var victory_subtitle = SUBTITLE_VICTORY_1 if use_intro_3 else SUBTITLE_VICTORY_2
	victory_player.play()
	_subtitles.show_line(victory_subtitle)
	victory_player.finished.connect(func():
		_subtitles.hide_line()
		victory_player.queue_free()
	, CONNECT_ONE_SHOT)

func _play_world_music() -> void:
	if not AudioManager:
		return
	var track: String = AudioManager.WORLD_MUSIC.get(world_number,
			"res://assets/audio/music/meadow_theme.ogg")
	AudioManager.play_music(track)

func _build_level() -> void:
	super._build_level()
	for trap in get_tree().get_nodes_in_group("traps"):
		if trap.has_signal("ball_killed"):
			trap.ball_killed.connect(_on_ball_killed)

func _on_ball_killed(_ball: Node2D) -> void:
	var death_player := AudioStreamPlayer.new()
	death_player.bus = "UI"
	add_child(death_player)
	var use_intro_5 := randf() < 0.5
	death_player.stream = load("res://assets/audio/intro_5.mp3" if use_intro_5 else "res://assets/audio/intro_6.mp3")
	_subtitles.show_line(SUBTITLE_DEATH_1 if use_intro_5 else SUBTITLE_DEATH_2)
	death_player.play()
	death_player.finished.connect(func():
		_subtitles.hide_line()
		death_player.queue_free()
	, CONNECT_ONE_SHOT)
