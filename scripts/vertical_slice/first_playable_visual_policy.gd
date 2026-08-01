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

# Rotas da arena. FU deixa de usar violeta/roxo para não reintroduzir
# a leitura tech que foi descartada da identidade canônica.
const ROUTE_TAI := Color(0.20, 0.62, 0.96, 0.92)
const ROUTE_JI := Color(0.92, 0.30, 0.16, 0.92)
const ROUTE_FU := Color(0.28, 0.68, 0.52, 0.92)
const ROUTE_FU_ACCENT := Color(0.88, 0.68, 0.28, 0.88)
const PLATFORM_STONE := Color(0.16, 0.17, 0.18, 0.98)
const PLATFORM_FACE := Color(0.075, 0.080, 0.082, 0.98)
const PLATFORM_SHADOW := Color(0.015, 0.018, 0.020, 0.62)

const LIAN_WU_INK := Color(0.035, 0.055, 0.09, 1.0)
const LIAN_WU_ROBE := Color(0.90, 0.94, 0.98, 1.0)
const LIAN_WU_WATER := Color(0.10, 0.42, 0.88, 1.0)
const LIAN_WU_GOLD := Color(0.88, 0.66, 0.22, 1.0)

const RIVAL_ARMOR := Color(0.24, 0.08, 0.06, 1.0)
const RIVAL_EMBER := Color(0.96, 0.28, 0.10, 1.0)
const RIVAL_METAL := Color(0.38, 0.42, 0.48, 1.0)
const RIVAL_BRASS := Color(0.74, 0.47, 0.16, 1.0)

static func route_color(route_id: StringName) -> Color:
	match route_id:
		&"tai":
			return ROUTE_TAI
		&"ji":
			return ROUTE_JI
		_:
			return ROUTE_FU

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
		"route_fu_uses_purple": false,
		"route_palette": ["water_blue", "ember", "jade_gold"],
		"lian_wu_palette": ["white", "water_blue", "gold", "ink"],
		"lian_wu_single_katana": true,
		"training_rival_palette": ["dark_armor", "ember", "metal", "brass"],
		"training_rival_gauntlets": true,
		"real_art_status": &"art_required",
		"procedural_is_fallback_only": true,
		"signature": "Tehkné Solutions"
	}

# Tehkné Solutions
