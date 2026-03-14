shader_type canvas_item;

// Color range we want to target (the current green)
uniform vec3 target_color : source_color = vec3(0.55, 0.75, 0.20);
// New color for that range (lava edge)
uniform vec3 replace_color : source_color = vec3(1.0, 0.45, 0.05);
// How wide the match is; higher = grabs more colors
uniform float tolerance : hint_range(0.0, 1.0) = 0.25;

// Optional: overall tint for the rest (your existing volcanic feel)
uniform vec3 global_tint : source_color = vec3(1.0, 0.35, 0.05);
uniform float global_intensity : hint_range(0.0, 1.0) = 0.6;
uniform float brightness : hint_range(0.2, 1.5) = 0.8;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // Distance from this pixel to the target green
    float d = distance(tex.rgb, target_color);

    vec3 base = tex.rgb * brightness;

    // First apply global lava tint
    vec3 tinted = mix(base, global_tint, global_intensity);

    // Then, if this pixel is close to the green rim, force it to lava edge color
    if (d < tolerance) {
        tinted = mix(tinted, replace_color, 1.0);
    }

    COLOR = vec4(tinted, tex.a);
}
