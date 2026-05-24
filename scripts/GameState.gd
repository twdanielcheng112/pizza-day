extends Node
##
## M4 gameplay stats state.
##
## Kept as a scene-local node so the maze owns this run's volatile stats.

signal stats_changed(vision_label: String, achievement: int, instability: int, stage: int, critical_state: bool)

const MIN_VISION_LEVEL := 1  ## 3x3
const MAX_VISION_LEVEL := 4  ## 9x9

var vision_level: int = 1
var opened_chests: int = 0
var picked_vision_cores: int = 0
var solved_puzzles: int = 0
var defeated_enemies: int = 0
var explored_tiles: int = 0
var total_walkable_tiles: int = 0
var greed_buttons_pressed: int = 0
var bonus_instability: int = 0
var instability: int = 0
var instability_stage: int = 0
var critical_state: bool = false

var _explored_cells: Dictionary = {}

func reset_from_core(stats: Dictionary, stage: int, is_critical: bool = false) -> void:
	vision_level = int(clamp(int(stats.get("vision", vision_level)), MIN_VISION_LEVEL, MAX_VISION_LEVEL))
	opened_chests = int(stats.get("chests", opened_chests))
	picked_vision_cores = 0
	solved_puzzles = int(stats.get("puzzles", solved_puzzles))
	defeated_enemies = int(stats.get("enemies", defeated_enemies))
	explored_tiles = int(stats.get("explored", explored_tiles))
	total_walkable_tiles = int(stats.get("total_walkable", total_walkable_tiles))
	greed_buttons_pressed = int(stats.get("greed_buttons", 0))
	bonus_instability = int(stats.get("bonus", 0))
	instability = int(stats.get("instability", instability))
	instability_stage = stage
	critical_state = is_critical
	_explored_cells.clear()
	_emit_stats_changed()

func apply_core_result(stats: Dictionary, stage: int, is_critical: bool = false) -> void:
	vision_level = int(clamp(int(stats.get("vision", vision_level)), MIN_VISION_LEVEL, MAX_VISION_LEVEL))
	opened_chests = int(stats.get("chests", opened_chests))
	solved_puzzles = int(stats.get("puzzles", solved_puzzles))
	defeated_enemies = int(stats.get("enemies", defeated_enemies))
	explored_tiles = int(stats.get("explored", explored_tiles))
	greed_buttons_pressed = int(stats.get("greed_buttons", greed_buttons_pressed))
	bonus_instability = int(stats.get("bonus", bonus_instability))
	instability = int(stats.get("instability", instability))
	instability_stage = stage
	critical_state = is_critical
	_emit_stats_changed()

func mark_explored(cell: Vector2i) -> bool:
	if _explored_cells.has(cell):
		return false
	_explored_cells[cell] = true
	explored_tiles = _explored_cells.size()
	return true

func apply_chest_open() -> void:
	opened_chests += 1
	vision_level = min(vision_level + 1, MAX_VISION_LEVEL)

func apply_vision_core_pickup() -> void:
	picked_vision_cores += 1
	vision_level = min(vision_level + 2, MAX_VISION_LEVEL)

func apply_enemy_seen() -> void:
	defeated_enemies += 1

func apply_greed_button(delta: int) -> void:
	greed_buttons_pressed += 1
	bonus_instability += delta

func set_total_walkable_tiles(total: int) -> void:
	total_walkable_tiles = max(total, 0)
	_emit_stats_changed()

func get_vision_core_count() -> int:
	return picked_vision_cores

func get_achievement() -> int:
	return opened_chests + solved_puzzles + defeated_enemies + greed_buttons_pressed

func get_vision_radius() -> int:
	return vision_level

func get_vision_label() -> String:
	var diameter := vision_level * 2 + 1
	return "%dx%d" % [diameter, diameter]

func get_exploration_percent() -> float:
	if total_walkable_tiles <= 0:
		return 0.0
	return float(explored_tiles) / float(total_walkable_tiles) * 100.0

func to_core_stats() -> Dictionary:
	return {
		"vision": vision_level,
		"chests": opened_chests,
		"puzzles": solved_puzzles,
		"enemies": defeated_enemies,
		"explored": explored_tiles,
		"bonus": bonus_instability,
	}

func get_debug_snapshot() -> Dictionary:
	return {
		"vision_level": vision_level,
		"opened_chests": opened_chests,
		"vision_cores": picked_vision_cores,
		"puzzles_solved": solved_puzzles,
		"enemies_seen": defeated_enemies,
		"explored_tiles": explored_tiles,
		"total_walkable_tiles": total_walkable_tiles,
		"exploration_percent": get_exploration_percent(),
		"greed_buttons": greed_buttons_pressed,
		"bonus_instability": bonus_instability,
		"instability": instability,
		"critical_state": critical_state,
	}

func build_ending_recap() -> String:
	var explored_text := "%d / %d tiles (%.0f%%)" % [
		explored_tiles,
		total_walkable_tiles,
		get_exploration_percent(),
	]
	return (
		"本局回顧\n"
		+ "打開的寶箱：%d\n" % opened_chests
		+ "拿走的視野核心：%d\n" % picked_vision_cores
		+ "按下的貪婪按鈕：%d\n" % greed_buttons_pressed
		+ "探索範圍：%s\n" % explored_text
		+ "最終不穩定度：%d" % instability
	)

func _emit_stats_changed() -> void:
	stats_changed.emit(get_vision_label(), get_achievement(), instability, instability_stage, critical_state)
