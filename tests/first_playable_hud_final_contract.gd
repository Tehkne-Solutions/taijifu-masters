extends SceneTree

const COMBAT_GUIDE := preload("res://scripts/vertical_slice/first_playable_combat_guide.gd")

func _init() -> void:
	var signature := FirstPlayableHudSkin.presentation_signature()
	assert(signature.get("direction") == &"martial_fantasy_ink")
	assert(int(signature.get("fighter_identity_colors", 0)) == 2)
	assert(int(signature.get("resource_bar_roles", 0)) == 3)
	assert(bool(signature.get("ornamental_panels", false)))
	assert(bool(signature.get("compact_fight_hud", false)))
	assert(bool(signature.get("persistent_help_removed", false)))
	assert(bool(signature.get("qa_controls_collapsed", false)))
	assert(bool(signature.get("overlay_primary_action_hierarchy", false)))
	assert(bool(signature.get("game_language_overlays", false)))
	assert(bool(signature.get("generic_dark_strip_removed", false)))
	assert(not bool(signature.get("site_like_panels", true)))
	assert(not bool(signature.get("purple_tech_glow", true)))
	assert(not bool(signature.get("logic_changes", true)))
	assert(String(signature.get("signature", "")) == "Tehkné Solutions")

	var guide := COMBAT_GUIDE.new() as FirstPlayableCombatGuide
	var guide_signature := guide.presentation_signature()
	assert(bool(guide_signature.get("persistent_compact_controls", false)))
	assert(bool(guide_signature.get("attack_families_visible", false)))
	assert(String(guide_signature.get("tai_key", "")) == "F")
	assert(String(guide_signature.get("ji_key", "")) == "G")
	assert(String(guide_signature.get("fu_key", "")) == "H")
	assert(bool(guide_signature.get("repeat_sequences_visible", false)))
	assert(bool(guide_signature.get("direction_modifiers_visible", false)))
	assert(bool(guide_signature.get("elemental_recipes_visible", false)))
	assert(bool(guide_signature.get("climax_reaction_controls_visible", false)))
	assert(not bool(guide_signature.get("dedicated_magic_button_visible", true)))
	assert(bool(guide_signature.get("movement_visible", false)))
	assert(bool(guide_signature.get("jump_visible", false)))
	assert(bool(guide_signature.get("defense_visible", false)))
	assert(bool(guide_signature.get("arena_fighter_readability", false)))
	assert(not bool(guide_signature.get("site_panel", true)))
	assert(String(guide_signature.get("signature", "")) == "Tehkné Solutions")
	guide.free()

	print("FIRST_PLAYABLE_HUD_FINAL_CONTRACT_OK")
	quit()

# Tehkné Solutions
