extends LevelTemplate

func _ready() -> void:
	super._ready()
	if hud:
		hud.show_notification("Level 1", Color(0.5, 0.9, 0.7))

func _play_world_music() -> void:
	if not AudioManager:
		return
	var track: String = AudioManager.WORLD_MUSIC.get(world_number,
			"res://assets/audio/music/meadow_theme.ogg")
	AudioManager.play_music(track)
