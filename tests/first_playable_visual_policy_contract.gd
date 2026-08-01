extends SceneTree

const POLICY := preload("res://scripts/vertical_slice/first_playable_visual_policy.gd")
const HUD_SKIN := preload("res://scripts/vertical_slice/first_playable_hud_skin.gd")
const IDENTITY := preload("res://scripts/vertical_slice/first_playable_character_identity.gd")

func _init() -> void:
	var policy := POLICY.signature()
	assert(policy.get("direction") == &"comic_manga_2_5d_martial_fantasy")
	assert(policy.get("character_read") == &"gunbound_like_fighter_readability")
	assert(policy.get("arena_read") == &"layered_parallax_fighter_first")
	assert(policy.get("ui_read") == &"martial_fantasy_ink")
	assert(bool(policy.get("comic_manga", false)))
	assert(bool(policy.get("two_point_five_d", false)))
	assert(bool(policy.get("layered_parallax", false)))
	assert(bool(policy.get("fighter_first", false)))
	assert(bool(policy.get("quick_game_ui", false)))
	assert(not bool(policy.get("site_like_panels", true)))
	assert(not bool(policy.get("purple_tech_glow", true)))
	assert(bool(policy.get("lian_wu_recovered_pack01_identity", false)))
	assert(bool(policy.get("lian_wu_chibi_proportions", false)))
	assert(bool(policy.get("lian_wu_large_head_read", false)))
	assert(bool(policy.get("lian_wu_topknot_blue_tie", false)))
	assert(bool(policy.get("lian_wu_white_blue_black_gold_outfit", false)))
	assert(bool(policy.get("lian_wu_single_katana", false)))
	assert(bool(policy.get("lian_wu_katana_sheathed_neutral", false)))
	assert(bool(policy.get("lian_wu_scabbard_left_hip", false)))
	assert(not bool(policy.get("rejected_turnaround_promoted", true)))
	assert(bool(policy.get("training_rival_gauntlets", false)))
	assert(policy.get("real_art_status") == &"art_required")
	assert(bool(policy.get("procedural_is_fallback_only", false)))
	assert(String(policy.get("signature", "")) == "Tehkné Solutions")

	var hud := HUD_SKIN.presentation_signature()
	assert(hud.get("visual_policy") == POLICY.DIRECTION)
	assert(hud.get("direction") == POLICY.UI_READ)
	assert(not bool(hud.get("site_like_panels", true)))
	assert(not bool(hud.get("purple_tech_glow", true)))

	var identity := IDENTITY.new() as FirstPlayableCharacterIdentity
	var identity_signature := identity.presentation_signature()
	assert(identity_signature.get("visual_policy") == POLICY.DIRECTION)
	assert(identity_signature.get("character_read") == POLICY.CHARACTER_READ)
	assert(bool(identity_signature.get("procedural_is_fallback_only", false)))
	assert(bool(identity_signature.get("lian_wu_recovered_identity", false)))
	assert(bool(identity_signature.get("lian_wu_chibi_silhouette", false)))
	assert(bool(identity_signature.get("lian_wu_single_sheathed_katana", false)))
	assert(not bool(identity_signature.get("rejected_turnaround_promoted", true)))
	identity.free()

	print("FIRST_PLAYABLE_VISUAL_POLICY_CONTRACT_OK")
	quit()

# Tehkné Solutions
