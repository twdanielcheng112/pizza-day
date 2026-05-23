extends CanvasLayer
##
## Text-only ending page for M6 endings.
##
## The screen is built in script so the ending copy, fade, and restart hint stay
## together while the Maze scene owns when it appears.

const BACKDROP_COLOR := Color(0.047, 0.035, 0.059, 0.94)
const TITLE_COLOR := Color(0.94, 0.86, 0.88)
const BODY_COLOR := Color(0.84, 0.78, 0.82)
const HINT_COLOR := Color(0.62, 0.56, 0.62)
const FADE_SECONDS := 0.8

@export var default_title := ""
@export_multiline var default_body := ""
@export var default_hint := "按 R 再走一次"

@onready var _root: Control = get_node_or_null("Root")
@onready var _title_label: Label = get_node_or_null("Root/Center/TextBox/EndingTitle")
@onready var _body_label: Label = get_node_or_null("Root/Center/TextBox/EndingBody")
@onready var _hint_label: Label = get_node_or_null("Root/Center/TextBox/RestartHint")

func _ready() -> void:
	layer = 50
	visible = false
	if _root == null or _title_label == null or _body_label == null or _hint_label == null:
		_build_screen()

func show_ending(title: String, body: String, hint: String) -> void:
	if _title_label == null:
		_build_screen()

	_title_label.text = title
	_body_label.text = body
	_hint_label.text = hint
	visible = true
	_root.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, FADE_SECONDS)

func show_default_ending() -> void:
	show_ending(default_title, default_body, default_hint)

func _build_screen() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = BACKDROP_COLOR
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)

	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var text_box := VBoxContainer.new()
	text_box.name = "TextBox"
	text_box.custom_minimum_size = Vector2(430.0, 0.0)
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.add_theme_constant_override("separation", 16)
	center.add_child(text_box)

	_title_label = Label.new()
	_title_label.name = "EndingTitle"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", TITLE_COLOR)
	text_box.add_child(_title_label)

	_body_label = Label.new()
	_body_label.name = "EndingBody"
	_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 16)
	_body_label.add_theme_color_override("font_color", BODY_COLOR)
	text_box.add_child(_body_label)

	_hint_label = Label.new()
	_hint_label.name = "RestartHint"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", 11)
	_hint_label.add_theme_color_override("font_color", HINT_COLOR)
	text_box.add_child(_hint_label)
