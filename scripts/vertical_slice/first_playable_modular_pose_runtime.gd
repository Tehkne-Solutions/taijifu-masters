class_name FirstPlayableModularPoseRuntime
extends Node

## P0.2 bridge between the First Playable combat state and the BASE-00 skeletal
## pose rig. Runs after the modular presenter and owns combat-pose deformation
## only when the explicit authored motion library is valid. Fighter physics
## remains world authority.
## Tehkné Solutions

const TARGET_VISUAL_HEIGHT := 132.0
const RUNTIME_ID := "first_playable_modular_pose_runtime_v2"
const AUTHORITY_META := &"modular_skeletal_pose_authority"
const EXPECTED_AUTHORED_CLIPS := 12
const OBSERVED_BONES := [
	"pelvis", "torso", "head", "upper_arm_r", "forearm_r", "thigh_l", "thigh_r",
]

var _match: FirstPlayableController
var _fighter: FighterController
var _presenter: FirstPlayableModularFighterPresenter
var _assembler: ModularFighterAssembler
var _pose_rig: ModularFighterPoseRig
var _base_scale := 1.0
var _state: StringName = &"idle"
var _state_time := 0.0
var _activation_attempted := false
var _blocked_reason := ""

func _ready() -> void:
	process_priority = 100
	_match = get_parent() as FirstPlayableController

func _exit_tree() -> void:
	_clear_authority()

func _process(delta: float) -> void:
	_discover_and_activate()
	if _pose_rig == null or not _pose_rig.configured() or not is_instance_valid(_fighter):
		return

	var next_state := _presenter.visual_state() if is_instance_valid(_presenter) else &"idle"
	if next_state != _state:
		_state = next_state
		_state_time = 0.0
	else:
		_state_time += delta

	# FighterController remains the sole world-translation/collision owner. The
	# modular root keeps only canonical scale + facing mirror. Combat expression
	# belongs to authored Skeleton2D keyframes once AUTHORITY_META is active.
	var facing_sign := -1.0 if _fighter.facing < 0.0 else 1.0
	_assembler.position = Vector2.ZERO
	_assembler.rotation = 0.0
	_assembler.skew = 0.0
	_assembler.scale = Vector2(_base_scale * facing_sign, _base_scale)
	_pose_rig.apply_pose(
		_state,
		_state_time,
		_fighter._attack_phase,
		_fighter._attack_phase_timer,
		_fighter._current_technique
	)

func active() -> bool:
	return _pose_rig != null and _pose_rig.configured()

func pose_rig() -> ModularFighterPoseRig:
	return _pose_rig

func authority_active() -> bool:
	return (
		active()
		and is_instance_valid(_fighter)
		and bool(_fighter.get_meta(AUTHORITY_META, false))
	)

func deformation_signature() -> Dictionary:
	var samples: Dictionary = {}
	if active():
		for bone_name in OBSERVED_BONES:
			var bone := _pose_rig._bones.get(bone_name) as Bone2D
			if bone == null:
				continue
			samples[bone_name] = {
				"position": [bone.position.x, bone.position.y],
				"rotation": bone.rotation,
				"scale": [bone.scale.x, bone.scale.y],
			}
	return {
		"runtime": RUNTIME_ID,
		"active": active(),
		"authority_active": authority_active(),
		"visual_state": String(_state),
		"attack_pose_phase": _pose_rig.attack_pose_phase() if active() else "none",
		"bones": samples,
		"observed_bone_count": samples.size(),
		"assembler_position": [_assembler.position.x, _assembler.position.y] if is_instance_valid(_assembler) else [],
		"assembler_rotation": _assembler.rotation if is_instance_valid(_assembler) else 0.0,
		"assembler_skew": _assembler.skew if is_instance_valid(_assembler) else 0.0,
		"whole_assembler_combat_pose": false,
		"authored_animation": _authored_motion_active(),
		"signature": "Tehkné Solutions",
	}

func runtime_signature() -> Dictionary:
	var pose_signature := _pose_rig.runtime_signature() if _pose_rig != null else {}
	var authored := bool(pose_signature.get("authored_animation", false))
	var motion_library: Dictionary = pose_signature.get("motion_library", {}) if pose_signature.get("motion_library", {}) is Dictionary else {}
	return {
		"runtime": RUNTIME_ID,
		"active": active(),
		"authority_active": authority_active(),
		"blocked_reason": _blocked_reason,
		"visual_state": String(_state),
		"base_scale": _base_scale,
		"legacy_root_affine_neutralized": active(),
		"presenter_root_affine_bypassed": authority_active(),
		"world_translation_owner": "fighter_physics",
		"combat_pose_owner": "Skeleton2D",
		"collision_changes": false,
		"pose_rig": pose_signature,
		"authored_animation": authored,
		"motion_library_id": String(motion_library.get("library_id", "")),
		"motion_library_clip_count": int(motion_library.get("clip_count", 0)),
		"procedural_pose_functions": bool(pose_signature.get("procedural_pose_functions", true)),
		"signature": "Tehkné Solutions",
	}

func _discover_and_activate() -> void:
	if active() or _activation_attempted:
		return
	if not is_instance_valid(_match):
		_match = get_parent() as FirstPlayableController
	if not is_instance_valid(_match) or not is_instance_valid(_match.player_one):
		return
	_fighter = _match.player_one
	_presenter = _fighter.get_node_or_null("FirstPlayableModularFighterPresenter") as FirstPlayableModularFighterPresenter
	if _presenter == null or not _presenter.using_modular_assets():
		return
	_assembler = _presenter.assembler()
	if _assembler == null or not _assembler.is_ready_for_render():
		return
	var body := _assembler.get_node_or_null("Module_body_base") as Sprite2D
	if body == null or body.texture == null:
		_block("body_layer_missing")
		return
	var image := body.texture.get_image()
	if image == null or image.is_empty():
		_block("body_image_invalid")
		return
	var used_rect := image.get_used_rect()
	if used_rect.size.y <= 0:
		_block("body_alpha_bounds_invalid")
		return

	_activation_attempted = true
	_base_scale = TARGET_VISUAL_HEIGHT / float(used_rect.size.y)
	_pose_rig = ModularFighterPoseRig.new()
	_pose_rig.name = "ModularFighterPoseRig"
	add_child(_pose_rig)
	var failures := _pose_rig.configure(_assembler, body.texture, used_rect)
	if not failures.is_empty():
		_block_pose_rig("pose_rig_configure:%s" % ",".join(failures))
		return
	var pose_signature := _pose_rig.runtime_signature()
	var library_variant: Variant = pose_signature.get("motion_library", {})
	var library_signature := library_variant as Dictionary if library_variant is Dictionary else {}
	if not bool(pose_signature.get("authored_animation", false)):
		_block_pose_rig("authored_motion_inactive")
		return
	if bool(pose_signature.get("procedural_pose_functions", true)):
		_block_pose_rig("procedural_pose_functions_active")
		return
	if not bool(library_signature.get("valid", false)):
		_block_pose_rig("authored_motion_library_invalid")
		return
	if int(library_signature.get("clip_count", 0)) != EXPECTED_AUTHORED_CLIPS:
		_block_pose_rig("authored_motion_clip_count:%d" % int(library_signature.get("clip_count", 0)))
		return

	_fighter.set_meta(AUTHORITY_META, true)
	print("P0_2_SKELETAL_POSE_RUNTIME=PASS bones=%d layers=%d" % [
		_pose_rig.bone_count(),
		_pose_rig.mesh_layer_count(),
	])
	print("P0_2_SKELETAL_POSE_AUTHORITY=PASS presenter_root_affine=bypassed")
	print("P0_2_ROOT_AFFINE_ONLY=REJECTED owner=Skeleton2D")
	print("P0_2_AUTHORED_SKELETAL_MOTION=PASS library=%s clips=%d" % [
		String(library_signature.get("library_id", "")),
		int(library_signature.get("clip_count", 0)),
	])
	print("SIGNATURE=Tehkné Solutions")

func _authored_motion_active() -> bool:
	if not active():
		return false
	return bool(_pose_rig.runtime_signature().get("authored_animation", false))

func _block_pose_rig(reason: String) -> void:
	if _pose_rig != null:
		_pose_rig.queue_free()
		_pose_rig = null
	_block(reason)

func _block(reason: String) -> void:
	_activation_attempted = true
	_blocked_reason = reason
	_clear_authority()
	push_error("P0_2_SKELETAL_POSE_RUNTIME=BLOCKED reason=%s" % reason)

func _clear_authority() -> void:
	if is_instance_valid(_fighter) and _fighter.has_meta(AUTHORITY_META):
		_fighter.remove_meta(AUTHORITY_META)

# Tehkné Solutions
