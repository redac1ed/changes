extends Node2D

## Simple vertical dashed-line divider used by ShowcaseLevel

func _draw() -> void:
	var h: float = get_meta("height", 800.0)
	var dash_len := 8.0
	var gap_len := 6.0
	var y := 0.0
	var col := Color(1, 1, 1, 0.12)
	while y < h:
		var end_y := minf(y + dash_len, h)
		draw_line(Vector2(0, y), Vector2(0, end_y), col, 1.0)
		y = end_y + gap_len
