class_name ModularFighterMotionLibrary
extends RefCounted

## Fail-closed loader and sampler for explicit authored skeletal keyframes.
## Runtime interpolation is allowed; runtime pose generation is not.
## Tehkné Solutions

const SCHEMA := "taijifu.modular_fighter_motion_library"
const VERSION := 1
const AUTHORING_MODE := "explicit_keyframes"
const INTERPOLATION := "linear"
const REQUIRED_BONES := [
	"pelvis", "torso", "head", "upper_arm_l", "forearm_l", "upper_arm_r", "forearm_r",
	"thigh_l", "shin_l", "thigh_r", "shin_r",
]
const REQUIRED_CLIPS := [
	"idle", "run", "jump_start", "airborne", "fall",
	"attack_anticipation", "attack_contact", "attack_recovery",
	"guard", "dodge", "hit", "ko",
]

var _clips: Dictionary = {}
var _library_id := ""
var _source_path := ""
var _source_sha256 := ""
var _valid := false
var _errors := PackedStringArray()

func load_from_path(path: String) -> PackedStringArray:
	_reset()
	_source_path = path
	if not FileAccess.file_exists(path):
		_errors.append("motion_library_missing:%s" % path)
		return _errors.duplicate()

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		_errors.append("motion_library_json_invalid")
		return _errors.duplicate()
	var root := parsed as Dictionary

	if String(root.get("schema", "")) != SCHEMA:
		_errors.append("motion_library_schema")
	if int(root.get("version", -1)) != VERSION:
		_errors.append("motion_library_version")
	if String(root.get("authoring_mode", "")) != AUTHORING_MODE:
		_errors.append("motion_library_authoring_mode")
	if String(root.get("interpolation", "")) != INTERPOLATION:
		_errors.append("motion_library_interpolation")
	if String(root.get("signature", "")) != "Tehkné Solutions":
		_errors.append("motion_library_signature")

	_library_id = String(root.get("library_id", ""))
	if _library_id == "":
		_errors.append("motion_library_id")

	_validate_required_bones(root.get("required_bones", []))
	_validate_required_clip_list(root.get("required_clips", []))

	var clips_variant: Variant = root.get("clips", {})
	if not (clips_variant is Dictionary):
		_errors.append("motion_library_clips_invalid")
		return _errors.duplicate()
	var clips := clips_variant as Dictionary
	if clips.size() != REQUIRED_CLIPS.size():
		_errors.append("motion_library_clip_count:%d" % clips.size())
	for clip_id in REQUIRED_CLIPS:
		if not clips.has(clip_id):
			_errors.append("motion_library_clip_missing:%s" % clip_id)
			continue
		_validate_clip(clip_id, clips[clip_id])

	if not _errors.is_empty():
		return _errors.duplicate()

	_clips = clips.duplicate(true)
	_source_sha256 = FileAccess.get_sha256(path)
	_valid = true
	return _errors.duplicate()

func valid() -> bool:
	return _valid

func clip_count() -> int:
	return _clips.size()

func library_id() -> String:
	return _library_id

func source_sha256() -> String:
	return _source_sha256

func errors() -> PackedStringArray:
	return _errors.duplicate()

func sample_clip(clip_id: String, elapsed_seconds: float, explicit_progress: float = -1.0) -> Dictionary:
	if not _valid or not _clips.has(clip_id):
		return {}
	var clip := _clips[clip_id] as Dictionary
	var frames := clip.get("keyframes", []) as Array
	if frames.size() < 2:
		return {}

	var progress := explicit_progress
	if progress < 0.0:
		var duration := maxf(0.0001, float(clip.get("duration", 1.0)))
		if bool(clip.get("loop", false)):
			progress = fposmod(maxf(0.0, elapsed_seconds), duration) / duration
		else:
			progress = clampf(maxf(0.0, elapsed_seconds) / duration, 0.0, 1.0)
	else:
		progress = clampf(progress, 0.0, 1.0)

	var lower := frames[0] as Dictionary
	var upper := frames[frames.size() - 1] as Dictionary
	for index in range(1, frames.size()):
		var candidate := frames[index] as Dictionary
		if progress <= float(candidate.get("t", 1.0)):
			lower = frames[index - 1] as Dictionary
			upper = candidate
			break

	var lower_t := float(lower.get("t", 0.0))
	var upper_t := float(upper.get("t", 1.0))
	var span := upper_t - lower_t
	var alpha := 0.0 if span <= 0.000001 else clampf((progress - lower_t) / span, 0.0, 1.0)
	var result: Dictionary = {}
	for bone_name in REQUIRED_BONES:
		var a := _bone_transform(lower, bone_name)
		var b := _bone_transform(upper, bone_name)
		var a_position := _transform_position(a)
		var b_position := _transform_position(b)
		result[bone_name] = {
			"rotation": lerpf(float(a.get("rotation", 0.0)), float(b.get("rotation", 0.0)), alpha),
			"position": [
				lerpf(a_position.x, b_position.x, alpha),
				lerpf(a_position.y, b_position.y, alpha),
			],
		}
	return result

func presentation_signature() -> Dictionary:
	return {
		"library_id": _library_id,
		"valid": _valid,
		"schema": SCHEMA,
		"version": VERSION,
		"authoring_mode": AUTHORING_MODE,
		"interpolation": INTERPOLATION,
		"clip_count": clip_count(),
		"required_clip_count": REQUIRED_CLIPS.size(),
		"required_bone_count": REQUIRED_BONES.size(),
		"source_path": _source_path,
		"source_sha256": _source_sha256,
		"runtime_interpolation": true,
		"runtime_pose_generation": false,
		"procedural_pose_functions": false,
		"signature": "Tehkné Solutions",
	}

func _validate_required_bones(value: Variant) -> void:
	if not (value is Array):
		_errors.append("motion_library_required_bones_invalid")
		return
	var declared := value as Array
	if declared.size() != REQUIRED_BONES.size():
		_errors.append("motion_library_required_bone_count:%d" % declared.size())
	for bone_name in REQUIRED_BONES:
		if not declared.has(bone_name):
			_errors.append("motion_library_required_bone_missing:%s" % bone_name)

func _validate_required_clip_list(value: Variant) -> void:
	if not (value is Array):
		_errors.append("motion_library_required_clips_invalid")
		return
	var declared := value as Array
	if declared.size() != REQUIRED_CLIPS.size():
		_errors.append("motion_library_required_clip_count:%d" % declared.size())
	for clip_id in REQUIRED_CLIPS:
		if not declared.has(clip_id):
			_errors.append("motion_library_required_clip_missing:%s" % clip_id)

func _validate_clip(clip_id: String, value: Variant) -> void:
	if not (value is Dictionary):
		_errors.append("motion_library_clip_invalid:%s" % clip_id)
		return
	var clip := value as Dictionary
	var duration_value: Variant = clip.get("duration", null)
	if not _is_number(duration_value) or float(duration_value) <= 0.0:
		_errors.append("motion_library_duration:%s" % clip_id)
	if typeof(clip.get("loop", null)) != TYPE_BOOL:
		_errors.append("motion_library_loop:%s" % clip_id)
	var frames_variant: Variant = clip.get("keyframes", [])
	if not (frames_variant is Array):
		_errors.append("motion_library_keyframes:%s" % clip_id)
		return
	var frames := frames_variant as Array
	if frames.size() < 2:
		_errors.append("motion_library_keyframe_count:%s" % clip_id)
		return

	var previous_t := -1.0
	var authored_transform_count := 0
	for frame_index in range(frames.size()):
		var frame_variant: Variant = frames[frame_index]
		if not (frame_variant is Dictionary):
			_errors.append("motion_library_keyframe_invalid:%s:%d" % [clip_id, frame_index])
			continue
		var frame := frame_variant as Dictionary
		var t_value: Variant = frame.get("t", null)
		if not _is_number(t_value):
			_errors.append("motion_library_keyframe_t:%s:%d" % [clip_id, frame_index])
			continue
		var t := float(t_value)
		if t < -0.0001 or t > 1.0001 or t < previous_t:
			_errors.append("motion_library_keyframe_order:%s:%d" % [clip_id, frame_index])
		previous_t = t
		var bones_variant: Variant = frame.get("bones", {})
		if not (bones_variant is Dictionary):
			_errors.append("motion_library_bones:%s:%d" % [clip_id, frame_index])
			continue
		var bones := bones_variant as Dictionary
		for bone_name_variant in bones.keys():
			var bone_name := String(bone_name_variant)
			if not REQUIRED_BONES.has(bone_name):
				_errors.append("motion_library_unknown_bone:%s:%s" % [clip_id, bone_name])
				continue
			var transform_variant: Variant = bones[bone_name_variant]
			if not (transform_variant is Dictionary):
				_errors.append("motion_library_transform:%s:%s" % [clip_id, bone_name])
				continue
			var transform := transform_variant as Dictionary
			if transform.has("rotation") and not _is_number(transform["rotation"]):
				_errors.append("motion_library_rotation:%s:%s" % [clip_id, bone_name])
			if transform.has("position"):
				var position_variant: Variant = transform["position"]
				if not (position_variant is Array) or (position_variant as Array).size() != 2:
					_errors.append("motion_library_position:%s:%s" % [clip_id, bone_name])
				elif not _is_number((position_variant as Array)[0]) or not _is_number((position_variant as Array)[1]):
					_errors.append("motion_library_position_number:%s:%s" % [clip_id, bone_name])
			if not transform.is_empty():
				authored_transform_count += 1

	var first := frames[0] as Dictionary
	var last := frames[frames.size() - 1] as Dictionary
	if absf(float(first.get("t", -1.0))) > 0.0001:
		_errors.append("motion_library_first_keyframe:%s" % clip_id)
	if absf(float(last.get("t", -1.0)) - 1.0) > 0.0001:
		_errors.append("motion_library_last_keyframe:%s" % clip_id)
	if authored_transform_count <= 0:
		_errors.append("motion_library_empty_clip:%s" % clip_id)

func _bone_transform(frame: Dictionary, bone_name: String) -> Dictionary:
	var bones_variant: Variant = frame.get("bones", {})
	if not (bones_variant is Dictionary):
		return {}
	var bones := bones_variant as Dictionary
	var transform_variant: Variant = bones.get(bone_name, {})
	return transform_variant as Dictionary if transform_variant is Dictionary else {}

func _transform_position(transform: Dictionary) -> Vector2:
	var value: Variant = transform.get("position", [0.0, 0.0])
	if not (value is Array):
		return Vector2.ZERO
	var values := value as Array
	if values.size() != 2:
		return Vector2.ZERO
	return Vector2(float(values[0]), float(values[1]))

func _is_number(value: Variant) -> bool:
	var value_type := typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT

func _reset() -> void:
	_clips.clear()
	_library_id = ""
	_source_path = ""
	_source_sha256 = ""
	_valid = false
	_errors = PackedStringArray()

# Tehkné Solutions
