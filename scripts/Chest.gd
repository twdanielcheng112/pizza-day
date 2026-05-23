extends Area2D

const CHEST_SFX_MIX_RATE := 22050
const CHEST_SFX_DURATION := 0.18
const CHEST_SFX_VOLUME := 0.15

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _sfx_player: AudioStreamPlayer = $SfxPlayer

var _is_open := false

func _ready() -> void:
	add_to_group("interactable")
	if _sprite:
		_sprite.frame = 0
	_setup_sfx_player()

func interact(player: Node = null) -> void:
	if _is_open:
		return

	_is_open = true

	if _sprite and _sprite.hframes >= 2:
		_sprite.frame = 1

	if is_in_group("interactable"):
		remove_from_group("interactable")

	if player and player.has_method("on_chest_opened"):
		player.on_chest_opened(self)

	_play_open_sfx()

func _setup_sfx_player() -> void:
	if _sfx_player == null:
		_sfx_player = AudioStreamPlayer.new()
		_sfx_player.name = "SfxPlayer"
		add_child(_sfx_player)
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = CHEST_SFX_MIX_RATE
	generator.buffer_length = CHEST_SFX_DURATION
	_sfx_player.stream = generator
	_sfx_player.volume_db = -8.0

func _play_open_sfx() -> void:
	_sfx_player.play()
	var playback := _sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var frame_count := int(CHEST_SFX_DURATION * CHEST_SFX_MIX_RATE)
	for i in frame_count:
		var t := float(i) / float(CHEST_SFX_MIX_RATE)
		var progress := float(i) / float(frame_count)
		var body_freq: float = lerpf(210.0, 140.0, progress)
		var body := sin(TAU * body_freq * t)
		body += 0.45 * sin(TAU * (body_freq * 0.55) * t)
		var click: float = sin(TAU * 980.0 * t) * maxf(0.0, 1.0 - progress * 7.0)
		var envelope: float = 1.0 - progress
		var sample: float = (body * 0.72 + click * 0.28) * CHEST_SFX_VOLUME * envelope
		playback.push_frame(Vector2(sample, sample))
