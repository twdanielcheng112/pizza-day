extends Area2D

@export_multiline var hint_text := ""

func _ready() -> void:
	add_to_group("interactable")

func interact(player: Node = null) -> void:
	if player and player.has_method("on_wall_hint_read"):
		player.on_wall_hint_read(hint_text)
