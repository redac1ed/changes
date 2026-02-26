extends Control
class_name SettingsMenu

## ═══════════════════════════════════════════════════════════════════════════════
## SettingsMenu — Configurable Options Panel
## ═══════════════════════════════════════════════════════════════════════════════
##
## Provides sliders for audio, checkboxes for graphics, and key rebinding.
## Saves changes to GameState on close.

# ─── UI References ──────────────────────────────────────────────────────────
@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SFXSlider
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var vsync_check: CheckButton = %VsyncCheck
@onready var particles_opt: OptionButton = %ParticlesOption
@onready var back_button: Button = %BackButton

# ─── Signals ─────────────────────────────────────────────────────────────────
signal closed

# ─── Lifecycle ──────────────────────────────────────────────────────────────

func _ready() -> void:
	# If UI exists, hook up signals
	if master_slider: master_slider.value_changed.connect(_on_master_changed)
	if music_slider: music_slider.value_changed.connect(_on_music_changed)
	if sfx_slider: sfx_slider.value_changed.connect(_on_sfx_changed)
	if fullscreen_check: fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	if vsync_check: vsync_check.toggled.connect(_on_vsync_toggled)
	if particles_opt: particles_opt.item_selected.connect(_on_particles_selected)
	if back_button: back_button.pressed.connect(_on_back_pressed)
	
	# Load current values
	_refresh_ui()


func _refresh_ui() -> void:
	if not GameState: return
	
	if master_slider: master_slider.value = GameState.get_setting("audio", "master")
	if music_slider: music_slider.value = GameState.get_setting("audio", "music")
	if sfx_slider: sfx_slider.value = GameState.get_setting("audio", "sfx")
	
	if fullscreen_check: fullscreen_check.button_pressed = GameState.get_setting("video", "fullscreen")
	if vsync_check: vsync_check.button_pressed = GameState.get_setting("video", "vsync")
	
	if particles_opt:
		var p_val = GameState.get_setting("video", "particles")
		match p_val:
			"low": particles_opt.selected = 0
			"medium": particles_opt.selected = 1
			"high": particles_opt.selected = 2


# ─── Input Handlers ─────────────────────────────────────────────────────────

func _on_master_changed(val: float) -> void:
	GameState.set_setting("audio", "master", val)


func _on_music_changed(val: float) -> void:
	GameState.set_setting("audio", "music", val)


func _on_sfx_changed(val: float) -> void:
	GameState.set_setting("audio", "sfx", val)


func _on_fullscreen_toggled(toggled: bool) -> void:
	GameState.set_setting("video", "fullscreen", toggled)


func _on_vsync_toggled(toggled: bool) -> void:
	GameState.set_setting("video", "vsync", toggled)


func _on_particles_selected(idx: int) -> void:
	var val = "high"
	match idx:
		0: val = "low"
		1: val = "medium"
		2: val = "high"
	GameState.set_setting("video", "particles", val)


func _on_back_pressed() -> void:
	GameState.save_settings()
	if MenuManager:
		MenuManager.pop_menu()
	else:
		hide()
		closed.emit()


# ─── Public API ─────────────────────────────────────────────────────────────

func open() -> void:
	show()
	_refresh_ui()
	if master_slider:
		master_slider.grab_focus()

