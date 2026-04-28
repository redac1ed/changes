extends LevelTemplate

const SUBTITLE_INTRO_1 := "Hey there, I'll be helping you out in the 'game'. Drag the ball to move."
const SUBTITLE_INTRO_2 := "Sorry, its just that no one has played the game in a long time."
var _subtitles: SubtitleOverlay

func get_custom_star_rules() -> Dictionary:
	return {
		"three_shots": 4, "three_time": 3600.0,
		"two_shots": 7,   "two_time": 3600.0,
		"one_shots": 10
	}

func _ready() -> void:
	_subtitles = SubtitleOverlay.new()
	add_child(_subtitles)
	super._ready()
	if hud:
		hud.show_notification("Level 1", Color(0.4, 0.8, 0.5))

func _play_world_music() -> void:
	if not AudioManager:
		return
	var intro2: AudioStream = load("res://assets/audio/intro_1.mp3")
	var intro1: AudioStream = load("res://assets/audio/intro_2.mp3")
	if not intro1 or not intro2:
		AudioManager.play_music("res://assets/audio/music/meadow_theme.ogg")
		return
	AudioManager.stop_music(0.0)
	var player := AudioStreamPlayer.new()
	player.bus = "Music"
	add_child(player)
	player.stream = intro1
	player.play()
	_subtitles.show_line(SUBTITLE_INTRO_1)
	player.finished.connect(func():
		_subtitles.hide_line()
		player.stream = intro2
		player.play()
		_subtitles.show_line(SUBTITLE_INTRO_2)
		player.finished.connect(func():
			_subtitles.hide_line()
			player.queue_free()
			if AudioManager:
				var track: String = AudioManager.WORLD_MUSIC.get(world_number,
						"res://assets/audio/music/meadow_theme.ogg")
				AudioManager.play_music(track)
		, CONNECT_ONE_SHOT)
	, CONNECT_ONE_SHOT)
