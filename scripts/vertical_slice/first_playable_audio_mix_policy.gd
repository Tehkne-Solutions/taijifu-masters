class_name FirstPlayableAudioMixPolicy
extends RefCounted

const PREF_PATH := "user://taijifu_audio_accessibility.cfg"
const PROFILE_STANDARD: StringName = &"standard"
const PROFILE_COMBAT_FOCUS: StringName = &"combat_focus"
const PROFILE_REDUCED_DYNAMICS: StringName = &"reduced_dynamics"
const PROFILE_MONO_ACCESSIBLE: StringName = &"mono_accessible"
const PROFILES: Array[StringName] = [
	PROFILE_STANDARD,
	PROFILE_COMBAT_FOCUS,
	PROFILE_REDUCED_DYNAMICS,
	PROFILE_MONO_ACCESSIBLE,
]
const MASTER_THRESHOLD := 0.68
const MASTER_CEILING := 0.86
const LEVEL_STEP := 0.10

var _profile_id: StringName = PROFILE_STANDARD
var _master_level := 1.0
var _combat_level := 1.0
var _ambience_level := 0.78
var _ui_level := 0.90
var _peak_observed := 0.0

func load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(PREF_PATH) != OK:
		return
	var profile := StringName(config.get_value("audio", "profile", String(PROFILE_STANDARD)))
	if PROFILES.has(profile):
		_profile_id = profile
	_master_level = _sanitize_level(float(config.get_value("audio", "master", 1.0)))
	_combat_level = _sanitize_level(float(config.get_value("audio", "combat", 1.0)))
	_ambience_level = _sanitize_level(float(config.get_value("audio", "ambience", 0.78)))
	_ui_level = _sanitize_level(float(config.get_value("audio", "ui", 0.90)))

func save_preferences() -> bool:
	var config := ConfigFile.new()
	config.set_value("audio", "profile", String(_profile_id))
	config.set_value("audio", "master", _master_level)
	config.set_value("audio", "combat", _combat_level)
	config.set_value("audio", "ambience", _ambience_level)
	config.set_value("audio", "ui", _ui_level)
	return config.save(PREF_PATH) == OK

func profile_id() -> StringName:
	return _profile_id

func profile_ids() -> Array[StringName]:
	return PROFILES.duplicate()

func set_profile(profile_id: StringName, persist: bool = true) -> bool:
	if not PROFILES.has(profile_id):
		return false
	_profile_id = profile_id
	if persist:
		save_preferences()
	return true

func cycle_profile() -> StringName:
	var index := PROFILES.find(_profile_id)
	if index < 0:
		index = 0
	_profile_id = PROFILES[(index + 1) % PROFILES.size()]
	save_preferences()
	return _profile_id

func level(channel_id: StringName) -> float:
	match channel_id:
		&"master": return _master_level
		&"combat": return _combat_level
		&"ambience": return _ambience_level
		&"ui": return _ui_level
		_: return 1.0

func set_level(channel_id: StringName, value: float, persist: bool = true) -> bool:
	var sanitized := _sanitize_level(value)
	match channel_id:
		&"master": _master_level = sanitized
		&"combat": _combat_level = sanitized
		&"ambience": _ambience_level = sanitized
		&"ui": _ui_level = sanitized
		_: return false
	if persist:
		save_preferences()
	return true

func adjust_level(channel_id: StringName, delta: float) -> float:
	var current := level(channel_id)
	if not set_level(channel_id, current + delta, true):
		return current
	return level(channel_id)

func adjust_level_step(channel_id: StringName, direction: int) -> float:
	return adjust_level(channel_id, LEVEL_STEP * signi(direction))

func apply_pan(pan: float) -> float:
	return clampf(pan * _profile_pan_multiplier(), -1.0, 1.0)

func shape_cue_amplitude(amplitude: float) -> float:
	var safe := maxf(0.0, amplitude)
	if _profile_id == PROFILE_REDUCED_DYNAMICS:
		# Pull loud cues down while lifting very quiet cues toward a stable center.
		return clampf(lerpf(0.12, safe, 0.62), 0.0, 0.42)
	return safe

func master_frame(frame: Vector2, channel_id: StringName) -> Vector2:
	var gain := _master_level * _channel_profile_gain(channel_id)
	var mixed := frame * gain
	var mastered := Vector2(_limit_sample(mixed.x), _limit_sample(mixed.y))
	_peak_observed = maxf(_peak_observed, maxf(absf(mastered.x), absf(mastered.y)))
	return mastered

func peak_observed() -> float:
	return _peak_observed

func reset_peak_observed() -> void:
	_peak_observed = 0.0

func master_ceiling() -> float:
	return MASTER_CEILING

func snapshot() -> Dictionary:
	return {
		"profile": _profile_id,
		"master": _master_level,
		"combat": _combat_level,
		"ambience": _ambience_level,
		"ui": _ui_level,
		"profile_combat_gain": _profile_channel_multiplier(&"combat"),
		"profile_ambience_gain": _profile_channel_multiplier(&"ambience"),
		"profile_ui_gain": _profile_channel_multiplier(&"ui"),
		"pan_multiplier": _profile_pan_multiplier(),
		"master_threshold": MASTER_THRESHOLD,
		"master_ceiling": MASTER_CEILING,
		"peak_observed": _peak_observed,
		"preferences_path": PREF_PATH,
		"persistent": true,
		"signature": "Tehkné Solutions"
	}

func _channel_profile_gain(channel_id: StringName) -> float:
	return level(channel_id) * _profile_channel_multiplier(channel_id)

func _profile_channel_multiplier(channel_id: StringName) -> float:
	match _profile_id:
		PROFILE_COMBAT_FOCUS:
			match channel_id:
				&"combat": return 1.08
				&"ambience": return 0.50
				&"ui": return 0.95
		PROFILE_REDUCED_DYNAMICS:
			match channel_id:
				&"combat": return 0.88
				&"ambience": return 0.92
				&"ui": return 0.96
		PROFILE_MONO_ACCESSIBLE:
			match channel_id:
				&"combat": return 0.94
				&"ambience": return 0.80
				&"ui": return 1.0
	return 1.0

func _profile_pan_multiplier() -> float:
	match _profile_id:
		PROFILE_REDUCED_DYNAMICS: return 0.72
		PROFILE_MONO_ACCESSIBLE: return 0.0
		_: return 1.0

func _limit_sample(sample: float) -> float:
	var magnitude := absf(sample)
	if magnitude <= MASTER_THRESHOLD:
		return sample
	var excess := magnitude - MASTER_THRESHOLD
	var compressed := MASTER_THRESHOLD + excess / (1.0 + excess * 4.0)
	return signf(sample) * minf(compressed, MASTER_CEILING)

func _sanitize_level(value: float) -> float:
	return snappedf(clampf(value, 0.0, 1.0), 0.05)

# Tehkné Solutions
