extends Node2D
##
## M2 — grid-snap player movement.
## Owns the player's cell coordinate, renders centered in that cell, and asks
## the parent (MazeBridge) whether a target cell is walkable before moving.
## Notifies the parent after moving so fog can be updated.

const CELL_SIZE := 24
const VISION_RADIUS := 1  ## 3×3 means center ± 1

@export var cell: Vector2i = Vector2i(1, 1)

@onready var maze: Node2D = get_parent()

func _ready() -> void:
	_snap_to_cell()
	if maze and maze.has_method("update_vision"):
		maze.update_vision(cell, _current_vision_radius())

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var dir := _input_direction(event)
	if dir == Vector2i.ZERO:
		return
	_try_move(dir)

func _input_direction(event: InputEventKey) -> Vector2i:
	match event.keycode:
		KEY_W, KEY_UP:    return Vector2i.UP
		KEY_S, KEY_DOWN:  return Vector2i.DOWN
		KEY_A, KEY_LEFT:  return Vector2i.LEFT
		KEY_D, KEY_RIGHT: return Vector2i.RIGHT
	return Vector2i.ZERO

func _try_move(dir: Vector2i) -> void:
	var target := cell + dir
	if maze and maze.has_method("is_wall") and maze.is_wall(target):
		return
	cell = target
	_snap_to_cell()
	if maze and maze.has_method("update_vision"):
		maze.update_vision(cell, _current_vision_radius())

func _snap_to_cell() -> void:
	position = Vector2(cell.x * CELL_SIZE + CELL_SIZE / 2.0, cell.y * CELL_SIZE + CELL_SIZE / 2.0)

func _current_vision_radius() -> int:
	if maze and maze.has_method("get_vision_radius"):
		return maze.get_vision_radius()
	return VISION_RADIUS
