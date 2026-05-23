extends Area2D

const CORE_SFX_MIX_RATE := 22050
const CORE_SFX_DURATION := 0.30
const CORE_SFX_VOLUME := 0.20

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D
@onready var _sfx_player: AudioStreamPlayer = $SfxPlayer

var _picked := false

func _ready() -> void:
	add_to_group("interactable")
	_setup_sfx_player()

func interact(player: Node = null) -> void:
	if _picked:
		return
	_picked = true

	if is_in_group("interactable"):
		remove_from_group("interactable")
	if _sprite:
		_sprite.visible = false
	if _collision:
		_collision.disabled = true

	if player and player.has_method("on_vision_core_picked"):
		player.on_vision_core_picked(self)

	_play_pickup_sfx()
	await get_tree().create_timer(CORE_SFX_DURATION).timeout
	queue_free()

func _setup_sfx_player() -> void:
	if _sfx_player == null:
		_sfx_player = AudioStreamPlayer.new()
		_sfx_player.name = "SfxPlayer"
		add_child(_sfx_player)
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = CORE_SFX_MIX_RATE
	generator.buffer_length = CORE_SFX_DURATION
	_sfx_player.stream = generator
	_sfx_player.volume_db = -6.0

func _play_pickup_sfx() -> void:
	_sfx_player.play()
	var playback := _sfx_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return

	var frame_count := int(CORE_SFX_DURATION * CORE_SFX_MIX_RATE)
	for i in frame_count:
		var t := float(i) / float(CORE_SFX_MIX_RATE)
		var progress := float(i) / float(frame_count)
		var lead_freq: float = lerpf(520.0, 1240.0, progress)
		var shimmer_freq: float = lead_freq * 1.52
		var harmony_freq: float = lerpf(740.0, 980.0, progress)
		var envelope: float = pow(1.0 - progress, 1.2)
		var sparkle: float = maxf(0.0, 1.0 - progress * 2.2)
		var sample := sin(TAU * lead_freq * t)
		sample += 0.42 * sin(TAU * shimmer_freq * t)
		sample += 0.28 * sin(TAU * harmony_freq * t) * sparkle
		sample *= CORE_SFX_VOLUME * envelope
		playback.push_frame(Vector2(sample, sample))
