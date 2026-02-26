extends Node
class_name PlayerSkinManager

## ═══════════════════════════════════════════════════════════════════════════════
## PlayerSkinManager — Cosmetic Customization
## ═══════════════════════════════════════════════════════════════════════════════
##
## Handles loading and applying skins to the player ball.
## Supports texture-based skins, shader parameters, and trail effects.

# ─── Skin Definitions ───────────────────────────────────────────────────────
const SKINS: Dictionary = {
	"default": {
		"color": Color(0.95, 0.88, 0.72),
		"highlight": Color(1.0, 0.97, 0.92),
		"outline": Color(0.6, 0.52, 0.38),
		"texture": null,
		"trail_color": Color(1.0, 1.0, 1.0, 0.5)
	},
	"magma": {
		"color": Color(0.8, 0.2, 0.1),
		"highlight": Color(1.0, 0.6, 0.2),
		"outline": Color(0.3, 0.05, 0.05),
		"texture": "res://assets/sprites/skins/magma.png",
		"trail_color": Color(1.0, 0.4, 0.0, 0.6),
		"shader": "magma_shader"
	},
	"ice": {
		"color": Color(0.4, 0.7, 0.9),
		"highlight": Color(0.8, 0.9, 1.0),
		"outline": Color(0.2, 0.4, 0.6),
		"trail_color": Color(0.5, 0.8, 1.0, 0.6)
	},
	"gold": {
		"color": Color(1.0, 0.84, 0.0),
		"highlight": Color(1.0, 1.0, 0.6),
		"outline": Color(0.6, 0.4, 0.0),
		"trail_color": Color(1.0, 0.9, 0.2, 0.8),
		"shininess": 1.0
	},
	"void": {
		"color": Color(0.1, 0.0, 0.2),
		"highlight": Color(0.3, 0.0, 0.5),
		"outline": Color(0.5, 0.0, 0.8),
		"trail_color": Color(0.4, 0.0, 0.8, 0.5)
	}
}

# ─── State ───────────────────────────────────────────────────────────────────
var _player: Node2D
var _current_skin_id: String = "default"

# ─── Public API ─────────────────────────────────────────────────────────────

func setup(player_node: Node2D) -> void:
	_player = player_node
	
	# Listen for skin changes
	if GameState:
		GameState.state_changed.connect(_on_state_changed)
		apply_skin(GameState._save_data.unlockables.active_skin)
	else:
		apply_skin("default")


func apply_skin(skin_id: String) -> void:
	if not SKINS.has(skin_id):
		skin_id = "default"
	
	_current_skin_id = skin_id
	var data = SKINS[skin_id]
	
	# Apply to player properties (assuming player has these vars)
	if "ball_color" in _player:
		_player.ball_color = data.color
	if "highlight_color" in _player:
		_player.highlight_color = data.highlight
	if "outline_color" in _player:
		_player.outline_color = data.outline
	
	# Apply trail color
	if "trail_color" in _player:
		_player.trail_color = data.get("trail_color", Color.WHITE)
	
	# Handle texture
	var sprite = _player.get_node_or_null("Sprite2D")
	if sprite:
		if data.texture:
			# sprite.texture = load(data.texture)
			pass # Placeholder for actual resource loading
		else:
			sprite.texture = null
	
	_player.queue_redraw()
	print("[SkinManager] Applied skin: %s" % skin_id)


func _on_state_changed(what: String, value: Variant) -> void:
	if what == "equip_skins":
		apply_skin(str(value))

