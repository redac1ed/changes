extends Control
class_name SkinPreview

var _skin_id: String = "default"
var _circle: ColorRect
var _highlight: ColorRect

func _ready() -> void:
	if not _circle:
		_create_preview()

func _create_preview() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.2, 0.2, 0.2, 0.5)
	add_child(bg)
	
	# Main ball circle
	_circle = ColorRect.new()
	_circle.custom_minimum_size = Vector2(120, 120)
	_circle.anchor_left = 0.5
	_circle.anchor_top = 0.5
	_circle.anchor_right = 0.5
	_circle.anchor_bottom = 0.5
	_circle.offset_left = -60
	_circle.offset_top = -60
	_circle.offset_right = 60
	_circle.offset_bottom = 60
	add_child(_circle)
	
	# Apply shader for circular appearance
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv);
	
	if (dist > 0.5) {
		discard;
	}
	
	// Create a sphere effect with lighting
	float light = 1.0 - (dist * 0.8);
	light = pow(light, 2.0);
	
	vec3 base_color = texture(TEXTURE, UV).rgb;
	vec3 final_color = base_color * (0.6 + light * 0.4);
	
	COLOR = vec4(final_color, 1.0);
}
"""
	var material = ShaderMaterial.new()
	material.shader = shader
	_circle.material = material

func set_skin(skin_id: String) -> void:
	_skin_id = skin_id
	_update_preview()

func _update_preview() -> void:
	if not _circle:
		return
	
	var skin_data = _get_skin_data(_skin_id)
	if not skin_data:
		return
	
	_circle.color = skin_data.color

func _get_skin_data(skin_id: String) -> Dictionary:
	var skins = {
		"default": {
			"color": Color(0.95, 0.88, 0.72),
			"highlight": Color(1.0, 0.97, 0.92),
			"outline": Color(0.6, 0.52, 0.38),
		},
		"magma": {
			"color": Color(0.8, 0.2, 0.1),
			"highlight": Color(1.0, 0.6, 0.2),
			"outline": Color(0.3, 0.05, 0.05),
		},
		"ice": {
			"color": Color(0.4, 0.7, 0.9),
			"highlight": Color(0.8, 0.9, 1.0),
			"outline": Color(0.2, 0.4, 0.6),
		},
		"gold": {
			"color": Color(1.0, 0.84, 0.0),
			"highlight": Color(1.0, 1.0, 0.6),
			"outline": Color(0.6, 0.4, 0.0),
		},
		"void": {
			"color": Color(0.1, 0.0, 0.2),
			"highlight": Color(0.3, 0.0, 0.5),
			"outline": Color(0.5, 0.0, 0.8),
		}
	}
	return skins.get(skin_id, skins.default)
