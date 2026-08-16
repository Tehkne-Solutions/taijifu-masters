class_name FirstPlayableSkeletalModularFighterPresenter
extends FirstPlayableModularFighterPresenter

## P0.2 production presenter specialization.
## The C65 modular presenter remains the assembly/state authority, while this
## specialization stops the historical whole-assembler affine animation once
## the shared Skeleton2D runtime has assumed visual-motion authority.
##
## P0.3 additionally consumes the PACK 04 semantic reaction bridge. Until the
## approved reaction-art release exists, the bridge only selects existing
## authored states (guard/hit/idle); it never invents poses or owns gameplay.
## Tehkné Solutions

const SKELETAL_AUTHORITY_META := &"modular_skeletal_pose_authority"

func _resolve_visual_state() -> StringName:
	if is_instance_valid(_fighter) and _fighter.health <= 0.0:
		return &"ko"
	var override := pack04_visual_override()
	if not String(override).is_empty():
		return override
	return super._resolve_visual_state()

func pack04_visual_override() -> StringName:
	var runtime := _pack04_runtime()
	return runtime.visual_override() if runtime != null else &""

func _pack04_runtime() -> FirstPlayablePack04ReactionRuntime:
	if not (_fighter is FirstPlayableCombatFighterController):
		return null
	return (_fighter as FirstPlayableCombatFighterController).pack04_reaction_runtime()

func _apply_state_transform() -> void:
	if (
		is_instance_valid(_fighter)
		and is_instance_valid(_assembler)
		and bool(_fighter.get_meta(SKELETAL_AUTHORITY_META, false))
	):
		var facing_sign := -1.0 if _fighter.facing < 0.0 else 1.0
		_assembler.position = Vector2.ZERO
		_assembler.rotation = 0.0
		_assembler.skew = 0.0
		_assembler.scale = Vector2(_base_scale * facing_sign, _base_scale)
		return
	
	super._apply_state_transform()

func runtime_signature() -> Dictionary:
	var signature := super.runtime_signature()
	var pack04 := _pack04_runtime()
	var pack04_signature := pack04.runtime_signature() if pack04 != null else {}
	signature["skeletal_authority_aware"] = true
	signature["skeletal_authority_active"] = (
		is_instance_valid(_fighter)
		and bool(_fighter.get_meta(SKELETAL_AUTHORITY_META, false))
	)
	signature["root_affine_policy"] = "skeletal_authority_when_active"
	signature["whole_assembler_combat_pose"] = false
	signature["pack04_reaction_handoff"] = pack04 != null
	signature["pack04_visual_override"] = String(pack04_visual_override())
	signature["pack04_visual_source"] = String(pack04_signature.get("visual_source", "none"))
	signature["pack04_fallback_active"] = bool(pack04_signature.get("fallback_active", false))
	signature["pack04_art_available"] = bool(pack04_signature.get("pack04_art_available", false))
	signature["pack04_art_status"] = String(pack04_signature.get("pack04_art_status", "runtime_unavailable"))
	signature["pack04_gameplay_owner"] = "fighter_physics"
	signature["signature"] = "Tehkné Solutions"
	return signature

# Tehkné Solutions
