extends Node2D
##
## M1 + M2 — drives the C ↔ Godot pipeline and manages maze + fog rendering.
##
## Runs the maze_core executable, reads maze_state.json, renders it onto the
## maze TileMapLayer, fills the FogLayer with dark fog, and spawns the player.
##
## Source IDs:
##   maze_tileset.tres → 0 = floor, 1 = wall
##   fog_tileset.tres  → 0 = dim (in step trail), 1 = dark (forgotten / never seen)
## Tile values from maze_core JSON are identity-mapped to source ids.
## Memory model: step-based — only the last MEMORY_TRAIL_SIZE cells the player
## actually stepped on stay dim; older steps fade to dark. (Spatial radius was
## tried first but caused old paths to "reappear" when the player walked into
## an adjacent corridor.)

const ATLAS_COORDS := Vector2i(0, 0)
const FOG_DIM_SOURCE := 0
const FOG_DARK_SOURCE := 1
const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const PLAYER_SPAWN := Vector2i(1, 1)
const MEMORY_TRAIL_SIZE := 8  ## Number of past stepped cells that stay dim before fading to dark
const EXPANSION_STAGE := 1
const EXPANSION_OFFSET := 2
const INTERACTABLE_SCRIPT := preload("res://scripts/Interactable.gd")
const EXIT_SCRIPT := preload("res://scripts/Exit.gd")
const WALL_HINT_SCRIPT := preload("res://scripts/WallHint.gd")
const OBJECT_SCENES := {
	"chest": preload("res://scenes/Chest.tscn"),
	"key": preload("res://scenes/Key.tscn"),
	"vision_core": preload("res://scenes/VisionCore.tscn"),
	"enemy": preload("res://scenes/Enemy.tscn")
}
const EXIT_SCENES := {
	"false": preload("res://scenes/ExitFalse.tscn"),
	"true": preload("res://scenes/ExitTrue.tscn")
}
const EXIT_TYPE_FALSE := "false"
const EXIT_TYPE_TRUE := "true"
const RESTART_HINT := "按 R 再走一次"

enum EndingType {
	BAD,
	NORMAL,
	TRUE
}

const ENDING_TEXT := {
	EndingType.BAD: {
		"title": "迷宮留下了你",
		"body": "你一直往前。牆也一直往前。最後，出口學會了把你忘記。"
	},
	EndingType.NORMAL: {
		"title": "你走出去了",
		"body": "門在身後關上。你聽見裡面還有腳步，像是你的。"
	},
	EndingType.TRUE: {
		"title": "你沒有再拿",
		"body": "迷宮等了一會兒。你沒有回答。於是它把真正的門還給你。"
	}
}
const ENDING_MUSIC := {
	EndingType.BAD: preload("res://assets/audio/endings/ending_bad.ogg"),
	EndingType.NORMAL: preload("res://assets/audio/endings/ending_normal.ogg"),
	EndingType.TRUE: preload("res://assets/audio/endings/ending_true.ogg")
}
const ENDING_SCENES := {
	EndingType.BAD: preload("res://scenes/ui/EndingBad.tscn"),
	EndingType.NORMAL: preload("res://scenes/ui/EndingNormal.tscn"),
	EndingType.TRUE: preload("res://scenes/ui/EndingTrue.tscn")
}

@onready var tile_layer: TileMapLayer = $TileMapLayer
@onready var fog_layer: TileMapLayer = $FogLayer
@onready var game_state = $GameState
@onready var hud = $HUD
@onready var objects_root: Node2D = get_node_or_null("Objects")
@onready var critical_event_controller: Node = get_node_or_null("CriticalEventController")
@onready var ambient_loop: AudioStreamPlayer = $AudioStreamPlayer
@onready var ending_music: AudioStreamPlayer = $EndingMusic
@onready var ending_screen: CanvasLayer = $EndingScreen

var _maze: Dictionary
var _trail: Array = []  ## FIFO of past player cells (Vector2i), oldest first
var _last_center := Vector2i(-9999, -9999)  ## sentinel; first update_vision call won't push
var _player: Node2D = null
var _is_expanding := false
var _is_game_over := false
var _consumed_object_keys: Dictionary = {}
var _has_key := false
var _distortion_tween: Tween = null
var _ending_transition_layer: CanvasLayer = null
var _ending_fade: ColorRect = null

func _ready() -> void:
	if game_state and hud:
		game_state.stats_changed.connect(hud.update_stats)
		game_state.stats_changed.connect(_on_stats_changed)
	_maze = _run_maze_core()
	if _maze.is_empty():
		return
	_load_initial_stats(_maze)
	_render_maze(_maze)
	_init_fog(_maze)
	_spawn_objects(_maze)
	_spawn_player()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F1 and hud and hud.has_method("toggle_debug_overlay"):
		hud.toggle_debug_overlay()
		get_viewport().set_input_as_handled()
		return

	if OS.is_debug_build() and not _is_game_over:
		match event.keycode:
			KEY_7, KEY_F7:
				show_ending(EndingType.BAD)
				get_viewport().set_input_as_handled()
				return
			KEY_8:
				show_ending(EndingType.NORMAL)
				get_viewport().set_input_as_handled()
				return
			KEY_9:
				show_ending(EndingType.TRUE)
				get_viewport().set_input_as_handled()
				return

	if not _is_game_over:
		return
	if event.keycode == KEY_R:
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()
	elif event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		get_tree().quit()

func is_wall(cell: Vector2i) -> bool:
	if _maze.is_empty():
		return true
	if not _is_in_bounds(cell):
		return true
	var tiles: Array = _maze.get("tiles", [])
	var row: Array = tiles[cell.y]
	return int(row[cell.x]) == 1

func update_vision(center: Vector2i, vision_radius: int) -> void:
	if _maze.is_empty():
		return
	if _is_game_over:
		return
	if game_state and game_state.mark_explored(center):
		_refresh_instability_stats()
	if center != _last_center:
		if _last_center != Vector2i(-9999, -9999):
			_trail.push_back(_last_center)
			if _trail.size() > MEMORY_TRAIL_SIZE:
				_trail.pop_front()
		_last_center = center

	var trail_set: Dictionary = {}
	for c in _trail:
		trail_set[c] = true

	var w := int(_maze.get("width", 0))
	var h := int(_maze.get("height", 0))
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			var cheb: int = max(abs(c.x - center.x), abs(c.y - center.y))
			if cheb <= vision_radius:
				fog_layer.set_cell(c, -1)
			elif trail_set.has(c):
				fog_layer.set_cell(c, FOG_DIM_SOURCE, ATLAS_COORDS)
			else:
				fog_layer.set_cell(c, FOG_DARK_SOURCE, ATLAS_COORDS)

func get_vision_radius() -> int:
	if game_state and game_state.has_method("get_vision_radius"):
		return game_state.get_vision_radius()
	return 1

func get_vision_core_count() -> int:
	if game_state and game_state.has_method("get_vision_core_count"):
		return game_state.get_vision_core_count()
	return 0

func get_instability_value() -> int:
	return _current_instability()

func has_key() -> bool:
	return _has_key

func on_chest_opened(source: Node = null) -> void:
	if _is_game_over or not game_state:
		return
	_mark_object_consumed(source)
	if game_state.has_method("apply_chest_open"):
		game_state.apply_chest_open()
	_refresh_instability_stats()

func on_key_picked(source: Node = null) -> void:
	if _is_game_over:
		return
	_has_key = true
	_mark_object_consumed(source)

func on_vision_core_picked(source: Node = null) -> void:
	if _is_game_over or not game_state:
		return
	_mark_object_consumed(source)
	if game_state.has_method("apply_vision_core_pickup"):
		game_state.apply_vision_core_pickup()
	_refresh_instability_stats()

func on_enemy_seen(source: Node = null) -> void:
	if _is_game_over or not game_state:
		return
	_mark_object_consumed(source)
	if game_state.has_method("apply_enemy_seen"):
		game_state.apply_enemy_seen()
	_refresh_instability_stats()

func on_exit_interacted(exit_type: String) -> void:
	if _is_game_over:
		return
	if exit_type.is_empty():
		return
	show_ending(judge_ending(exit_type, _current_instability()))

func judge_ending(exit_type: String, instability: int) -> EndingType:
	if instability >= 100:
		return EndingType.BAD
	if exit_type == EXIT_TYPE_FALSE:
		return EndingType.NORMAL
	if exit_type == EXIT_TYPE_TRUE and instability < 70:
		return EndingType.TRUE
	return EndingType.NORMAL

func show_ending(ending: EndingType) -> void:
	if _is_game_over:
		return
	_is_game_over = true

	if is_instance_valid(_player):
		_player.set_process(false)
		_player.set_process_input(false)
		_player.set_process_unhandled_input(false)
		_player.set_physics_process(false)

	_show_ending_after_transition(ending)

func _show_ending_after_transition(ending: EndingType) -> void:
	await _fade_to_black()

	var scene: PackedScene = ENDING_SCENES.get(ending, null)
	if scene != null:
		var screen := scene.instantiate() as CanvasLayer
		if screen == null:
			return
		add_child(screen)
		ending_screen = screen
		if screen.has_method("show_default_ending"):
			screen.show_default_ending()
	else:
		var data: Dictionary = ENDING_TEXT.get(ending, ENDING_TEXT[EndingType.NORMAL])
		if ending_screen and ending_screen.has_method("show_ending"):
			ending_screen.show_ending(String(data["title"]), String(data["body"]), RESTART_HINT)
	_play_ending_music(ending)

func _fade_to_black() -> void:
	if _ending_transition_layer == null:
		_ending_transition_layer = CanvasLayer.new()
		_ending_transition_layer.layer = 45
		add_child(_ending_transition_layer)
		_ending_fade = ColorRect.new()
		_ending_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ending_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		_ending_transition_layer.add_child(_ending_fade)
	if _ending_fade == null:
		return
	_ending_fade.visible = true
	_ending_fade.color = Color(0.047, 0.035, 0.059, 0.0)
	var tween := create_tween()
	tween.tween_property(_ending_fade, "color:a", 1.0, 0.75)
	await tween.finished

func _is_in_bounds(cell: Vector2i) -> bool:
	if _maze.is_empty():
		return false
	var w := int(_maze.get("width", 0))
	var h := int(_maze.get("height", 0))
	return cell.x >= 0 and cell.y >= 0 and cell.x < w and cell.y < h

func _run_maze_core() -> Dictionary:
	var project_dir := ProjectSettings.globalize_path("res://")
	var exe_name := "maze_core.exe" if OS.has_feature("windows") else "maze_core"
	var exe_path := project_dir.path_join(exe_name)
	var out_path := ProjectSettings.globalize_path("user://maze_state.json")

	if not FileAccess.file_exists(exe_path):
		push_error("maze_core executable not found at %s — run `make` in c_src/" % exe_path)
		return {}

	var output: Array = []
	var args := PackedStringArray([out_path, str(int(Time.get_unix_time_from_system()))])
	var exit_code := OS.execute(exe_path, args, output, true)
	if exit_code != 0:
		push_error("maze_core exited with code %d. stdout/stderr:\n%s" % [exit_code, "\n".join(output)])
		return {}

	var f := FileAccess.open(out_path, FileAccess.READ)
	if f == null:
		push_error("cannot read %s" % out_path)
		return {}
	var json_text := f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("invalid JSON from maze_core")
		return {}
	return parsed

func _run_maze_core_stats(stats: Dictionary) -> Dictionary:
	var project_dir := ProjectSettings.globalize_path("res://")
	var exe_name := "maze_core.exe" if OS.has_feature("windows") else "maze_core"
	var exe_path := project_dir.path_join(exe_name)
	var out_path := ProjectSettings.globalize_path("user://maze_stats.json")

	if not FileAccess.file_exists(exe_path):
		push_error("maze_core executable not found at %s ??run `make` in c_src/" % exe_path)
		return {}

	var output: Array = []
	var args := PackedStringArray([
		"--stats",
		out_path,
		str(int(stats.get("vision", 1))),
		str(int(stats.get("chests", 0))),
		str(int(stats.get("puzzles", 0))),
		str(int(stats.get("enemies", 0))),
		str(int(stats.get("explored", 0))),
		str(int(stats.get("previous_instability", 0))),
	])
	var exit_code := OS.execute(exe_path, args, output, true)
	if exit_code != 0:
		push_error("maze_core stats exited with code %d. stdout/stderr:\n%s" % [exit_code, "\n".join(output)])
		return {}

	var f := FileAccess.open(out_path, FileAccess.READ)
	if f == null:
		push_error("cannot read %s" % out_path)
		return {}
	var json_text := f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("invalid stats JSON from maze_core")
		return {}
	return parsed

func _run_maze_core_expansion(player_cell: Vector2i) -> Dictionary:
	var project_dir := ProjectSettings.globalize_path("res://")
	var exe_name := "maze_core.exe" if OS.has_feature("windows") else "maze_core"
	var exe_path := project_dir.path_join(exe_name)
	var out_path := ProjectSettings.globalize_path("user://maze_expanded.json")

	if not FileAccess.file_exists(exe_path):
		push_error("maze_core executable not found at %s ??run `make` in c_src/" % exe_path)
		return {}

	var output: Array = []
	var seed_value := int(_maze.get("seed", int(Time.get_unix_time_from_system())))
	var args := PackedStringArray([
		"--expand",
		out_path,
		str(seed_value),
		str(player_cell.x),
		str(player_cell.y),
	])
	var exit_code := OS.execute(exe_path, args, output, true)
	if exit_code != 0:
		push_error("maze_core expansion exited with code %d. stdout/stderr:\n%s" % [exit_code, "\n".join(output)])
		return {}

	var f := FileAccess.open(out_path, FileAccess.READ)
	if f == null:
		push_error("cannot read %s" % out_path)
		return {}
	var json_text := f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("invalid expansion JSON from maze_core")
		return {}
	return parsed

func _render_maze(maze: Dictionary) -> void:
	var w := int(maze.get("width", 0))
	var h := int(maze.get("height", 0))
	var tiles: Array = maze.get("tiles", [])
	tile_layer.clear()
	for y in h:
		var row: Array = tiles[y]
		for x in w:
			var source_id := int(row[x])
			tile_layer.set_cell(Vector2i(x, y), source_id, ATLAS_COORDS)
	print("maze_core: rendered %dx%d, seed=%s" % [w, h, maze.get("seed", "?")])

func _spawn_objects(maze: Dictionary) -> void:
	if objects_root == null:
		objects_root = Node2D.new()
		objects_root.name = "Objects"
		add_child(objects_root)
	for child in objects_root.get_children():
		child.queue_free()

	var objects: Array = _objects_with_r2_fallback(maze)
	var expansion_level := int(maze.get("expansion_level", 0))
	for obj in objects:
		if typeof(obj) != TYPE_DICTIONARY:
			continue
		var obj_type := String(obj.get("type", ""))
		var cell := Vector2i(int(obj.get("x", 0)), int(obj.get("y", 0)))
		if obj_type == "wall_text":
			_spawn_wall_text(obj, _find_wall_hint_cell(maze, cell))
			continue
		var scene: PackedScene = null
		var exit_type := ""
		if obj_type == "exit":
			exit_type = String(obj.get("exit_type", ""))
			scene = EXIT_SCENES.get(exit_type, null)
		else:
			scene = OBJECT_SCENES.get(obj_type, null)
		if scene == null:
			continue
		var object_key := _object_key(obj_type, exit_type, cell, expansion_level)
		if obj_type != "exit" and obj_type != "enemy" and _consumed_object_keys.has(object_key):
			continue
		var node := scene.instantiate()
		if obj_type == "exit":
			node.set_script(EXIT_SCRIPT)
			node.set("exit_type", exit_type)
		elif obj_type == "enemy" and node.has_method("set_patrol_cells"):
			node.set_patrol_cells(_parse_patrol_cells(obj, cell))
		if obj_type != "enemy":
			_prepare_interactable(node)
		node.set_meta("object_key", object_key)
		node.set_meta("object_type", obj_type)
		node.position = _cell_to_world(cell)
		if obj_type == "exit" and exit_type == EXIT_TYPE_FALSE:
			node.add_to_group("false_exit")
		objects_root.add_child(node)

func _spawn_wall_text(obj: Dictionary, cell: Vector2i) -> void:
	var wall_dir := _wall_neighbor_direction(_maze, cell)
	var hint := Area2D.new()
	hint.name = "WallHint"
	hint.set_script(WALL_HINT_SCRIPT)
	hint.set("hint_text", String(obj.get("text", "The wall remembers.")))
	hint.set_meta("object_type", "wall_hint")
	hint.position = _cell_to_world(cell)

	var marker_root := Node2D.new()
	marker_root.name = "WallMark"
	marker_root.position = Vector2(wall_dir.x * 24.0, wall_dir.y * 24.0)
	hint.add_child(marker_root)

	var backing := ColorRect.new()
	backing.name = "Backing"
	backing.position = Vector2(-7.0, -8.0)
	backing.size = Vector2(14.0, 16.0)
	backing.color = Color(0.18, 0.10, 0.18, 0.55)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker_root.add_child(backing)

	var marker := Label.new()
	marker.name = "Marker"
	marker.text = "?"
	marker.position = Vector2(-7.0, -11.0)
	marker.size = Vector2(14.0, 18.0)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 13)
	marker.add_theme_color_override("font_color", Color(0.92, 0.62, 0.68, 0.96))
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker_root.add_child(marker)

	var pulse := create_tween()
	pulse.set_loops()
	pulse.tween_property(marker_root, "modulate:a", 0.55, 0.85)
	pulse.tween_property(marker_root, "modulate:a", 1.0, 0.85)

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18.0, 18.0)
	collision.shape = shape
	hint.add_child(collision)
	objects_root.add_child(hint)

func _objects_with_r2_fallback(maze: Dictionary) -> Array:
	var objects: Array = maze.get("objects", []).duplicate()
	var occupied: Dictionary = {}
	for obj in objects:
		if typeof(obj) != TYPE_DICTIONARY:
			continue
		occupied[Vector2i(int(obj.get("x", 0)), int(obj.get("y", 0)))] = true

	if not _objects_have_type(objects, "wall_text"):
		var wall_texts := [
			{"text": "牆記得你走過的路。", "preferred": Vector2i(3, 3)},
			{"text": "看得更遠，不代表更接近出口。", "preferred": Vector2i(8, 5)},
			{"text": "太容易看見的門，正在看你。", "preferred": Vector2i(13, 7)},
			{"text": "有些獎賞，可以留在原地。", "preferred": Vector2i(17, 11)},
		]
		for entry in wall_texts:
			var cell := _find_wall_hint_cell(maze, entry["preferred"], occupied)
			occupied[cell] = true
			objects.append({
				"type": "wall_text",
				"x": cell.x,
				"y": cell.y,
				"text": entry["text"],
			})

	if not _objects_have_type(objects, "enemy"):
		for preferred in [Vector2i(5, 5), Vector2i(15, 9)]:
			var cell := _find_floor_near(maze, preferred, occupied)
			var patrol := _fallback_patrol_for_cell(maze, cell)
			occupied[cell] = true
			objects.append({
				"type": "enemy",
				"x": cell.x,
				"y": cell.y,
				"patrol": patrol,
			})
	return objects

func _find_wall_hint_cell(maze: Dictionary, preferred: Vector2i, occupied: Dictionary = {}) -> Vector2i:
	var w := int(maze.get("width", 0))
	var h := int(maze.get("height", 0))
	var max_radius: int = max(w, h)
	for radius in range(max_radius):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var cell := preferred + Vector2i(dx, dy)
				if occupied.has(cell):
					continue
				if _is_floor_in_maze(maze, cell) and _has_wall_neighbor(maze, cell):
					return cell
	return _find_floor_near(maze, preferred, occupied)

func _objects_have_type(objects: Array, obj_type: String) -> bool:
	for obj in objects:
		if typeof(obj) == TYPE_DICTIONARY and String(obj.get("type", "")) == obj_type:
			return true
	return false

func _find_floor_near(maze: Dictionary, preferred: Vector2i, occupied: Dictionary) -> Vector2i:
	var w := int(maze.get("width", 0))
	var h := int(maze.get("height", 0))
	var max_radius: int = max(w, h)
	for radius in range(max_radius):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var cell := preferred + Vector2i(dx, dy)
				if occupied.has(cell):
					continue
				if _is_floor_in_maze(maze, cell):
					return cell
	return preferred

func _fallback_patrol_for_cell(maze: Dictionary, cell: Vector2i) -> Array:
	var directions: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	for dir in directions:
		var next_cell: Vector2i = cell + dir
		if _is_floor_in_maze(maze, next_cell):
			return [[cell.x, cell.y], [next_cell.x, next_cell.y]]
	return [[cell.x, cell.y]]

func _is_floor_in_maze(maze: Dictionary, cell: Vector2i) -> bool:
	var w := int(maze.get("width", 0))
	var h := int(maze.get("height", 0))
	if cell.x < 0 or cell.y < 0 or cell.x >= w or cell.y >= h:
		return false
	var tiles: Array = maze.get("tiles", [])
	if cell.y >= tiles.size():
		return false
	var row: Array = tiles[cell.y]
	if cell.x >= row.size():
		return false
	return int(row[cell.x]) == 0

func _has_wall_neighbor(maze: Dictionary, cell: Vector2i) -> bool:
	return _wall_neighbor_direction(maze, cell) != Vector2i.ZERO

func _wall_neighbor_direction(maze: Dictionary, cell: Vector2i) -> Vector2i:
	var directions: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
	for dir in directions:
		if _is_wall_in_maze(maze, cell + dir):
			return dir
	return Vector2i.ZERO

func _is_wall_in_maze(maze: Dictionary, cell: Vector2i) -> bool:
	var w := int(maze.get("width", 0))
	var h := int(maze.get("height", 0))
	if cell.x < 0 or cell.y < 0 or cell.x >= w or cell.y >= h:
		return false
	var tiles: Array = maze.get("tiles", [])
	if cell.y >= tiles.size():
		return false
	var row: Array = tiles[cell.y]
	if cell.x >= row.size():
		return false
	return int(row[cell.x]) == 1

func _parse_patrol_cells(obj: Dictionary, fallback: Vector2i) -> Array:
	var cells: Array = []
	var patrol: Array = obj.get("patrol", [])
	for point in patrol:
		if typeof(point) != TYPE_ARRAY or point.size() < 2:
			continue
		cells.append(Vector2i(int(point[0]), int(point[1])))
	if cells.is_empty():
		cells.append(fallback)
	return cells

func _init_fog(maze: Dictionary) -> void:
	var w := int(maze.get("width", 0))
	var h := int(maze.get("height", 0))
	fog_layer.clear()
	for y in h:
		for x in w:
			fog_layer.set_cell(Vector2i(x, y), FOG_DARK_SOURCE, ATLAS_COORDS)

func _spawn_player() -> void:
	var player := PLAYER_SCENE.instantiate()
	player.cell = _player_cell_from_maze(_maze, PLAYER_SPAWN)
	add_child(player)
	_player = player
	_apply_camera_limits()
	print("player: spawned at cell %s" % str(player.cell))

func _load_initial_stats(maze: Dictionary) -> void:
	if not game_state:
		return
	var stats: Dictionary = maze.get("stats", {})
	var events: Dictionary = maze.get("events", {})
	game_state.reset_from_core(
		stats,
		int(events.get("instability_stage", 0)),
		bool(events.get("critical_state", false))
	)

func _on_stats_changed(_vision_text: String, _achievement: int, instability: int, _stage: int, _critical_state: bool = false) -> void:
	if hud and hud.has_method("update_debug_overlay") and game_state and game_state.has_method("get_debug_snapshot"):
		hud.update_debug_overlay(game_state.get_debug_snapshot())
	_apply_instability_side_effects(instability)

func _refresh_instability_stats() -> void:
	if _is_game_over or not game_state:
		return
	var core_stats: Dictionary = game_state.to_core_stats()
	core_stats["previous_instability"] = int(game_state.get("instability"))
	var result := _run_maze_core_stats(core_stats)
	if result.is_empty():
		return
	var stats: Dictionary = result.get("stats", {})
	var events: Dictionary = result.get("events", {})
	game_state.apply_core_result(
		stats,
		int(events.get("instability_stage", 0)),
		bool(events.get("critical_state", false))
	)
	if _current_instability() >= 100:
		show_ending(EndingType.BAD)
		return
	if bool(events.get("critical_event_triggered", false)):
		_trigger_critical_sequence()
	elif bool(events.get("critical_state", false)):
		_apply_critical_state(true)
	_try_expand_maze(int(events.get("instability_stage", 0)))

func _try_expand_maze(instability_stage: int) -> void:
	if _is_game_over or _is_expanding or instability_stage < EXPANSION_STAGE:
		return
	if int(_maze.get("expansion_level", 0)) >= 1:
		return

	_is_expanding = true
	var expanded := _run_maze_core_expansion(_get_player_cell())
	if expanded.is_empty():
		_is_expanding = false
		return

	_apply_maze_state(expanded)
	_is_expanding = false

func _apply_maze_state(maze: Dictionary) -> void:
	_maze = maze
	_trail.clear()
	_last_center = Vector2i(-9999, -9999)
	_render_maze(_maze)
	_init_fog(_maze)
	_spawn_objects(_maze)
	_apply_player_cell_from_maze(_maze)
	_apply_camera_limits()
	if game_state:
		_apply_critical_state(bool(game_state.get("critical_state")))
	if bool(_maze.get("expanded_this_frame", false)):
		_play_expansion_feedback()

func _apply_instability_side_effects(instability: int) -> void:
	var active := instability >= 61 and not _is_game_over
	if hud and hud.has_method("set_distortion_active"):
		hud.set_distortion_active(active)
	if active:
		if _distortion_tween != null and _distortion_tween.is_valid():
			return
		_distortion_tween = create_tween()
		_distortion_tween.set_loops()
		_distortion_tween.tween_property(tile_layer, "modulate", Color(0.92, 0.78, 0.76, 1.0), 0.44)
		_distortion_tween.parallel().tween_property(fog_layer, "modulate", Color(0.78, 0.58, 0.7, 1.0), 0.44)
		_distortion_tween.tween_property(tile_layer, "modulate", Color.WHITE, 0.5)
		_distortion_tween.parallel().tween_property(fog_layer, "modulate", Color.WHITE, 0.5)
	else:
		if _distortion_tween != null and _distortion_tween.is_valid():
			_distortion_tween.kill()
		_distortion_tween = null
		tile_layer.modulate = Color.WHITE
		fog_layer.modulate = Color.WHITE

func _trigger_critical_sequence() -> void:
	if critical_event_controller and critical_event_controller.has_method("trigger_critical_sequence"):
		critical_event_controller.trigger_critical_sequence()

func _apply_critical_state(active: bool) -> void:
	if critical_event_controller and critical_event_controller.has_method("apply_critical_state"):
		critical_event_controller.apply_critical_state(active)

func _cell_to_world(cell: Vector2i) -> Vector2:
	var size := tile_layer.tile_set.tile_size
	return Vector2(cell.x * size.x + size.x * 0.5, cell.y * size.y + size.y * 0.5)

func _player_cell_from_maze(maze: Dictionary, fallback: Vector2i) -> Vector2i:
	var player_data: Variant = maze.get("player", {})
	if typeof(player_data) != TYPE_DICTIONARY:
		return fallback
	return Vector2i(int(player_data.get("x", fallback.x)), int(player_data.get("y", fallback.y)))

func _get_player_cell() -> Vector2i:
	if _player == null:
		return _player_cell_from_maze(_maze, PLAYER_SPAWN)
	var cell_value: Variant = _player.get("cell")
	if typeof(cell_value) == TYPE_VECTOR2I:
		return cell_value
	return _player_cell_from_maze(_maze, PLAYER_SPAWN)

func _apply_player_cell_from_maze(maze: Dictionary) -> void:
	if _player == null:
		return
	var cell := _player_cell_from_maze(maze, _get_player_cell())
	if _player.has_method("set_cell_from_maze"):
		_player.set_cell_from_maze(cell)
	else:
		_player.set("cell", cell)
		_player.position = _cell_to_world(cell)

func _apply_camera_limits() -> void:
	if _player == null or not _player.has_method("set_camera_bounds"):
		return
	_player.set_camera_bounds(Vector2i(
		int(_maze.get("width", 0)),
		int(_maze.get("height", 0))
	))

func _play_expansion_feedback() -> void:
	tile_layer.modulate = Color(1.0, 0.82, 0.28, 1.0)
	fog_layer.modulate = Color(1.0, 0.92, 0.72, 1.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(tile_layer, "modulate", Color.WHITE, 0.45)
	tween.tween_property(fog_layer, "modulate", Color.WHITE, 0.45)
	if _player and _player.has_method("play_expansion_camera_feedback"):
		_player.play_expansion_camera_feedback()
	if hud and hud.has_method("show_expansion_feedback"):
		hud.show_expansion_feedback()

func _current_instability() -> int:
	if game_state == null:
		return 0
	return int(game_state.get("instability"))

func _play_ending_music(ending: EndingType) -> void:
	if ambient_loop:
		ambient_loop.stop()
	if ending_music == null:
		return
	var stream: AudioStream = ENDING_MUSIC.get(ending, null)
	if stream == null:
		return
	ending_music.stream = stream
	ending_music.play()

func _prepare_interactable(node: Node) -> void:
	if node == null:
		return
	if not node.is_in_group("interactable"):
		node.add_to_group("interactable")
	if not node.has_method("interact") and node.get_script() == null:
		node.set_script(INTERACTABLE_SCRIPT)

func _mark_object_consumed(source: Node) -> void:
	if source == null:
		return
	var object_key := String(source.get_meta("object_key", ""))
	if object_key.is_empty():
		return
	_consumed_object_keys[object_key] = true

func _object_key(obj_type: String, exit_type: String, cell: Vector2i, expansion_level: int) -> String:
	var origin_cell := cell - Vector2i(EXPANSION_OFFSET * expansion_level, EXPANSION_OFFSET * expansion_level)
	return "%s:%s:%d:%d" % [obj_type, exit_type, origin_cell.x, origin_cell.y]
