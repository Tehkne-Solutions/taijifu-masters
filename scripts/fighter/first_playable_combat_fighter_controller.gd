class_name FirstPlayableCombatFighterController
extends MasteredWeaponFighterController

# First Playable recovery layer.
# The core fighter already receives an impulse, but normal movement steering can
# overwrite it on the next physics frame. These short locks preserve readable
# recoil while remaining inert outside the FirstPlayable scene.
const HIT_INPUT_LOCK_SECONDS := 0.17
const POSTURE_BREAK_INPUT_LOCK_SECONDS := 0.29
const HIT_KNOCKBACK_LOCK_SECONDS := 0.15
const BLOCK_KNOCKBACK_LOCK_SECONDS := 0.08
const POSTURE_BREAK_KNOCKBACK_LOCK_SECONDS := 0.24
const MIN_HIT_HORIZONTAL_SPEED := 285.0
const MIN_BLOCK_HORIZONTAL_SPEED := 118.0
const MIN_POSTURE_BREAK_HORIZONTAL_SPEED := 430.0
const KNOCKBACK_GROUND_DECELERATION := 520.0

var _first_playable_input_lock := 0.0
var _first_playable_knockback_lock := 0.0
var _last_reaction_id: StringName = &"none"
var _pack04_reaction_runtime: FirstPlayablePack04ReactionRuntime

func _physics_process(delta: float) -> void:
	_ensure_pack04_reaction_runtime()
	_first_playable_input_lock = maxf(0.0, _first_playable_input_lock - delta)
	_first_playable_knockback_lock = maxf(0.0, _first_playable_knockback_lock - delta)
	super._physics_process(delta)

func _process_actions() -> void:
	if _first_playable_recovery_active() and _first_playable_input_lock > 0.0:
		_is_blocking = false
		_parry_timer = 0.0
		return
	super._process_actions()

func _apply_movement(delta: float) -> void:
	if _first_playable_recovery_active() and _first_playable_knockback_lock > 0.0:
		# Preserve the received impulse long enough to be visible. We only bleed
		# horizontal speed slowly on the ground; gravity and move_and_slide still run.
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, KNOCKBACK_GROUND_DECELERATION * delta)
		return
	super._apply_movement(delta)

func receive_hit(
	damage: float,
	posture_damage: float,
	impulse: Vector2,
	attacker_position: Vector2,
	attacker: FighterController = null,
	region_id: StringName = &"torso",
	technique: TechniqueData = null,
	bypass_guard: bool = false,
	disarm_multiplier: float = 1.0
) -> bool:
	var recovery_active := _first_playable_recovery_active()
	var posture_before := posture
	var attacker_direction := signf(attacker_position.x - global_position.x)
	var guarding_front := _is_blocking and attacker_direction == facing and not bypass_guard
	var was_evading := _dodge_timer > 0.06 and not bypass_guard
	var was_parrying := guarding_front and _parry_timer > 0.0
	var adjusted_impulse := impulse

	if recovery_active and not was_evading and not was_parrying:
		var away := signf(global_position.x - attacker_position.x)
		if away == 0.0:
			away = -facing if facing != 0.0 else -1.0
		# Give every accepted contact enough horizontal authority to separate the
		# bodies. Guard reduction and knockback resistance are still applied by the
		# parent controller before the post-hit minimum below is enforced.
		if absf(adjusted_impulse.x) < MIN_HIT_HORIZONTAL_SPEED:
			adjusted_impulse.x = away * MIN_HIT_HORIZONTAL_SPEED

	var accepted := super.receive_hit(
		damage,
		posture_damage,
		adjusted_impulse,
		attacker_position,
		attacker,
		region_id,
		technique,
		bypass_guard,
		disarm_multiplier
	)
	if not accepted or not recovery_active:
		return accepted

	var away_after := signf(global_position.x - attacker_position.x)
	if away_after == 0.0:
		away_after = -facing if facing != 0.0 else -1.0
	var posture_broken_now := posture > posture_before and posture_before <= build.max_posture() * 0.40

	if guarding_front:
		# Physical/telemetry ID retained for backwards compatibility. PACK 04 maps
		# the already-resolved `blocked` outcome to canonical visual `block_recoil`.
		_last_reaction_id = &"blocked_recoil"
		_first_playable_knockback_lock = maxf(_first_playable_knockback_lock, BLOCK_KNOCKBACK_LOCK_SECONDS)
		if absf(velocity.x) < MIN_BLOCK_HORIZONTAL_SPEED:
			velocity.x = away_after * MIN_BLOCK_HORIZONTAL_SPEED
	elif posture_broken_now:
		_last_reaction_id = &"posture_break"
		_interrupt_for_first_playable_hit()
		_first_playable_input_lock = maxf(_first_playable_input_lock, POSTURE_BREAK_INPUT_LOCK_SECONDS)
		_first_playable_knockback_lock = maxf(_first_playable_knockback_lock, POSTURE_BREAK_KNOCKBACK_LOCK_SECONDS)
		if absf(velocity.x) < MIN_POSTURE_BREAK_HORIZONTAL_SPEED:
			velocity.x = away_after * MIN_POSTURE_BREAK_HORIZONTAL_SPEED
		velocity.y = minf(velocity.y, -105.0)
	else:
		_last_reaction_id = &"hit_recoil"
		_interrupt_for_first_playable_hit()
		_first_playable_input_lock = maxf(_first_playable_input_lock, HIT_INPUT_LOCK_SECONDS)
		_first_playable_knockback_lock = maxf(_first_playable_knockback_lock, HIT_KNOCKBACK_LOCK_SECONDS)
		if absf(velocity.x) < MIN_HIT_HORIZONTAL_SPEED:
			velocity.x = away_after * MIN_HIT_HORIZONTAL_SPEED

	combat_state_changed.emit(self)
	return accepted

func _first_playable_recovery_active() -> bool:
	if not _is_first_playable_fighter():
		return false
	var cursor: Node = self
	while is_instance_valid(cursor):
		if cursor.name == &"FirstPlayable":
			return true
		cursor = cursor.get_parent()
	return false

func _interrupt_for_first_playable_hit() -> void:
	_is_blocking = false
	_parry_timer = 0.0
	if _attack_phase != AttackPhase.NONE:
		_end_technique()
	if is_instance_valid(_grabbed_target):
		_release_grab_without_throw()

func first_playable_visual_action_override_active() -> bool:
	# Presentation may keep a short authored HIT tail after physical recoil, but it
	# must yield as soon as gameplay has actually accepted a new discrete action.
	# This keeps gameplay authoritative without extending hit-stun to match visuals.
	if not _first_playable_recovery_active() or _first_playable_input_lock > 0.0:
		return false
	return (
		_dodge_timer > 0.0
		or _attack_phase != AttackPhase.NONE
		or _is_blocking
	)

func pack04_reaction_runtime() -> FirstPlayablePack04ReactionRuntime:
	_ensure_pack04_reaction_runtime()
	return _pack04_reaction_runtime

func first_playable_reaction_signature() -> Dictionary:
	var pack04_signature := _pack04_reaction_runtime.runtime_signature() if is_instance_valid(_pack04_reaction_runtime) else {}
	return {
		"enabled": _first_playable_recovery_active(),
		"context_scoped": true,
		"input_lock_seconds": HIT_INPUT_LOCK_SECONDS,
		"posture_break_lock_seconds": POSTURE_BREAK_INPUT_LOCK_SECONDS,
		"knockback_lock_seconds": HIT_KNOCKBACK_LOCK_SECONDS,
		"minimum_hit_horizontal_speed": MIN_HIT_HORIZONTAL_SPEED,
		"minimum_block_horizontal_speed": MIN_BLOCK_HORIZONTAL_SPEED,
		"minimum_posture_break_horizontal_speed": MIN_POSTURE_BREAK_HORIZONTAL_SPEED,
		"last_reaction_id": String(_last_reaction_id),
		"input_locked": _first_playable_input_lock > 0.0,
		"knockback_locked": _first_playable_knockback_lock > 0.0,
		"visual_action_override_active": first_playable_visual_action_override_active(),
		"pack04_semantic_runtime": pack04_signature,
		"pack04_art_available": bool(pack04_signature.get("pack04_art_available", false)),
		"pack04_fallback_observable": is_instance_valid(_pack04_reaction_runtime),
		"signature": "Tehkné Solutions",
	}

func _ensure_pack04_reaction_runtime() -> void:
	if is_instance_valid(_pack04_reaction_runtime) or not _first_playable_recovery_active():
		return
	_pack04_reaction_runtime = FirstPlayablePack04ReactionRuntime.new()
	_pack04_reaction_runtime.name = "FirstPlayablePack04ReactionRuntime"
	add_child(_pack04_reaction_runtime)

func reset_fighter(spawn_position: Vector2) -> void:
	super.reset_fighter(spawn_position)
	_first_playable_input_lock = 0.0
	_first_playable_knockback_lock = 0.0
	_last_reaction_id = &"none"

# Tehkné Solutions
