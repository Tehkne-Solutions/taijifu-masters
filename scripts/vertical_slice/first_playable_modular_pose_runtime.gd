class_name FirstPlayableModularPoseRuntime
extends Node

## P0.2 bridge between the First Playable combat state and the BASE-00 skeletal
## pose rig. Runs after the legacy presenter and neutralizes its whole-assembler
## skew/rotation so the visible motion comes from shared bone deformation.
## Tehkné Solutions

const TARGET_VISUAL_HEIGHT := 132.0
const RUNTIME_ID := "first_playable_modular_pose_runtime_v1"

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
	# assembler keeps only canonical scale + authored-facing mirroring.
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

func runtime_signature() -> Dictionary:
	var pose_signature := _pose_rig.runtime_signature() if _pose_rig != null else {}
	return {
		"runtime": RUNTIME_ID,
		"active": active(),
		"blocked_reason": _blocked_reason,
		"visual_state": String(_state),
		"base_scale": _base_scale,
		"legacy_root_affine_neutralized": active(),
		"world_translation_owner": "fighter_physics",
		"collision_changes": false,
		"pose_rig": pose_signature,
		"authored_animation": false,
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
		_block("pose_rig_configure:%s" % ",".join(failures))
		return
	print("P0_2_SKELETAL_POSE_RUNTIME=PASS bones=%d layers=%d" % [
		_pose_rig.bone_count(),
		_pose_rig.mesh_layer_count(),
	])
	print("P0_2_ROOT_AFFINE_ONLY=REJECTED owner=Skeleton2D")
	print("SIGNATURE=Tehkné Solutions")

func _block(reason: String) -> void:
	_activation_attempted = true
	_blocked_reason = reason
	push_error("P0_2_SKELETAL_POSE_RUNTIME=BLOCKED reason=%s" % reason)

# Tehkné Solutions
