class_name FirstPlayableSkeletalModularFighterPresenter
extends FirstPlayableModularFighterPresenter

## P0.2 production presenter specialization.
## The C65 modular presenter remains the assembly/state authority, while this
## specialization stops the historical whole-assembler affine animation once
## the shared Skeleton2D runtime has assumed visual-motion authority.
## Tehkné Solutions

const SKELETAL_AUTHORITY_META := &"modular_skeletal_pose_authority"

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
	signature["skeletal_authority_aware"] = true
	signature["skeletal_authority_active"] = (
		is_instance_valid(_fighter)
		and bool(_fighter.get_meta(SKELETAL_AUTHORITY_META, false))
	)
	signature["root_affine_policy"] = "skeletal_authority_when_active"
	signature["whole_assembler_combat_pose"] = false
	signature["signature"] = "Tehkné Solutions"
	return signature

# Tehkné Solutions