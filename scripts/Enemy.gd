extends Area2D

const CELL_SIZE := 24
const PATROL_WAIT_SECONDS := 0.75
const MOVE_SECONDS := 0.32
const CONTACT_COOLDOWN_SECONDS := 3.0

@export var patrol_cells: Array[Vector2i] = []

@onready var _sprite: Sprite2D = $Sprite2D

var _patrol_index := 0
var _is_moving := false
var _contact_cooldown := 0.0

func _ready() -> void:
	add_to_group("enemy")
	if _sprite:
		_sprite.modulate = Color(0.7, 0.18, 0.28, 1.0)
	if patrol_cells.is_empty():
		patrol_cells = [_world_to_cell(global_position)]
	_snap_to_cell(patrol_cells[0])
	_start_patrol()

func _process(delta: float) -> void:
	_contact_cooldown = maxf(0.0, _contact_cooldown - delta)
	_check_player_contact()

func set_patrol_cells(cells: Array) -> void:
	patrol_cells.clear()
	for value in cells:
		if typeof(value) == TYPE_VECTOR2I:
			patrol_cells.append(value)
	if not patrol_cells.is_empty():
		_patrol_index = 0
		_snap_to_cell(patrol_cells[0])

func _start_patrol() -> void:
	if patrol_cells.size() < 2 or _is_moving:
		return
	_patrol_loop()

func _patrol_loop() -> void:
	while is_inside_tree() and patrol_cells.size() >= 2:
		await get_tree().create_timer(PATROL_WAIT_SECONDS).timeout
		_patrol_index = (_patrol_index + 1) % patrol_cells.size()
		_is_moving = true
		var tween := create_tween()
		tween.tween_property(self, "global_position", _cell_to_world(patrol_cells[_patrol_index]), MOVE_SECONDS)
		await tween.finished
		_is_moving = false

func _check_player_contact() -> void:
	if _contact_cooldown > 0.0:
		return
	for player in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(player):
			continue
		var player_cell: Variant = player.get("cell")
		if typeof(player_cell) != TYPE_VECTOR2I:
			continue
		if player_cell != _world_to_cell(global_position):
			continue
		_report_contact()
		return

func _report_contact() -> void:
	_contact_cooldown = CONTACT_COOLDOWN_SECONDS
	var maze := get_parent()
	if maze:
		maze = maze.get_parent()
	if maze and maze.has_method("on_enemy_seen"):
		maze.on_enemy_seen(self)
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color(1.0, 0.35, 0.22, 1.0), 0.08)
		tween.tween_property(_sprite, "modulate", Color(0.7, 0.18, 0.28, 1.0), 0.28)

func _snap_to_cell(cell: Vector2i) -> void:
	global_position = _cell_to_world(cell)

func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL_SIZE + CELL_SIZE / 2.0, cell.y * CELL_SIZE + CELL_SIZE / 2.0)

func _world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / CELL_SIZE)), int(floor(world_pos.y / CELL_SIZE)))
