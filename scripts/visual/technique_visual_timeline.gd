class_name TechniqueVisualTimeline
extends RefCounted

const FRAME_COUNT := 4

static func phase_id(fighter: FighterController) -> StringName:
	if not is_instance_valid(fighter):
		return &"none"
	match fighter._attack_phase:
		FighterController.AttackPhase.STARTUP:
			return &"startup"
		FighterController.AttackPhase.ACTIVE:
			return &"active"
		FighterController.AttackPhase.RECOVERY:
			return &"recovery"
		_:
			return &"none"

static func phase_duration(fighter: FighterController) -> float:
	if not is_instance_valid(fighter):
		return 0.0
	var technique := fighter._current_technique
	if is_instance_valid(technique):
		match fighter._attack_phase:
			FighterController.AttackPhase.STARTUP:
				return maxf(0.001, technique.startup_seconds())
			FighterController.AttackPhase.ACTIVE:
				return maxf(0.001, technique.active_seconds())
			FighterController.AttackPhase.RECOVERY:
				return maxf(0.001, technique.recovery_seconds())
	if fighter._attack_phase == FighterController.AttackPhase.RECOVERY:
		return 0.24
	return 0.0

static func phase_progress(fighter: FighterController) -> float:
	var duration := phase_duration(fighter)
	if duration <= 0.0:
		return 0.0
	return clampf(1.0 - fighter._attack_phase_timer / duration, 0.0, 1.0)

static func frame_for_fighter(fighter: FighterController) -> int:
	var current_phase := phase_id(fighter)
	var progress := phase_progress(fighter)
	match current_phase:
		&"startup":
			return 0
		&"active":
			return 1 if progress < 0.48 else 2
		&"recovery":
			return 3
		_:
			return 0

static func phase_energy(fighter: FighterController) -> float:
	var current_phase := phase_id(fighter)
	var progress := phase_progress(fighter)
	match current_phase:
		&"startup":
			return lerpf(0.34, 0.76, progress)
		&"active":
			return 1.0
		&"recovery":
			return lerpf(0.48, 0.16, progress)
		_:
			return 0.36

static func weapon_angle_offset(fighter: FighterController) -> float:
	var current_phase := phase_id(fighter)
	var progress := phase_progress(fighter)
	var path_id := &"neutral"
	if is_instance_valid(fighter) and is_instance_valid(fighter._current_technique):
		path_id = StringName(fighter._current_technique.path)
	var path_scale := 1.0
	match path_id:
		&"tai":
			path_scale = 0.72
		&"ji":
			path_scale = 0.48
		&"fu":
			path_scale = 1.12
	match current_phase:
		&"startup":
			return lerpf(-0.22, -0.08, progress) * path_scale
		&"active":
			return lerpf(-0.05, 0.68, progress) * path_scale
		&"recovery":
			return lerpf(0.42, 0.02, progress) * path_scale
		_:
			return 0.0

static func phase_label(fighter: FighterController) -> String:
	match phase_id(fighter):
		&"startup":
			return "PREPARAÇÃO"
		&"active":
			return "CONTATO"
		&"recovery":
			return "RECUPERAÇÃO"
		_:
			return "LIVRE"

static func validate() -> Array[String]:
	var failures: Array[String] = []
	for frame in [0, 1, 2, 3]:
		if frame < 0 or frame >= FRAME_COUNT:
			failures.append("Quadro técnico fora da grade: %d" % frame)
	return failures
