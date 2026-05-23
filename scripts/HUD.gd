extends CanvasLayer
##
## M4 HUD for Vision / Achievement / Instability.
##
## Also owns the one-shot warning stings when instability crosses a higher
## stage threshold.

const CRITICAL_MESSAGE := "邊界已記住你的貪婪"
const WARNING_STINGS := {
	1: preload("res://assets/audio/stings/sting_stage1.ogg"),
	2: preload("res://assets/audio/stings/sting_stage2.ogg"),
	3: preload("res://assets/audio/stings/sting_stage3.ogg"),
}

@onready var vision_label: Label = $Panel/StatsBox/VisionLabel
@onready var achievement_label: Label = $Panel/StatsBox/AchievementLabel
@onready var instability_label: Label = $Panel/StatsBox/InstabilityLabel
@onready var warning_sfx: AudioStreamPlayer = $WarningSfx

var _previous_stage := 0
var _expansion_label: Label = null
var _expansion_flash: ColorRect = null
var _critical_label: Label = null
var _critical_flash: ColorRect = null

func _ready() -> void:
	_create_critical_flash()
	_create_critical_label()
	_create_expansion_flash()
	_create_expansion_label()

func update_stats(vision_text: String, achievement: int, instability: int, stage: int, critical_state: bool = false) -> void:
	vision_label.text = "Vision: %s" % vision_text
	achievement_label.text = "Achievement: %d" % achievement
	instability_label.text = "Instability: %d%s" % [instability, "  CRITICAL" if critical_state else ""]
	instability_label.add_theme_color_override("font_color", _get_instability_color(instability))

	if stage > _previous_stage:
		_play_warning_sfx(stage)
	_previous_stage = stage

func show_critical_sequence() -> void:
	_pulse_instability_label()
	_flash_critical_screen()
	if _critical_label == null:
		return
	_critical_label.text = CRITICAL_MESSAGE
	_critical_label.visible = true
	_critical_label.modulate = Color(1.0, 0.2, 0.16, 1.0)

	var base_position := _critical_label.position
	var tween := create_tween()
	tween.tween_property(_critical_label, "position:x", base_position.x + 5.0, 0.04)
	tween.tween_property(_critical_label, "position:x", base_position.x - 5.0, 0.04)
	tween.tween_property(_critical_label, "position:x", base_position.x + 3.0, 0.04)
	tween.tween_property(_critical_label, "position:x", base_position.x, 0.04)
	tween.tween_interval(1.2)
	tween.tween_property(_critical_label, "modulate:a", 0.0, 0.65)
	await tween.finished
	_critical_label.visible = false

func _get_instability_color(value: int) -> Color:
	if value >= 81:
		return Color(0.92, 0.12, 0.16)
	if value >= 61:
		return Color(1.0, 0.48, 0.12)
	if value >= 31:
		return Color(0.95, 0.78, 0.18)
	return Color(0.35, 0.86, 0.45)

func _play_warning_sfx(stage: int) -> void:
	var stream: AudioStream = WARNING_STINGS.get(stage, null)
	if stream == null:
		return
	warning_sfx.stop()
	warning_sfx.stream = stream
	warning_sfx.play()

func show_expansion_feedback() -> void:
	if _expansion_label == null:
		return
	_pulse_instability_label()
	_flash_screen()
	_expansion_label.text = "Maze expanding..."
	_expansion_label.visible = true
	_expansion_label.modulate = Color(1.0, 0.82, 0.22, 1.0)
	var base_position := _expansion_label.position
	var tween := create_tween()
	tween.tween_property(_expansion_label, "position:x", base_position.x + 4.0, 0.04)
	tween.tween_property(_expansion_label, "position:x", base_position.x - 4.0, 0.04)
	tween.tween_property(_expansion_label, "position:x", base_position.x, 0.04)
	tween.tween_property(_expansion_label, "modulate:a", 0.0, 1.1)
	await tween.finished
	_expansion_label.visible = false

func _create_expansion_label() -> void:
	_expansion_label = Label.new()
	_expansion_label.visible = false
	_expansion_label.text = "Maze expanding..."
	_expansion_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expansion_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_expansion_label.offset_left = 0.0
	_expansion_label.offset_top = 0.0
	_expansion_label.offset_right = 0.0
	_expansion_label.offset_bottom = 0.0
	_expansion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_expansion_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_expansion_label.z_index = 20
	_expansion_label.theme_type_variation = "HeaderSmall"
	_expansion_label.add_theme_font_size_override("font_size", 16)
	_expansion_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.22))
	add_child(_expansion_label)

func _create_critical_label() -> void:
	_critical_label = Label.new()
	_critical_label.visible = false
	_critical_label.text = CRITICAL_MESSAGE
	_critical_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_critical_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_critical_label.offset_left = 0.0
	_critical_label.offset_top = 0.0
	_critical_label.offset_right = 0.0
	_critical_label.offset_bottom = 0.0
	_critical_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_critical_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_critical_label.z_index = 20
	_critical_label.theme_type_variation = "HeaderSmall"
	_critical_label.add_theme_font_size_override("font_size", 16)
	_critical_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.16))
	add_child(_critical_label)

func _create_expansion_flash() -> void:
	_expansion_flash = ColorRect.new()
	_expansion_flash.visible = false
	_expansion_flash.color = Color(1.0, 0.82, 0.22, 0.0)
	_expansion_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expansion_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_expansion_flash)

func _create_critical_flash() -> void:
	_critical_flash = ColorRect.new()
	_critical_flash.visible = false
	_critical_flash.color = Color(1.0, 0.08, 0.06, 0.0)
	_critical_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_critical_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_critical_flash)

func _flash_screen() -> void:
	if _expansion_flash == null:
		return
	_expansion_flash.visible = true
	_expansion_flash.color = Color(1.0, 0.82, 0.22, 0.16)
	var tween := create_tween()
	tween.tween_property(_expansion_flash, "color:a", 0.0, 0.45)
	await tween.finished
	_expansion_flash.visible = false

func _flash_critical_screen() -> void:
	if _critical_flash == null:
		return
	_critical_flash.visible = true
	_critical_flash.color = Color(1.0, 0.08, 0.06, 0.18)
	var tween := create_tween()
	tween.tween_property(_critical_flash, "color:a", 0.0, 0.55)
	await tween.finished
	_critical_flash.visible = false

func _pulse_instability_label() -> void:
	var base_scale := instability_label.scale
	var tween := create_tween()
	tween.tween_property(instability_label, "scale", base_scale * 1.16, 0.08)
	tween.tween_property(instability_label, "scale", base_scale, 0.16)
