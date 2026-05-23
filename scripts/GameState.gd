extends Node
##
## M4 gameplay stats state.
##
## Kept as a scene-local node so the maze owns this run's volatile stats.

signal stats_changed(vision_label: String, achievement: int, instability: int, stage: int)

var vision_level: int = 1
var opened_chests: int = 0
var solved_puzzles: int = 0
var defeated_enemies: int = 0
var explored_tiles: int = 0
var instability: int = 0
var instability_stage: int = 0

var _explored_cells: Dictionary = {}

func reset_from_core(stats: Dictionary, stage: int) -> void:
	vision_level = int(stats.get("vision", vision_level))
	opened_chests = int(stats.get("chests", opened_chests))
	solved_puzzles = int(stats.get("puzzles", solved_puzzles))
	defeated_enemies = int(stats.get("enemies", defeated_enemies))
	explored_tiles = int(stats.get("explored", explored_tiles))
	instability = int(stats.get("instability", instability))
	instability_stage = stage
	_emit_stats_changed()

func apply_core_result(stats: Dictionary, stage: int) -> void:
	vision_level = int(stats.get("vision", vision_level))
	opened_chests = int(stats.get("chests", opened_chests))
	solved_puzzles = int(stats.get("puzzles", solved_puzzles))
	defeated_enemies = int(stats.get("enemies", defeated_enemies))
	explored_tiles = int(stats.get("explored", explored_tiles))
	instability = int(stats.get("instability", instability))
	instability_stage = stage
	_emit_stats_changed()

func mark_explored(cell: Vector2i) -> bool:
	if _explored_cells.has(cell):
		return false
	_explored_cells[cell] = true
	explored_tiles = _explored_cells.size()
	return true

func get_achievement() -> int:
	return opened_chests + solved_puzzles + defeated_enemies

func get_vision_radius() -> int:
	return vision_level

func get_vision_label() -> String:
	var diameter := vision_level * 2 + 1
	return "%dx%d" % [diameter, diameter]

func to_core_stats() -> Dictionary:
	return {
		"vision": vision_level,
		"chests": opened_chests,
		"puzzles": solved_puzzles,
		"enemies": defeated_enemies,
		"explored": explored_tiles,
	}

func _emit_stats_changed() -> void:
	stats_changed.emit(get_vision_label(), get_achievement(), instability, instability_stage)
