class_name FirstPlayableVisualPolicy
extends RefCounted

# Fonte única de verdade visual do First Playable.
# Nenhuma geração artística é considerada canônica por este arquivo; ele apenas
# fixa as regras já aprovadas que o runtime e os contratos devem respeitar.

const DIRECTION: StringName = &"comic_manga_2_5d_martial_fantasy"
const CHARACTER_READ: StringName = &"gunbound_like_fighter_readability"
const ARENA_READ: StringName = &"layered_parallax_fighter_first"
const UI_READ: StringName = &"martial_fantasy_ink"

const INK := Color(0.026, 0.030, 0.032, 0.94)
const INK_SOFT := Color(0.055, 0.058, 0.055, 0.96)
const JADE := Color(0.26, 0.72, 0.58, 1.0)
const EMBER := Color(0.88, 0.30, 0.15, 1.0)
const GOLD := Color(0.88, 0.68, 0.28, 1.0)
const BONE := Color(0.92, 0.88, 0.78, 1.0)

const LIAN_WU_INK := Color(0.035, 0.055, 0.09, 1.0)
const LIAN_WU_ROBE := Color(0.90, 0.94, 0.98, 1.0)
const LIAN_WU_WATER := Color(0.10, 0.42, 0.88, 1.0)
const LIAN_WU_GOLD := Color(0.88, 0.66, 0.22, 1.0)

const RIVAL_ARMOR := Color(0.24, 0.08, 0.06, 1.0)
const RIVAL_EMBER := Color(0.96, 0.28, 0.10, 1.0)
const RIVAL_METAL := Color(0.38, 0.42, 0.48, 1.0)
const RIVAL_BRASS := Color(0.74, 0.47, 0.16, 1.0)

static func signature() -> Dictionary:
	return {
		"direction": DIRECTION,
		"character_read": CHARACTER_READ,
		"arena_read": ARENA_READ,
		"ui_read": UI_READ,
		"comic_manga": true,
		"two_point_five_d": true,
		"layered_parallax": true,
		"fighter_first": true,
		"quick_game_ui": true,
		"site_like_panels": false,
		"purple_tech_glow": false,
		"lian_wu_palette": ["white", "water_blue", "gold", "ink"],
		"lian_wu_single_katana": true,
		"training_rival_palette": ["dark_armor", "ember", "metal", "brass"],
		"training_rival_gauntlets": true,
		"real_art_status": &"art_required",
		"procedural_is_fallback_only": true,
		"signature": "Tehkné Solutions"
	}

# Tehkné Solutions
