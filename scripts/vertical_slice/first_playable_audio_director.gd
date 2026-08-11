class_name FirstPlayableAudioDirector
extends Node

signal cue_emitted(cue_id: StringName, intensity: float)

const CONNECT_INTERVAL := 0.35
const CUE_HIT := &"hit"
const CUE_EVADE := &"evade"
const CUE_BLOCK := &"block"
const CUE_PARRY := &"parry"
const CUE_POSTURE_BREAK := &"posture_break"

var _connect_timer := 0.0
var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _cue_counts: Dictionary = {}
var _last_cue: StringName = &""
var _connected_fighter_ids: Dictionary = {}

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
		"stage": "AUDIO-01",
		"impact_audio": true,
		"procedural_audio": true,
		"external_audio_assets_required": false,
		"event_consumer_only": true,
		"gameplay_timing_owner": false,
		"damage_owner": false,
		"cue_telemetry": true,
		"impact_cues": ["hit", "evade", "block", "parry", "posture_break"],
		"future_canonical_cues": ["countdown", "fight", "ko", "round_result", "ui"],
		"balance_changes": false,
		"signature": "Tehkné Solutions"
	}

func cue_count(cue_id: StringName) -> int:
	return int(_cue_counts.get(cue_id, 0))

func last_cue_id() -> StringName:
	return _last_cue

func connected_fighter_count() -> int:
	return _connected_fighter_ids.size()

func _connect_fighters() -> void:
	for fighter in get_tree().get_nodes_in_group("fighters"):
		if fighter == null or not is_instance_valid(fighter):
			continue
		if fighter.has_signal("impact_resolved"):
			var callback := Callable(self, "_on_impact_resolved")
			if not fighter.is_connected("impact_resolved", callback):
				fighter.connect("impact_resolved", callback)
			_connected_fighter_ids[fighter.get_instance_id()] = true

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
	var cue_id := CUE_HIT
	match result_id:
		&"evaded": cue_id = CUE_EVADE
		&"blocked": cue_id = CUE_BLOCK
		&"parried": cue_id = CUE_PARRY
		&"posture_break": cue_id = CUE_POSTURE_BREAK
		_: cue_id = CUE_HIT
	_dispatch_impact_cue(cue_id, clampf(intensity, 0.0, 1.0))

func _dispatch_impact_cue(cue_id: StringName, intensity: float) -> void:
	_last_cue = cue_id
	_cue_counts[cue_id] = cue_count(cue_id) + 1
	cue_emitted.emit(cue_id, intensity)
	match cue_id:
		CUE_EVADE: _emit_tone(560.0, 0.055, 0.10)
		CUE_BLOCK: _emit_tone(180.0, 0.075, 0.18)
		CUE_PARRY: _emit_tone(880.0, 0.070, 0.22)
		CUE_POSTURE_BREAK: _emit_tone(92.0, 0.150, 0.34)
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
