extends CanvasLayer
##
## M4 HUD for Vision / Achievement / Instability.
##
## Also owns the one-shot generated warning tone when instability crosses a
## higher stage threshold.

const WARNING_MIX_RATE := 22050
const WARNING_DURATION := 0.16
const WARNING_VOLUME := 0.18

@onready var vision_label: Label = $Panel/StatsBox/VisionLabel
@onready var achievement_label: Label = $Panel/StatsBox/AchievementLabel
@onready var instability_label: Label = $Panel/StatsBox/InstabilityLabel
@onready var warning_sfx: AudioStreamPlayer = $WarningSfx

var _previous_stage := 0

func _ready() -> void:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = WARNING_MIX_RATE
	generator.buffer_length = WARNING_DURATION
	warning_sfx.stream = generator

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
	var frequency := 330.0 + float(stage) * 140.0
	for i in frame_count:
		var t := float(i) / float(WARNING_MIX_RATE)
		var fade := 1.0 - float(i) / float(frame_count)
		var sample := sin(TAU * frequency * t) * WARNING_VOLUME * fade
		playback.push_frame(Vector2(sample, sample))
