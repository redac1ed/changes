extends TileMapLayer



func _process(delta: float) -> void:
	var btn1 = get_node("../button/Area2D")
	var btn2 = get_node("../button2/Area2D")
	var btn3 = get_node("../button3/Area2D")
	var btn4 = get_node("../button4/Area2D")

	var end_hint = get_node("../ending_hint")
	var goal_collision = get_node("../GoalZone/CollisionShape2D")
	var goal = goal_collision.get_parent()

	if btn1.button_pressed and btn2.button_pressed and btn3.button_pressed:
		for i in range(43, 51):
			for j in range(18, 22):
				self.set_cell(Vector2i(i, j), -1, Vector2i(-1, -1))

	if btn4.button_pressed:
		end_hint.visible = true
		goal_collision.disabled = false
		goal.visible = true
