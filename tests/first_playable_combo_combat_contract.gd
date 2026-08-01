extends SceneTree

const COMBO_RUNTIME := preload("res://scripts/vertical_slice/first_playable_combo_runtime.gd")
const COMBAT_GUIDE := preload("res://scripts/vertical_slice/first_playable_combat_guide.gd")
const IDENTITY := preload("res://scripts/vertical_slice/first_playable_character_identity.gd")

func _init() -> void:
	var combo := COMBO_RUNTIME.new() as FirstPlayableComboRuntime
	var signature := combo.presentation_signature()
	assert(bool(signature.get("discrete_attack_buttons", false)))
	assert(signature.get("tai_button") == "F")
	assert(signature.get("ji_button") == "G")
	assert(signature.get("fu_button") == "H")
	assert(float(signature.get("combo_buffer_seconds", 0.0)) >= 0.70)
	assert(bool(signature.get("repeat_button_sequences", false)))
	assert(bool(signature.get("direction_modifiers", false)))
	assert(bool(signature.get("air_attack_modifier", false)))
	assert(bool(signature.get("low_attack_modifier", false)))
	assert(bool(signature.get("reversal_modifier", false)))
	assert(bool(signature.get("legacy_single_attack_unbound", false)))
	assert(not bool(signature.get("dedicated_push_attack", true)))
	assert(bool(signature.get("knockback_is_hit_consequence", false)))
	assert(bool(signature.get("clean_hit_full_knockback", false)))
	assert(bool(signature.get("guard_reduces_damage_and_knockback", false)))
	assert(bool(signature.get("dodge_negates_hit", false)))
	assert(bool(signature.get("parry_negates_hit", false)))
	assert(bool(signature.get("elemental_invocations_from_martial_sequences", false)))
	assert(not bool(signature.get("dedicated_magic_button", true)))
	assert(int(signature.get("elemental_recipe_count", 0)) == 4)
	assert(signature.get("air_recipe") == "F-H-F")
	assert(signature.get("earth_recipe") == "G-G-H")
	assert(signature.get("water_recipe") == "H-F-H")
	assert(signature.get("fire_recipe") == "F-G-F")
	assert(bool(signature.get("invocation_consumes_recipe", false)))
	assert(bool(signature.get("failed_invocation_falls_back_to_physical", false)))
	combo.free()

	var guide := COMBAT_GUIDE.new() as FirstPlayableCombatGuide
	var guide_signature := guide.presentation_signature()
	assert(bool(guide_signature.get("attack_families_visible", false)))
	assert(guide_signature.get("tai_key") == "F")
	assert(guide_signature.get("ji_key") == "G")
	assert(guide_signature.get("fu_key") == "H")
	assert(bool(guide_signature.get("repeat_sequences_visible", false)))
	assert(bool(guide_signature.get("direction_modifiers_visible", false)))
	assert(bool(guide_signature.get("elemental_recipes_visible", false)))
	assert(int(guide_signature.get("elemental_recipe_count", 0)) == 4)
	assert(not bool(guide_signature.get("dedicated_magic_button_visible", true)))
	guide.free()

	var identity := IDENTITY.new() as FirstPlayableCharacterIdentity
	assert(bool(identity.presentation_signature().get("combo_runtime", false)))
	identity.free()

	print("FIRST_PLAYABLE_COMBO_COMBAT_CONTRACT_OK")
	quit()

# Tehkné Solutions
