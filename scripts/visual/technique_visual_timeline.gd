class_name TechniqueVisualTimeline
extends RefCounted

const FRAME_COUNT := 4

static func phase_id(fighter: FighterController) -> StringName:
	if not is_instance_valid(fighter):
		return &"none"
	match fighter._attack_phase:
		FighterController.AttackPhase.STARTUP: return &"startup"
		FighterController.AttackPhase.ACTIVE: return &"active"
		FighterController.AttackPhase.RECOVERY: return &"recovery"
		_: return &"none"

static func phase_duration(fighter: FighterController) -> float:
	if not is_instance_valid(fighter):
		return 0.0
	var technique := fighter._current_technique
	if is_instance_valid(technique):
		match fighter._attack_phase:
			FighterController.AttackPhase.STARTUP: return maxf(0.001, technique.startup_seconds())
			FighterController.AttackPhase.ACTIVE: return maxf(0.001, technique.active_seconds())
			FighterController.AttackPhase.RECOVERY: return maxf(0.001, technique.recovery_seconds())
	if fighter._attack_phase == FighterController.AttackPhase.RECOVERY:
		return 0.24
	return 0.0

static func phase_progress(fighter: FighterController) -> float:
	var duration := phase_duration(fighter)
	if duration <= 0.0:
		return 0.0
	return clampf(1.0 - fighter._attack_phase_timer / duration, 0.0, 1.0)

static func context(fighter: FighterController) -> Dictionary:
	var technique_id := &""
	var path_id := &"neutral"
	if is_instance_valid(fighter) and is_instance_valid(fighter._current_technique):
		technique_id = fighter._current_technique.technique_id
		path_id = StringName(fighter._current_technique.path)
	return {
		"technique_id": technique_id,
		"path_id": path_id,
		"phase_id": phase_id(fighter),
		"progress": phase_progress(fighter)
	}

static func frame_for_fighter(fighter: FighterController) -> int:
	return frame_for_context(phase_id(fighter), phase_progress(fighter))

static func frame_for_context(current_phase: StringName, progress: float) -> int:
	match current_phase:
		&"startup": return 0
		&"active": return 1 if progress < 0.48 else 2
		&"recovery": return 3
		_: return 0

static func phase_energy(fighter: FighterController) -> float:
	return energy_for_context(phase_id(fighter), phase_progress(fighter))

static func energy_for_context(current_phase: StringName, progress: float) -> float:
	match current_phase:
		&"startup": return lerpf(0.34, 0.76, progress)
		&"active": return 1.0
		&"recovery": return lerpf(0.48, 0.16, progress)
		_: return 0.36

static func weapon_angle_offset(fighter: FighterController) -> float:
	var path_id := &"neutral"
	if is_instance_valid(fighter) and is_instance_valid(fighter._current_technique):
		path_id = StringName(fighter._current_technique.path)
	return angle_offset_for_context(path_id, phase_id(fighter), phase_progress(fighter))

static func angle_offset_for_context(path_id: StringName, current_phase: StringName, progress: float) -> float:
	var path_scale := 1.0
	match path_id:
		&"tai": path_scale = 0.72
		&"ji": path_scale = 0.48
		&"fu": path_scale = 1.12
	match current_phase:
		&"startup": return lerpf(-0.22, -0.08, progress) * path_scale
		&"active": return lerpf(-0.05, 0.68, progress) * path_scale
		&"recovery": return lerpf(0.42, 0.02, progress) * path_scale
		_: return 0.0

static func phase_label(fighter: FighterController) -> String:
	return label_for_context(phase_id(fighter), phase_progress(fighter))

static func label_for_context(current_phase: StringName, progress: float) -> String:
	match current_phase:
		&"startup": return "PREPARAÇÃO"
		&"active": return "CONTATO INICIAL" if progress < 0.5 else "CONTATO FINAL"
		&"recovery": return "RECUPERAÇÃO"
		_: return "LIVRE"

static func validate() -> Array[String]:
	var failures: Array[String] = []
	for frame in [0, 1, 2, 3]:
		if frame < 0 or frame >= FRAME_COUNT:
			failures.append("Quadro técnico fora da grade: %d" % frame)
	for phase in [&"startup", &"active", &"recovery"]:
		var frame := frame_for_context(phase, 0.5)
		if frame < 0 or frame >= FRAME_COUNT:
			failures.append("Fase %s resolveu quadro inválido" % String(phase))
	return failures
