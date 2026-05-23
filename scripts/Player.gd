extends Node2D
##
## M2 grid-snap player movement.
## Owns the player's cell coordinate, renders centered in that cell, and asks
## the parent (MazeBridge) whether a target cell is walkable before moving.
## Notifies the parent after moving so fog can be updated.

const CELL_SIZE := 24
const DEFAULT_VISION_RADIUS := 1  ## 3x3
const INTERACT_RANGE := 0
const EXPANSION_ZOOM_OUT_FACTOR := 0.86

@export var cell: Vector2i = Vector2i(1, 1)

@onready var maze: Node2D = get_parent()
@onready var camera: Camera2D = $Camera2D

var _nearest_interactable: Node = null
var _hint_label: Label = null

func _ready() -> void:
	_snap_to_cell()
	_create_hint()
	_update_interaction_hint()
	_refresh_vision()

func _process(_delta: float) -> void:
	_update_interaction_hint()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_E:
		_try_interact()
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
	_update_interaction_hint()
	_refresh_vision()

func set_cell_from_maze(new_cell: Vector2i) -> void:
	cell = new_cell
	_snap_to_cell()
	_update_interaction_hint()
	_refresh_vision()

func set_camera_bounds(map_size: Vector2i) -> void:
	if camera == null:
		return
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = map_size.x * CELL_SIZE
	camera.limit_bottom = map_size.y * CELL_SIZE

func play_expansion_camera_feedback() -> void:
	if camera == null:
		return
	var base_zoom := camera.zoom
	var zoomed_out := base_zoom * EXPANSION_ZOOM_OUT_FACTOR
	camera.offset = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(camera, "zoom", zoomed_out, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for offset in [
		Vector2(7, -4),
		Vector2(-6, 5),
		Vector2(4, 4),
		Vector2(-3, -5),
		Vector2.ZERO,
	]:
		tween.tween_property(camera, "offset", offset, 0.035)
	tween.tween_property(camera, "zoom", base_zoom, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _snap_to_cell() -> void:
	position = Vector2(cell.x * CELL_SIZE + CELL_SIZE / 2.0, cell.y * CELL_SIZE + CELL_SIZE / 2.0)

func _current_vision_radius() -> int:
	if maze and maze.has_method("get_vision_radius"):
		return max(int(maze.get_vision_radius()), DEFAULT_VISION_RADIUS)
	return DEFAULT_VISION_RADIUS

func _refresh_vision() -> void:
	if maze and maze.has_method("update_vision"):
		maze.update_vision(cell, _current_vision_radius())

func _create_hint() -> void:
	_hint_label = Label.new()
	_hint_label.text = "E"
	_hint_label.visible = false
	_hint_label.z_index = 10
	_hint_label.position = Vector2(-6, -24)
	_hint_label.size = Vector2(12, 12)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_hint_label)

func _update_interaction_hint() -> void:
	_nearest_interactable = _find_nearest_interactable()
	if _hint_label:
		_hint_label.visible = _nearest_interactable != null

func _find_nearest_interactable() -> Node:
	var nodes: Array = get_tree().get_nodes_in_group("interactable")
	var best: Node = null
	var best_dist: int = 999
	for node in nodes:
		if not is_instance_valid(node):
			continue
		var obj_cell := _world_to_cell(node.global_position)
		var dx: int = abs(obj_cell.x - cell.x)
		var dy: int = abs(obj_cell.y - cell.y)
		if max(dx, dy) > INTERACT_RANGE:
			continue
		var dist: int = dx + dy
		if dist < best_dist:
			best_dist = dist
			best = node
	return best

func _try_interact() -> void:
	if _nearest_interactable == null:
		return
	if _nearest_interactable.has_method("interact"):
		_nearest_interactable.interact(self)
		_update_interaction_hint()

func on_chest_opened() -> void:
	if maze and maze.has_method("on_chest_opened"):
		maze.on_chest_opened()
	_refresh_vision()

func on_vision_core_picked() -> void:
	if maze and maze.has_method("on_vision_core_picked"):
		maze.on_vision_core_picked()
	_refresh_vision()
	var core_count := 0
	if maze and maze.has_method("get_vision_core_count"):
		core_count = int(maze.get_vision_core_count())
	var radius := _current_vision_radius()
	print("vision core picked: count=%d, vision=%dx%d" % [core_count, radius * 2 + 1, radius * 2 + 1])

func _world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / CELL_SIZE)), int(floor(world_pos.y / CELL_SIZE)))
