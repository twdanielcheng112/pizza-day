extends Node
##
## T6 one-shot critical state presentation.
##
## MazeBridge feeds the C-emitted critical_event_triggered flag here. This node
## owns the "play once" guard and keeps exit highlighting separate from stats.

const FALSE_EXIT_GROUP := "false_exit"
const FALSE_EXIT_CRITICAL_COLOR := Color(1.0, 0.18, 0.14, 1.0)

@export var hud_path: NodePath = NodePath("../HUD")

var already_triggered := false
var _false_exit_tweens: Dictionary = {}

@onready var _hud: CanvasLayer = get_node_or_null(hud_path)

func trigger_critical_sequence() -> void:
	if already_triggered:
		return

	already_triggered = true
	if _hud and _hud.has_method("show_critical_sequence"):
		_hud.show_critical_sequence()
	_set_false_exit_highlight(true)

func apply_critical_state(active: bool) -> void:
	if active:
		_set_false_exit_highlight(true)
	else:
		_clear_false_exit_highlight()
		already_triggered = false

func _set_false_exit_highlight(active: bool) -> void:
	if not active:
		_clear_false_exit_highlight()
		return

	for exit_node in get_tree().get_nodes_in_group(FALSE_EXIT_GROUP):
		if not is_instance_valid(exit_node):
			continue
		var visual := _get_exit_visual(exit_node)
		if visual == null or _false_exit_tweens.has(visual):
			continue
		var tween := create_tween()
		tween.set_loops()
		tween.tween_property(visual, "modulate", FALSE_EXIT_CRITICAL_COLOR, 0.28)
		tween.tween_property(visual, "modulate", Color.WHITE, 0.28)
		_false_exit_tweens[visual] = tween

func _clear_false_exit_highlight() -> void:
	for visual in _false_exit_tweens.keys():
		if not is_instance_valid(visual):
			continue
		var tween := _false_exit_tweens[visual] as Tween
		if tween:
			tween.kill()
		visual.modulate = Color.WHITE
	_false_exit_tweens.clear()

func _get_exit_visual(exit_node: Node) -> CanvasItem:
	if exit_node is CanvasItem:
		return exit_node
	var sprite := exit_node.get_node_or_null("Sprite2D")
	if sprite is CanvasItem:
		return sprite
	return null
