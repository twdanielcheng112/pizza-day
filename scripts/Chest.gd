extends Area2D

@onready var _sprite: Sprite2D = $Sprite2D

var _is_open := false

func _ready() -> void:
	add_to_group("interactable")
	if _sprite:
		_sprite.frame = 0

func interact(player: Node = null) -> void:
	if _is_open:
		return

	_is_open = true

	if _sprite and _sprite.hframes >= 2:
		_sprite.frame = 1

	if is_in_group("interactable"):
		remove_from_group("interactable")

	if player and player.has_method("on_chest_opened"):
		player.on_chest_opened()
