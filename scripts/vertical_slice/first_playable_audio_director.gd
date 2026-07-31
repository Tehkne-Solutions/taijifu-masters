class_name FirstPlayableAudioDirector
extends Node

const CONNECT_INTERVAL := 0.35

var _connect_timer := 0.0
var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "CombatAudioPlayer"
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.35
	_player.stream = stream
	_player.volume_db = -13.0
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	_connect_fighters()

func _process(delta: float) -> void:
	_connect_timer -= delta
	if _connect_timer <= 0.0:
		_connect_timer = CONNECT_INTERVAL
		_connect_fighters()

func presentation_signature() -> Dictionary:
	return {
		"impact_audio": true,
		"procedural_audio": true,
		"external_audio_assets_required": false,
		"balance_changes": false,
		"signature": "Tehkné Solutions"
	}

func _connect_fighters() -> void:
	for fighter in get_tree().get_nodes_in_group("fighters"):
		if fighter.has_signal("impact_resolved"):
			var callback := Callable(self, "_on_impact_resolved")
			if not fighter.is_connected("impact_resolved", callback):
				fighter.connect("impact_resolved", callback)

func _on_impact_resolved(
	_target: Node,
	_attacker: Node,
	_technique: Resource,
	result_id: StringName,
	_damage_applied: float,
	_posture_applied: float,
	intensity: float,
	_world_position: Vector2
) -> void:
	match result_id:
		&"evaded": _emit_tone(560.0, 0.055, 0.10)
		&"blocked": _emit_tone(180.0, 0.075, 0.18)
		&"parried": _emit_tone(880.0, 0.070, 0.22)
		&"posture_break": _emit_tone(92.0, 0.150, 0.34)
		_: _emit_tone(125.0 + intensity * 85.0, 0.085, 0.18 + intensity * 0.12)

func _emit_tone(frequency: float, duration: float, amplitude: float) -> void:
	if not is_instance_valid(_playback):
		return
	var frames := mini(int(22050.0 * duration), _playback.get_frames_available())
	for index in range(frames):
		var t := float(index) / 22050.0
		var envelope := 1.0 - float(index) / maxf(1.0, float(frames))
		var sample := sin(TAU * frequency * t) * amplitude * envelope
		_playback.push_frame(Vector2(sample, sample))

# Tehkné Solutions