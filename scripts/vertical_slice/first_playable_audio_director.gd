class_name FirstPlayableAudioDirector
extends Node

signal cue_emitted(cue_id: StringName, intensity: float)

const CONNECT_INTERVAL := 0.35
const MIX_RATE := 44100.0
const WORLD_AUDIO_CENTER_X := 1400.0
const WORLD_AUDIO_HALF_WIDTH := 1400.0
const MAX_WORLD_PAN := 0.42

const CUE_HIT := &"hit"
const CUE_EVADE := &"evade"
const CUE_BLOCK := &"block"
const CUE_PARRY := &"parry"
const CUE_POSTURE_BREAK := &"posture_break"
const CUE_COUNTDOWN := &"countdown"
const CUE_FIGHT := &"fight"
const CUE_KO := &"ko"
const CUE_TIMEOUT := &"timeout"
const CUE_ROUND_WIN := &"round_win"
const CUE_ROUND_LOSS := &"round_loss"
const CUE_UI_PAUSE := &"ui_pause"
const CUE_UI_RESUME := &"ui_resume"
const CUE_UI_SELECT := &"ui_select"
const CUE_UI_CONFIRM := &"ui_confirm"

var _connect_timer := 0.0
var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _cue_counts: Dictionary = {}
var _last_cue: StringName = &""
var _last_pan := 0.0
var _connected_fighter_ids: Dictionary = {}
var _presentation_connected := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "CombatAudioPlayer"
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = 0.50
	_player.stream = stream
	_player.volume_db = -10.5
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	_connect_parent_presentation()
	_connect_fighters()

func _process(delta: float) -> void:
	_connect_timer -= delta
	if _connect_timer <= 0.0:
		_connect_timer = CONNECT_INTERVAL
		_connect_parent_presentation()
		_connect_fighters()

func presentation_signature() -> Dictionary:
	return {
		"stage": "AUDIO-02",
		"impact_audio": true,
		"round_audio": true,
		"ui_audio": true,
		"procedural_audio": true,
		"canonical_sound_design": true,
		"procedural_layering": true,
		"deterministic_recipes": true,
		"stereo_spatialization": true,
		"mix_rate_hz": int(MIX_RATE),
		"external_audio_assets_required": false,
		"event_consumer_only": true,
		"gameplay_timing_owner": false,
		"damage_owner": false,
		"ai_owner": false,
		"cue_telemetry": true,
		"impact_cues": ["hit", "evade", "block", "parry", "posture_break"],
		"round_cues": ["countdown", "fight", "ko", "timeout", "round_win", "round_loss"],
		"ui_cues": ["ui_pause", "ui_resume", "ui_select", "ui_confirm"],
		"remaining_audio_scope": ["arena_ambience", "music", "final_mastering", "accessibility_mix_controls"],
		"balance_changes": false,
		"signature": "Tehkné Solutions"
	}

func canonical_cue_ids() -> Array[StringName]:
	return [
		CUE_HIT,
		CUE_EVADE,
		CUE_BLOCK,
		CUE_PARRY,
		CUE_POSTURE_BREAK,
		CUE_COUNTDOWN,
		CUE_FIGHT,
		CUE_KO,
		CUE_TIMEOUT,
		CUE_ROUND_WIN,
		CUE_ROUND_LOSS,
		CUE_UI_PAUSE,
		CUE_UI_RESUME,
		CUE_UI_SELECT,
		CUE_UI_CONFIRM,
	]

func cue_recipe(cue_id: StringName) -> Dictionary:
	match cue_id:
		CUE_HIT:
			return _recipe([118.0, 176.0, 410.0], 0.085, 0.27, -24.0, 1.85)
		CUE_EVADE:
			return _recipe([520.0, 760.0], 0.065, 0.12, 80.0, 2.30)
		CUE_BLOCK:
			return _recipe([148.0, 296.0, 592.0], 0.110, 0.22, -12.0, 1.70)
		CUE_PARRY:
			return _recipe([880.0, 1320.0, 1760.0], 0.180, 0.19, -30.0, 0.92)
		CUE_POSTURE_BREAK:
			return _recipe([72.0, 108.0, 216.0], 0.220, 0.33, -38.0, 1.45)
		CUE_COUNTDOWN:
			return _recipe([294.0, 440.0], 0.120, 0.13, 24.0, 1.80)
		CUE_FIGHT:
			return _recipe([392.0, 659.0, 988.0], 0.220, 0.23, 80.0, 1.15)
		CUE_KO:
			return _recipe([82.0, 123.0, 246.0], 0.380, 0.34, -55.0, 1.28)
		CUE_TIMEOUT:
			return _recipe([190.0, 285.0], 0.260, 0.18, -75.0, 1.20)
		CUE_ROUND_WIN:
			return _recipe([523.0, 659.0, 784.0], 0.320, 0.18, 85.0, 1.05)
		CUE_ROUND_LOSS:
			return _recipe([196.0, 147.0, 98.0], 0.360, 0.19, -50.0, 1.10)
		CUE_UI_PAUSE:
			return _recipe([220.0, 330.0], 0.080, 0.08, -18.0, 2.00)
		CUE_UI_RESUME:
			return _recipe([330.0, 440.0], 0.080, 0.08, 22.0, 2.00)
		CUE_UI_SELECT:
			return _recipe([440.0, 660.0], 0.055, 0.07, 35.0, 2.40)
		CUE_UI_CONFIRM:
			return _recipe([523.0, 784.0], 0.070, 0.09, 42.0, 2.20)
		_:
			return _recipe([220.0], 0.070, 0.08, 0.0, 2.00)

func cue_count(cue_id: StringName) -> int:
	return int(_cue_counts.get(cue_id, 0))

func last_cue_id() -> StringName:
	return _last_cue

func last_pan() -> float:
	return _last_pan

func connected_fighter_count() -> int:
	return _connected_fighter_ids.size()

func presentation_connected() -> bool:
	return _presentation_connected

func _connect_parent_presentation() -> void:
	var controller := get_parent()
	if controller == null or not controller.has_signal("presentation_cue_requested"):
		return
	var callback := Callable(self, "_on_presentation_cue_requested")
	if not controller.is_connected("presentation_cue_requested", callback):
		controller.connect("presentation_cue_requested", callback)
	_presentation_connected = true

func _connect_fighters() -> void:
	for fighter in get_tree().get_nodes_in_group("fighters"):
		if fighter == null or not is_instance_valid(fighter):
			continue
		if fighter.has_signal("impact_resolved"):
			var callback := Callable(self, "_on_impact_resolved")
			if not fighter.is_connected("impact_resolved", callback):
				fighter.connect("impact_resolved", callback)
			_connected_fighter_ids[fighter.get_instance_id()] = true

func _on_presentation_cue_requested(cue_id: StringName, intensity: float) -> void:
	_dispatch_cue(cue_id, clampf(intensity, 0.0, 1.0), 0.0)

func _on_impact_resolved(
	_target: Node,
	_attacker: Node,
	_technique: Resource,
	result_id: StringName,
	_damage_applied: float,
	_posture_applied: float,
	intensity: float,
	world_position: Vector2
) -> void:
	var cue_id := CUE_HIT
	match result_id:
		&"evaded": cue_id = CUE_EVADE
		&"blocked": cue_id = CUE_BLOCK
		&"parried": cue_id = CUE_PARRY
		&"posture_break": cue_id = CUE_POSTURE_BREAK
		_: cue_id = CUE_HIT
	_dispatch_cue(cue_id, clampf(intensity, 0.0, 1.0), _pan_for_world_position(world_position))

func _dispatch_cue(cue_id: StringName, intensity: float, pan: float) -> void:
	_last_cue = cue_id
	_last_pan = clampf(pan, -MAX_WORLD_PAN, MAX_WORLD_PAN)
	_cue_counts[cue_id] = cue_count(cue_id) + 1
	cue_emitted.emit(cue_id, intensity)
	var recipe := cue_recipe(cue_id)
	var amplitude := float(recipe["amplitude"]) * lerpf(0.72, 1.0, intensity)
	_emit_layered(
		recipe["frequencies"],
		float(recipe["duration"]),
		amplitude,
		float(recipe["sweep_hz"]),
		float(recipe["decay_power"]),
		_last_pan
	)

func _recipe(frequencies: Array, duration: float, amplitude: float, sweep_hz: float, decay_power: float) -> Dictionary:
	return {
		"frequencies": frequencies,
		"duration": duration,
		"amplitude": amplitude,
		"sweep_hz": sweep_hz,
		"decay_power": decay_power,
	}

func _pan_for_world_position(world_position: Vector2) -> float:
	if world_position == Vector2.ZERO:
		return 0.0
	var normalized := (world_position.x - WORLD_AUDIO_CENTER_X) / WORLD_AUDIO_HALF_WIDTH
	return clampf(normalized * MAX_WORLD_PAN, -MAX_WORLD_PAN, MAX_WORLD_PAN)

func _emit_layered(
	frequencies: Array,
	duration: float,
	amplitude: float,
	sweep_hz: float,
	decay_power: float,
	pan: float
) -> void:
	if not is_instance_valid(_playback):
		return
	var requested_frames := int(MIX_RATE * duration)
	var frames := mini(requested_frames, _playback.get_frames_available())
	if frames <= 0:
		return
	var left_gain := sqrt(0.5 * (1.0 - pan))
	var right_gain := sqrt(0.5 * (1.0 + pan))
	for index in range(frames):
		var t := float(index) / MIX_RATE
		var normalized := float(index) / maxf(1.0, float(frames - 1))
		var envelope := pow(maxf(0.0, 1.0 - normalized), decay_power)
		var sample := 0.0
		for raw_frequency in frequencies:
			var frequency := maxf(20.0, float(raw_frequency) + sweep_hz * normalized)
			sample += sin(TAU * frequency * t)
		sample /= maxf(1.0, float(frequencies.size()))
		sample = clampf(sample * amplitude * envelope, -0.95, 0.95)
		_playback.push_frame(Vector2(sample * left_gain, sample * right_gain))

# Tehkné Solutions
