extends LevelTemplate

func get_custom_star_rules() -> Dictionary:
	return {
		"three_shots": 2, "three_time": 18.0,
		"two_shots": 4,   "two_time": 30.0,
		"one_shots": 7
	}

func _ready() -> void:
	super._ready()
	if hud:
		hud.show_notification("Level 2", Color(0.5, 0.9, 0.7))

func _play_world_music() -> void:
	if not AudioManager:
		return
	var track: String = AudioManager.WORLD_MUSIC.get(world_number,
			"res://assets/audio/music/meadow_theme.ogg")
	AudioManager.play_music(track)
