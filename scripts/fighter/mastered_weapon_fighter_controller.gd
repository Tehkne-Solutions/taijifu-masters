class_name MasteredWeaponFighterController
extends WeaponKitFighterController

func _begin_technique(technique_id: StringName) -> bool:
	var variant_id := unlocked_variant_for(technique_id)
	var additional_cost := 0.0
	if variant_id != &"":
		var base_technique := TechniqueCatalog.get_technique(technique_id)
		var preview := TechniqueCatalog.get_technique(technique_id)
		MasterTrainingCatalog.apply_variant(preview, variant_id)
		if stamina < preview.stamina_cost:
			return false
		additional_cost = maxf(0.0, preview.stamina_cost - base_technique.stamina_cost)

	var began := super._begin_technique(technique_id)
	if began and additional_cost > 0.0:
		stamina = maxf(0.0, stamina - additional_cost)
		combat_state_changed.emit(self)
	return began
