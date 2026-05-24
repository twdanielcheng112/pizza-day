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
const WALK_SFX_STREAM := preload("res://assets/audio/walk_sfx.mp3")
const WALK_SFX_PITCH_RANGE := Vector2(0.85, 1.15)

@export var cell: Vector2i = Vector2i(1, 1)

@onready var maze: Node2D = get_parent()
@onready var camera: Camera2D = $Camera2D
@onready var _walk_sfx: AudioStreamPlayer = $WalkSfx

var _nearest_interactable: Node = null
var _hint_label: Label = null
var _pending_confirmation: Node = null
var _confirmation_layer: CanvasLayer = null
var _confirmation_label: Label = null
var _is_reading_hint := false

func _ready() -> void:
	add_to_group("player")
	_snap_to_cell()
	_create_hint()
	_create_confirmation_prompt()
	_update_interaction_hint()
	_refresh_vision()
	if _walk_sfx and _walk_sfx.stream == null:
		_walk_sfx.stream = WALK_SFX_STREAM

func _process(_delta: float) -> void:
	_update_interaction_hint()

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if _is_reading_hint:
		if event.keycode in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_Q]:
			_close_wall_hint()
			get_viewport().set_input_as_handled()
		return
	if _pending_confirmation != null:
		if event.keycode in [KEY_E, KEY_ENTER, KEY_KP_ENTER]:
			_confirm_pending_interaction()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_ESCAPE, KEY_Q]:
			_cancel_pending_interaction()
			get_viewport().set_input_as_handled()
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
	_play_walk_sfx()

func _play_walk_sfx() -> void:
	if _walk_sfx == null or _walk_sfx.stream == null:
		return
	_walk_sfx.pitch_scale = randf_range(WALK_SFX_PITCH_RANGE.x, WALK_SFX_PITCH_RANGE.y)
	_walk_sfx.play()

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
	if _requires_confirmation(_nearest_interactable):
		_show_confirmation_prompt(_nearest_interactable)
		return
	if _nearest_interactable.has_method("interact"):
		_nearest_interactable.interact(self)
		_update_interaction_hint()

func _requires_confirmation(node: Node) -> bool:
	var object_type := String(node.get_meta("object_type", ""))
	return object_type == "vision_core" or object_type == "greed_button"

func _show_confirmation_prompt(node: Node) -> void:
	_pending_confirmation = node
	if _confirmation_layer == null:
		_create_confirmation_prompt()
	var instability := 0
	if maze and maze.has_method("get_instability_value"):
		instability = int(maze.get_instability_value())
	var message := "要取走視野核心嗎？\n邊界會記住你拿過。"
	if String(node.get_meta("object_type", "")) == "greed_button":
		message = "要按下這顆紅鍵嗎？\n一面牆會被推開，失控值會升起。"
		if instability >= 70:
			message = "還是要按下嗎？\n邊界已經在回望你。"
	else:
		if instability >= 70:
			message = "還要再從邊界拿走嗎？\n它已經在回望你。"
		elif instability >= 61:
			message = "要取走視野核心嗎？\n牆已經變薄。"
		elif instability >= 31:
			message = "要取走視野核心嗎？\n邊界開始移動。"
	_confirmation_label.text = "%s\n\nE / Enter：拿走    Esc / Q：離開" % message
	_confirmation_layer.visible = true

func _confirm_pending_interaction() -> void:
	var node := _pending_confirmation
	_pending_confirmation = null
	_confirmation_layer.visible = false
	if node != null and is_instance_valid(node) and node.has_method("interact"):
		node.interact(self)
	_update_interaction_hint()

func _cancel_pending_interaction() -> void:
	_pending_confirmation = null
	if _confirmation_layer:
		_confirmation_layer.visible = false
	_update_interaction_hint()

func on_wall_hint_read(text: String) -> void:
	_pending_confirmation = null
	_is_reading_hint = true
	if _confirmation_layer == null:
		_create_confirmation_prompt()
	_confirmation_label.text = "%s\n\nE / Enter / Esc：關閉" % text
	_confirmation_layer.visible = true

func _close_wall_hint() -> void:
	_is_reading_hint = false
	if _confirmation_layer:
		_confirmation_layer.visible = false
	_update_interaction_hint()

func _create_confirmation_prompt() -> void:
	_confirmation_layer = CanvasLayer.new()
	_confirmation_layer.visible = false
	_confirmation_layer.layer = 25
	add_child(_confirmation_layer)

	var panel := Panel.new()
	panel.offset_left = 170.0
	panel.offset_top = 236.0
	panel.offset_right = 470.0
	panel.offset_bottom = 336.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirmation_layer.add_child(panel)

	_confirmation_label = Label.new()
	_confirmation_label.offset_left = 12.0
	_confirmation_label.offset_top = 10.0
	_confirmation_label.offset_right = 288.0
	_confirmation_label.offset_bottom = 90.0
	_confirmation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirmation_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_confirmation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirmation_label.add_theme_font_size_override("font_size", 12)
	panel.add_child(_confirmation_label)

func on_chest_opened(source: Node = null) -> void:
	if maze and maze.has_method("on_chest_opened"):
		maze.on_chest_opened(source)
	_refresh_vision()

func can_open_chest() -> bool:
	if maze and maze.has_method("has_key"):
		return bool(maze.has_key())
	return false

func on_key_picked(source: Node = null) -> void:
	if maze and maze.has_method("on_key_picked"):
		maze.on_key_picked(source)

func on_vision_core_picked(source: Node = null) -> void:
	if maze and maze.has_method("on_vision_core_picked"):
		maze.on_vision_core_picked(source)
	_refresh_vision()
	var core_count := 0
	if maze and maze.has_method("get_vision_core_count"):
		core_count = int(maze.get_vision_core_count())
	var radius := _current_vision_radius()
	print("vision core picked: count=%d, vision=%dx%d" % [core_count, radius * 2 + 1, radius * 2 + 1])

func on_greed_button_pressed(source: Node = null) -> void:
	if maze and maze.has_method("on_greed_button_pressed"):
		maze.on_greed_button_pressed(source)
	_refresh_vision()

func on_exit_interacted(exit_type: String) -> void:
	if maze and maze.has_method("on_exit_interacted"):
		maze.on_exit_interacted(exit_type)

func _world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / CELL_SIZE)), int(floor(world_pos.y / CELL_SIZE)))
