extends LevelTemplate

func _ready() -> void:
	super._ready()
	if hud:
		hud.show_notification("Welcome to Meadow!", Color(0.4, 0.8, 0.5))

func _play_world_music() -> void:
	# Play intro_1 → intro_2 on entry, then start the normal looping world music.
	if not AudioManager:
		return
	var intro2: AudioStream = load("res://assets/audio/intro_2.mp3")
	var intro1: AudioStream = load("res://assets/audio/intro_1.mp3")
	if not intro1 or not intro2:
		# Fall back to regular music if intros are missing
		AudioManager.play_music("res://assets/audio/music/meadow_theme.ogg")
		return

	AudioManager.stop_music(0.0)
	var player := AudioStreamPlayer.new()
	player.bus = "Music"
	add_child(player)
	player.stream = intro1
	player.play()

	player.finished.connect(func():
		player.stream = intro2
		player.play()
		player.finished.connect(func():
			player.queue_free()
			if AudioManager:
				var track: String = AudioManager.WORLD_MUSIC.get(world_number,
						"res://assets/audio/music/meadow_theme.ogg")
				AudioManager.play_music(track)
		, CONNECT_ONE_SHOT)
	, CONNECT_ONE_SHOT)
