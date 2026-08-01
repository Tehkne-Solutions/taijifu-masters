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
	combo.free()

	var guide := COMBAT_GUIDE.new() as FirstPlayableCombatGuide
	var guide_signature := guide.presentation_signature()
	assert(bool(guide_signature.get("attack_families_visible", false)))
	assert(guide_signature.get("tai_key") == "F")
	assert(guide_signature.get("ji_key") == "G")
	assert(guide_signature.get("fu_key") == "H")
	assert(bool(guide_signature.get("repeat_sequences_visible", false)))
	assert(bool(guide_signature.get("direction_modifiers_visible", false)))
	guide.free()

	var identity := IDENTITY.new() as FirstPlayableCharacterIdentity
	assert(bool(identity.presentation_signature().get("combo_runtime", false)))
	identity.free()

	print("FIRST_PLAYABLE_COMBO_COMBAT_CONTRACT_OK")
	quit()

# Tehkné Solutions
