extends Area2D

@export var exit_type := "false"

func _ready() -> void:
	add_to_group("interactable")

func interact(player: Node = null) -> void:
	if player and player.has_method("on_exit_interacted"):
		player.on_exit_interacted(exit_type)
