extends Area2D

@export var button_pressed = false

func _ready() -> void:
	collision_mask = 2
	self.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("ball"):
		var sprite := get_parent()
		button_pressed = true
		sprite.texture = load("res://assets/buttons/on.png")
