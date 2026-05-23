extends Area2D

func _ready() -> void:
	add_to_group("interactable")

func interact(_player: Node = null) -> void:
	print("interact: %s" % name)
