class_name ModularFighterPoseRig
extends Node

## Runtime realization of the BASE-00 shared 2D rig contract.
## Existing modular Sprite2D layers stay as source-of-truth textures/materials;
## gameplay presentation is performed by aligned Polygon2D meshes driven by one
## Skeleton2D. This is procedural pose animation, not authored frame animation.
## Tehkné Solutions

const RUNTIME_ID := "modular_skeletal_pose_rig_v1"
const GRID_COLUMNS := 9
const GRID_ROWS := 11
const BONE_LAYOUT := {
	"pelvis": Vector2(0.50, 0.68),
	"torso": Vector2(0.50, 0.49),
	"head": Vector2(0.50, 0.20),
	"upper_arm_l": Vector2(0.34, 0.39),
	"forearm_l": Vector2(0.22, 0.49),
	"upper_arm_r": Vector2(0.66, 0.39),
	"forearm_r": Vector2(0.78, 0.49),
	"thigh_l": Vector2(0.42, 0.70),
	"shin_l": Vector2(0.40, 0.86),
	"thigh_r": Vector2(0.58, 0.70),
	"shin_r": Vector2(0.60, 0.86),
}
const BONE_RADIUS := {
	"pelvis": Vector2(0.30, 0.22),
	"torso": Vector2(0.28, 0.24),
	"head": Vector2(0.25, 0.24),
	"upper_arm_l": Vector2(0.18, 0.18),
	"forearm_l": Vector2(0.17, 0.20),
	"upper_arm_r": Vector2(0.18, 0.18),
	"forearm_r": Vector2(0.17, 0.20),
	"thigh_l": Vector2(0.18, 0.22),
	"shin_l": Vector2(0.17, 0.22),
	"thigh_r": Vector2(0.18, 0.22),
	"shin_r": Vector2(0.17, 0.22),
}
const ATTACK_POSE_PHASES := ["anticipation", "contact", "recovery"]

var _assembler: ModularFighterAssembler
var _skeleton: Skeleton2D
var _bones: Dictionary = {}
var _rest_transforms: Dictionary = {}
var _bindings: Array[Dictionary] = []
var _reference_rect := Rect2()
var _configured := false
var _last_pose := "idle"
var _last_attack_pose_phase := "none"

func configure(
	assembler: ModularFighterAssembler,
	reference_texture: Texture2D,
	used_rect: Rect2i
) -> PackedStringArray:
	var failures := PackedStringArray()
	if assembler == null or not assembler.is_ready_for_render():
		failures.append("pose_rig_assembler_not_ready")
		return failures
	if reference_texture == null or used_rect.size.x <= 0 or used_rect.size.y <= 0:
		failures.append("pose_rig_reference_invalid")
		return failures
	if assembler.get_node_or_null("PoseSkeleton") != null:
		failures.append("pose_rig_duplicate_skeleton")
		return failures

	_assembler = assembler
	var body := assembler.get_node_or_null("Module_body_base") as Sprite2D
	if body == null or body.texture == null:
		failures.append("pose_rig_body_layer_missing")
		return failures

	_reference_rect = _sprite_used_rect_to_local(body, used_rect)
	_build_skeleton()
	if _skeleton == null or _bones.size() != BONE_LAYOUT.size():
		failures.append("pose_rig_skeleton_build_failed")
		return failures

	var source_layers: Array[Sprite2D] = []
	for child in assembler.get_children():
		if child is Sprite2D and String(child.name).begins_with("Module_"):
			source_layers.append(child as Sprite2D)
	for source in source_layers:
		var mesh := _build_deformable_layer(source)
		if mesh == null:
			failures.append("pose_rig_layer_bind_failed:%s" % String(source.name))
			continue
		_bindings.append({"source": source, "mesh": mesh})

	if not failures.is_empty():
		_restore_sources()
		return failures
	if _bindings.is_empty():
		failures.append("pose_rig_no_visual_layers")
		return failures

	_configured = true
	_sync_layer_visibility()
	_reset_bones()
	return failures

func configured() -> bool:
	return _configured

func bone_count() -> int:
	return _bones.size()

func mesh_layer_count() -> int:
	return _bindings.size()

func attack_pose_phase() -> String:
	return _last_attack_pose_phase

func runtime_signature() -> Dictionary:
	return {
		"runtime": RUNTIME_ID,
		"configured": _configured,
		"skeleton_type": "Skeleton2D",
		"mesh_type": "Polygon2D",
		"bone_count": bone_count(),
		"required_bones": BONE_LAYOUT.keys(),
		"mesh_layer_count": mesh_layer_count(),
		"grid": [GRID_COLUMNS, GRID_ROWS],
		"shared_layer_deformation": true,
		"attack_pose_phases": ATTACK_POSE_PHASES.duplicate(),
		"attack_pose_phase_count": ATTACK_POSE_PHASES.size(),
		"last_pose": _last_pose,
		"last_attack_pose_phase": _last_attack_pose_phase,
		"world_translation_owner": "fighter_physics",
		"root_affine_only": false,
		"regional_cutouts": false,
		"authored_animation": false,
		"motion_source": "procedural_skeletal_pose_rig_v1",
		"signature": "Tehkné Solutions",
	}

func apply_pose(
	state: StringName,
	state_time: float,
	attack_phase: FighterController.AttackPhase,
	attack_phase_timer: float,
	technique: TechniqueData
) -> void:
	if not _configured:
		return
	_sync_layer_visibility()
	_reset_bones()
	_last_pose = String(state)
	_last_attack_pose_phase = "none"

	match state:
		&"idle":
			_apply_idle(state_time)
		&"run":
			_apply_run(state_time)
		&"jump_start":
			_apply_jump_start()
		&"airborne":
			_apply_airborne()
		&"fall":
			_apply_fall()
		&"attack_light":
			_apply_attack(attack_phase, attack_phase_timer, technique)
		&"guard":
			_apply_guard()
		&"dodge":
			_apply_dodge()
		&"hit":
			_apply_hit(state_time)
		&"ko":
			_apply_ko(state_time)

func _build_skeleton() -> void:
	_skeleton = Skeleton2D.new()
	_skeleton.name = "PoseSkeleton"
	_assembler.add_child(_skeleton)
	for bone_name in BONE_LAYOUT.keys():
		var bone := Bone2D.new()
		bone.name = String(bone_name)
		bone.position = _point_in_reference_rect(BONE_LAYOUT[bone_name])
		bone.set_autocalculate_length_and_angle(false)
		bone.set_length(44.0)
		_skeleton.add_child(bone)
		bone.rest = bone.transform
		_bones[bone_name] = bone
		_rest_transforms[bone_name] = bone.transform

func _build_deformable_layer(source: Sprite2D) -> Polygon2D:
	if source == null or source.texture == null:
		return null
	var size := source.texture.get_size()
	if size.x <= 0.0 or size.y <= 0.0:
		return null

	var mesh := Polygon2D.new()
	mesh.name = "%s_Deformed" % String(source.name)
	mesh.texture = source.texture
	mesh.material = source.material
	mesh.modulate = source.modulate
	mesh.self_modulate = source.self_modulate
	mesh.z_index = source.z_index
	mesh.z_as_relative = source.z_as_relative
	mesh.show_behind_parent = source.show_behind_parent
	mesh.texture_filter = source.texture_filter
	mesh.skeleton = NodePath("../PoseSkeleton")

	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	for row in range(GRID_ROWS):
		var v := float(row) / float(GRID_ROWS - 1)
		for column in range(GRID_COLUMNS):
			var u := float(column) / float(GRID_COLUMNS - 1)
			vertices.append(source.position + Vector2((u - 0.5) * size.x, (v - 0.5) * size.y))
			uvs.append(Vector2(u * size.x, v * size.y))
	mesh.polygon = vertices
	mesh.uv = uvs
	var triangles: Array[PackedInt32Array] = []
	for row in range(GRID_ROWS - 1):
		for column in range(GRID_COLUMNS - 1):
			var a := row * GRID_COLUMNS + column
			var b := a + 1
			var c := a + GRID_COLUMNS
			var d := c + 1
			triangles.append(PackedInt32Array([a, b, d]))
			triangles.append(PackedInt32Array([a, d, c]))
	mesh.polygons = triangles

	for bone_name in BONE_LAYOUT.keys():
		var weights := PackedFloat32Array()
		for vertex in vertices:
			weights.append(_normalized_bone_weight(String(bone_name), vertex))
		mesh.add_bone(NodePath(String(bone_name)), weights)

	_assembler.add_child(mesh)
	source.visible = false
	return mesh

func _normalized_bone_weight(bone_name: String, point: Vector2) -> float:
	var raw: Dictionary = {}
	var total := 0.0
	for candidate in BONE_LAYOUT.keys():
		var anchor := _point_in_reference_rect(BONE_LAYOUT[candidate])
		var radius_ratio: Vector2 = BONE_RADIUS[candidate]
		var radius := Vector2(
			maxf(1.0, _reference_rect.size.x * radius_ratio.x),
			maxf(1.0, _reference_rect.size.y * radius_ratio.y)
		)
		var dx := (point.x - anchor.x) / radius.x
		var dy := (point.y - anchor.y) / radius.y
		var value := exp(-(dx * dx + dy * dy) * 1.65) + 0.0001
		raw[candidate] = value
		total += value
	if total <= 0.0:
		return 0.0
	return float(raw.get(bone_name, 0.0)) / total

func _reset_bones() -> void:
	for bone_name in _bones.keys():
		var bone := _bones[bone_name] as Bone2D
		if bone != null:
			bone.transform = _rest_transforms[bone_name]

func _apply_idle(time: float) -> void:
	var breath := sin(time * 2.35)
	_rotate("torso", breath * 0.008)
	_rotate("head", -breath * 0.006)
	_translate("torso", Vector2(0.0, breath * 1.8))
	_rotate("upper_arm_l", breath * 0.010)
	_rotate("upper_arm_r", -breath * 0.010)

func _apply_run(time: float) -> void:
	var stride := sin(time * 14.0)
	var rebound := absf(cos(time * 14.0))
	_rotate("torso", -0.055)
	_rotate("head", 0.022)
	_rotate("upper_arm_l", -stride * 0.16)
	_rotate("forearm_l", stride * 0.10)
	_rotate("upper_arm_r", stride * 0.16)
	_rotate("forearm_r", -stride * 0.10)
	_rotate("thigh_l", stride * 0.18)
	_rotate("shin_l", -stride * 0.13)
	_rotate("thigh_r", -stride * 0.18)
	_rotate("shin_r", stride * 0.13)
	_translate("pelvis", Vector2(0.0, rebound * 2.0))

func _apply_jump_start() -> void:
	_translate("pelvis", Vector2(0.0, 6.0))
	_rotate("thigh_l", -0.10)
	_rotate("thigh_r", 0.10)
	_rotate("shin_l", 0.16)
	_rotate("shin_r", -0.16)
	_rotate("upper_arm_l", 0.08)
	_rotate("upper_arm_r", -0.08)

func _apply_airborne() -> void:
	_rotate("torso", -0.045)
	_rotate("thigh_l", -0.12)
	_rotate("shin_l", 0.18)
	_rotate("thigh_r", 0.08)
	_rotate("shin_r", -0.12)
	_rotate("upper_arm_l", 0.10)
	_rotate("upper_arm_r", -0.14)

func _apply_fall() -> void:
	_rotate("torso", 0.055)
	_rotate("head", -0.03)
	_rotate("thigh_l", 0.07)
	_rotate("thigh_r", -0.07)
	_rotate("forearm_l", 0.12)
	_rotate("forearm_r", -0.12)

func _apply_attack(
	attack_phase: FighterController.AttackPhase,
	attack_phase_timer: float,
	technique: TechniqueData
) -> void:
	var progress := _attack_phase_progress(attack_phase, attack_phase_timer, technique)
	match attack_phase:
		FighterController.AttackPhase.STARTUP:
			_last_attack_pose_phase = "anticipation"
			var windup := _smooth(progress)
			_rotate("pelvis", -0.035 * windup)
			_rotate("torso", -0.105 * windup)
			_rotate("head", 0.035 * windup)
			_rotate("upper_arm_r", -0.22 * windup)
			_rotate("forearm_r", -0.18 * windup)
			_rotate("upper_arm_l", 0.07 * windup)
			_translate("pelvis", Vector2(-5.0 * windup, 1.5 * windup))
		FighterController.AttackPhase.ACTIVE:
			_last_attack_pose_phase = "contact"
			var snap := 1.0 - absf(progress * 2.0 - 1.0) * 0.18
			_rotate("pelvis", 0.075 * snap)
			_rotate("torso", 0.155 * snap)
			_rotate("head", -0.055 * snap)
			_rotate("upper_arm_r", 0.42 * snap)
			_rotate("forearm_r", 0.50 * snap)
			_rotate("upper_arm_l", -0.13 * snap)
			_rotate("thigh_l", -0.07 * snap)
			_rotate("thigh_r", 0.08 * snap)
			_translate("pelvis", Vector2(8.0 * snap, -1.0))
		FighterController.AttackPhase.RECOVERY:
			_last_attack_pose_phase = "recovery"
			var settle := 1.0 - _smooth(progress)
			_rotate("pelvis", 0.045 * settle)
			_rotate("torso", 0.085 * settle)
			_rotate("upper_arm_r", 0.25 * settle)
			_rotate("forearm_r", 0.20 * settle)
			_translate("pelvis", Vector2(4.0 * settle, 0.0))
		_:
			_last_attack_pose_phase = "none"

func _apply_guard() -> void:
	_rotate("torso", -0.035)
	_rotate("head", 0.02)
	_rotate("upper_arm_l", 0.26)
	_rotate("forearm_l", -0.42)
	_rotate("upper_arm_r", -0.24)
	_rotate("forearm_r", 0.44)
	_rotate("thigh_l", -0.045)
	_rotate("thigh_r", 0.045)
	_translate("pelvis", Vector2(-2.0, 3.0))

func _apply_dodge() -> void:
	_rotate("pelvis", -0.08)
	_rotate("torso", -0.18)
	_rotate("head", 0.08)
	_rotate("upper_arm_l", 0.12)
	_rotate("upper_arm_r", -0.12)
	_rotate("thigh_l", 0.12)
	_rotate("thigh_r", -0.10)
	_translate("pelvis", Vector2(-8.0, 3.0))

func _apply_hit(time: float) -> void:
	var recoil := clampf(1.0 - time / 0.18, 0.0, 1.0)
	_rotate("pelvis", -0.08 * recoil)
	_rotate("torso", -0.19 * recoil)
	_rotate("head", -0.10 * recoil)
	_rotate("upper_arm_l", 0.18 * recoil)
	_rotate("upper_arm_r", -0.20 * recoil)
	_translate("torso", Vector2(-6.0 * recoil, 0.0))

func _apply_ko(time: float) -> void:
	var fall := _smooth(clampf(time / 0.42, 0.0, 1.0))
	_rotate("pelvis", 0.32 * fall)
	_rotate("torso", 0.52 * fall)
	_rotate("head", 0.28 * fall)
	_rotate("upper_arm_l", -0.20 * fall)
	_rotate("upper_arm_r", 0.26 * fall)
	_rotate("thigh_l", 0.16 * fall)
	_rotate("thigh_r", -0.12 * fall)
	_translate("pelvis", Vector2(8.0 * fall, 14.0 * fall))

func _attack_phase_progress(
	attack_phase: FighterController.AttackPhase,
	attack_phase_timer: float,
	technique: TechniqueData
) -> float:
	if technique == null:
		return 0.5
	var duration := 0.0
	match attack_phase:
		FighterController.AttackPhase.STARTUP:
			duration = technique.startup_seconds()
		FighterController.AttackPhase.ACTIVE:
			duration = technique.active_seconds()
		FighterController.AttackPhase.RECOVERY:
			duration = technique.recovery_seconds()
	if duration <= 0.001:
		return 1.0
	return clampf(1.0 - attack_phase_timer / duration, 0.0, 1.0)

func _rotate(bone_name: String, radians: float) -> void:
	var bone := _bones.get(bone_name) as Bone2D
	if bone != null:
		bone.rotation += radians

func _translate(bone_name: String, offset: Vector2) -> void:
	var bone := _bones.get(bone_name) as Bone2D
	if bone != null:
		bone.position += offset

func _sync_layer_visibility() -> void:
	for binding in _bindings:
		var source := binding.get("source") as Sprite2D
		var mesh := binding.get("mesh") as Polygon2D
		if source != null and mesh != null:
			# Source visibility is still the ownership boundary used by equipment
			# runtimes; the deformable mirror follows it but the source stays hidden.
			mesh.visible = source.visible
			source.visible = false

func _restore_sources() -> void:
	for binding in _bindings:
		var source := binding.get("source") as Sprite2D
		var mesh := binding.get("mesh") as Polygon2D
		if source != null:
			source.visible = true
		if mesh != null:
			mesh.queue_free()
	_bindings.clear()
	if _skeleton != null:
		_skeleton.queue_free()
	_skeleton = null
	_bones.clear()
	_rest_transforms.clear()
	_configured = false

func _sprite_used_rect_to_local(sprite: Sprite2D, used_rect: Rect2i) -> Rect2:
	var size := sprite.texture.get_size()
	return Rect2(
		sprite.position + Vector2(used_rect.position) - size * 0.5,
		Vector2(used_rect.size)
	)

func _point_in_reference_rect(normalized: Vector2) -> Vector2:
	return _reference_rect.position + Vector2(
		_reference_rect.size.x * normalized.x,
		_reference_rect.size.y * normalized.y
	)

func _smooth(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

# Tehkné Solutions
