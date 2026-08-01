extends SceneTree

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
	print("FIRST_PLAYABLE_HUD_FINAL_CONTRACT_OK")
	quit()

# Tehkné Solutions
