class_name ModularFighterPoseRig
extends Node

## Runtime realization of the BASE-00 shared 2D rig contract.
## Existing modular Sprite2D layers remain the source-of-truth textures/materials;
## aligned Polygon2D meshes are driven by Skeleton2D using explicit authored
## keyframes loaded from a fail-closed motion library.
## Tehkné Solutions

const RUNTIME_ID := "modular_skeletal_pose_rig_v2"
const MOTION_LIBRARY_PATH := "res://config/p0_2_modular_fighter_motion_library_v1.json"
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
var _motion_library: ModularFighterMotionLibrary
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

	_motion_library = ModularFighterMotionLibrary.new()
	var motion_failures := _motion_library.load_from_path(MOTION_LIBRARY_PATH)
	if not motion_failures.is_empty():
		for failure in motion_failures:
			failures.append(String(failure))
		return failures
	if not _motion_library.valid():
		failures.append("motion_library_not_authoritative")
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
		var original_self_modulate := source.self_modulate
		_bindings.append({
			"source": source,
			"mesh": mesh,
			"source_self_modulate": original_self_modulate,
		})
		var hidden_source := original_self_modulate
		hidden_source.a = 0.0
		source.self_modulate = hidden_source

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

func motion_library() -> ModularFighterMotionLibrary:
	return _motion_library

func runtime_signature() -> Dictionary:
	var library_signature := _motion_library.presentation_signature() if _motion_library != null else {}
	var authored := _motion_library != null and _motion_library.valid()
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
		"authored_animation": authored,
		"motion_source": _motion_library.library_id() if authored else "blocked",
		"motion_library": library_signature,
		"runtime_interpolation": authored,
		"runtime_pose_generation": false,
		"procedural_pose_functions": false,
		"signature": "Tehkné Solutions",
	}

func apply_pose(
	state: StringName,
	state_time: float,
	attack_phase: int,
	attack_phase_timer: float,
	technique: TechniqueData
) -> void:
	if not _configured or _motion_library == null or not _motion_library.valid():
		return
	_sync_layer_visibility()
	_reset_bones()
	_last_pose = String(state)
	_last_attack_pose_phase = "none"

	match state:
		&"idle":
			_apply_motion_clip("idle", state_time)
		&"run":
			_apply_motion_clip("run", state_time)
		&"jump_start":
			_apply_motion_clip("jump_start", state_time)
		&"airborne":
			_apply_motion_clip("airborne", state_time)
		&"fall":
			_apply_motion_clip("fall", state_time)
		&"attack_light":
			_apply_attack_clip(attack_phase, attack_phase_timer, technique)
		&"guard":
			_apply_motion_clip("guard", state_time)
		&"dodge":
			_apply_motion_clip("dodge", state_time)
		&"hit":
			_apply_motion_clip("hit", state_time)
		&"ko":
			_apply_motion_clip("ko", state_time)

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

func _apply_motion_clip(clip_id: String, elapsed_seconds: float, explicit_progress: float = -1.0) -> void:
	var sample := _motion_library.sample_clip(clip_id, elapsed_seconds, explicit_progress)
	if sample.is_empty():
		return
	for bone_name in BONE_LAYOUT.keys():
		var bone := _bones.get(bone_name) as Bone2D
		var transform_variant: Variant = sample.get(String(bone_name), {})
		if bone == null or not (transform_variant is Dictionary):
			continue
		var transform := transform_variant as Dictionary
		bone.rotation += float(transform.get("rotation", 0.0))
		var position_variant: Variant = transform.get("position", [0.0, 0.0])
		if position_variant is Array:
			var position := position_variant as Array
			if position.size() == 2:
				bone.position += Vector2(float(position[0]), float(position[1]))

func _apply_attack_clip(
	attack_phase: int,
	attack_phase_timer: float,
	technique: TechniqueData
) -> void:
	var clip_id := ""
	match attack_phase:
		FighterController.AttackPhase.STARTUP:
			_last_attack_pose_phase = "anticipation"
			clip_id = "attack_anticipation"
		FighterController.AttackPhase.ACTIVE:
			_last_attack_pose_phase = "contact"
			clip_id = "attack_contact"
		FighterController.AttackPhase.RECOVERY:
			_last_attack_pose_phase = "recovery"
			clip_id = "attack_recovery"
		_:
			_last_attack_pose_phase = "none"
			return
	var progress := _attack_phase_progress(attack_phase, attack_phase_timer, technique)
	_apply_motion_clip(clip_id, 0.0, progress)

func _attack_phase_progress(
	attack_phase: int,
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

func _sync_layer_visibility() -> void:
	for binding in _bindings:
		var source := binding.get("source") as Sprite2D
		var mesh := binding.get("mesh") as Polygon2D
		if source != null and mesh != null:
			# Equipment runtimes continue to own source.visible. The source texture
			# itself is alpha-hidden so the deformable mirror can follow that policy.
			mesh.visible = source.visible
			var hidden_source: Color = binding.get("source_self_modulate", Color.WHITE)
			hidden_source.a = 0.0
			source.self_modulate = hidden_source

func _restore_sources() -> void:
	for binding in _bindings:
		var source := binding.get("source") as Sprite2D
		var mesh := binding.get("mesh") as Polygon2D
		if source != null:
			source.self_modulate = binding.get("source_self_modulate", Color.WHITE)
		if mesh != null:
			mesh.queue_free()
	_bindings.clear()
	if _skeleton != null:
		_skeleton.queue_free()
	_skeleton = null
	_bones.clear()
	_rest_transforms.clear()
	_motion_library = null
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

# Tehkné Solutions
