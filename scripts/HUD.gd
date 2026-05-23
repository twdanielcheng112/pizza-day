extends CanvasLayer
##
## M4 HUD for Vision / Achievement / Instability.
##
## Also owns the one-shot generated warning tone when instability crosses a
## higher stage threshold.

const WARNING_MIX_RATE := 22050
const WARNING_DURATION := 0.64
const WARNING_VOLUME := 0.24

@onready var vision_label: Label = $Panel/StatsBox/VisionLabel
@onready var achievement_label: Label = $Panel/StatsBox/AchievementLabel
@onready var instability_label: Label = $Panel/StatsBox/InstabilityLabel
@onready var warning_sfx: AudioStreamPlayer = $WarningSfx

var _previous_stage := 0
var _expansion_label: Label = null
var _expansion_flash: ColorRect = null

func _ready() -> void:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = WARNING_MIX_RATE
	generator.buffer_length = WARNING_DURATION
	warning_sfx.stream = generator
	_create_expansion_flash()
	_create_expansion_label()

func update_stats(vision_text: String, achievement: int, instability: int, stage: int) -> void:
	vision_label.text = "Vision: %s" % vision_text
	achievement_label.text = "Achievement: %d" % achievement
	instability_label.text = "Instability: %d" % instability
	instability_label.add_theme_color_override("font_color", _get_instability_color(instability))

	if stage > _previous_stage:
		_play_warning_sfx(stage)
	_previous_stage = stage

func _get_instability_color(value: int) -> Color:
	if value >= 81:
		return Color(0.92, 0.12, 0.16)
	if value >= 61:
		return Color(1.0, 0.48, 0.12)
	if value >= 31:
		return Color(0.95, 0.78, 0.18)
	return Color(0.35, 0.86, 0.45)

func _play_warning_sfx(stage: int) -> void:
	warning_sfx.play()
	var playback := warning_sfx.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var frame_count := int(WARNING_DURATION * WARNING_MIX_RATE)
	var pulse_count: int = clampi(stage + 1, 2, 4)
	var low_frequency := 420.0 + float(stage) * 90.0
	var high_frequency := 760.0 + float(stage) * 150.0
	for i in frame_count:
		var t: float = float(i) / float(WARNING_MIX_RATE)
		var progress: float = float(i) / float(frame_count)
		var pulse_phase: float = fmod(progress * float(pulse_count), 1.0)
		var gate: float = 1.0 if pulse_phase < 0.58 else 0.0
		var sweep: float = 1.0 - pulse_phase
		var frequency: float = lerpf(low_frequency, high_frequency, sweep)
		var attack: float = minf(pulse_phase / 0.08, 1.0)
		var release: float = minf((0.58 - pulse_phase) / 0.16, 1.0)
		var envelope: float = clampf(minf(attack, release), 0.0, 1.0) * gate
		var sine: float = sin(TAU * frequency * t)
		var square: float = 1.0 if sine >= 0.0 else -1.0
		var harmonic: float = sin(TAU * frequency * 1.5 * t) * 0.28
		var sample: float = ((sine * 0.5) + (square * 0.34) + harmonic) * WARNING_VOLUME * envelope
		playback.push_frame(Vector2(sample, sample))

func show_expansion_feedback() -> void:
	if _expansion_label == null:
		return
	_pulse_instability_label()
	_flash_screen()
	_expansion_label.text = "Maze expanding..."
	_expansion_label.visible = true
	_expansion_label.modulate = Color(1.0, 0.82, 0.22, 1.0)
	var tween := create_tween()
	tween.tween_property(_expansion_label, "position:x", _expansion_label.position.x + 4.0, 0.04)
	tween.tween_property(_expansion_label, "position:x", _expansion_label.position.x - 4.0, 0.04)
	tween.tween_property(_expansion_label, "position:x", _expansion_label.position.x, 0.04)
	tween.tween_property(_expansion_label, "modulate:a", 0.0, 1.1)
	await tween.finished
	_expansion_label.visible = false

func _create_expansion_label() -> void:
	_expansion_label = Label.new()
	_expansion_label.visible = false
	_expansion_label.text = "Maze expanding..."
	_expansion_label.offset_left = 8.0
	_expansion_label.offset_top = 64.0
	_expansion_label.offset_right = 220.0
	_expansion_label.offset_bottom = 90.0
	_expansion_label.theme_type_variation = "HeaderSmall"
	_expansion_label.add_theme_font_size_override("font_size", 14)
	_expansion_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.22))
	add_child(_expansion_label)

func _create_expansion_flash() -> void:
	_expansion_flash = ColorRect.new()
	_expansion_flash.visible = false
	_expansion_flash.color = Color(1.0, 0.82, 0.22, 0.0)
	_expansion_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expansion_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_expansion_flash)

func _flash_screen() -> void:
	if _expansion_flash == null:
		return
	_expansion_flash.visible = true
	_expansion_flash.color = Color(1.0, 0.82, 0.22, 0.16)
	var tween := create_tween()
	tween.tween_property(_expansion_flash, "color:a", 0.0, 0.45)
	await tween.finished
	_expansion_flash.visible = false

func _pulse_instability_label() -> void:
	var base_scale := instability_label.scale
	var tween := create_tween()
	tween.tween_property(instability_label, "scale", base_scale * 1.16, 0.08)
	tween.tween_property(instability_label, "scale", base_scale, 0.16)
