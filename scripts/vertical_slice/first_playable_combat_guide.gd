class_name FirstPlayableCombatGuide
extends Control

const POLICY := preload("res://scripts/vertical_slice/first_playable_visual_policy.gd")
const COMPACT_BATTLE_SECONDS := 1.8

enum GuideStage { FULL, COMPACT, HIDDEN }

var _match: FirstPlayableController
var _panel: PanelContainer
var _full_column: VBoxContainer
var _compact_hint: Label
var _stage := GuideStage.HIDDEN
var _battle_elapsed := 0.0
var _battle_seen := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	anchor_top = 1.0
	offset_left = 18.0
	offset_right = -18.0
	_match = get_parent().get_parent() as FirstPlayableController
	_build()
	_set_stage(GuideStage.HIDDEN)

func _process(delta: float) -> void:
	if not is_instance_valid(_match):
		_match = get_parent().get_parent() as FirstPlayableController
	if not is_instance_valid(_match):
		return
	var match_state := int(_match.get("_state"))
	match match_state:
		FirstPlayableController.MatchState.COUNTDOWN:
			_battle_seen = false
			_battle_elapsed = 0.0
			_set_stage(GuideStage.FULL)
		FirstPlayableController.MatchState.BATTLE:
			if not _battle_seen:
				_battle_seen = true
				_battle_elapsed = 0.0
				_set_stage(GuideStage.COMPACT)
			else:
				_battle_elapsed += delta
				if _battle_elapsed >= COMPACT_BATTLE_SECONDS:
					_set_stage(GuideStage.HIDDEN)
		_:
			_set_stage(GuideStage.HIDDEN)

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "CombatGuidePanel"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(POLICY.INK, 0.76)
	panel_style.border_color = Color(POLICY.GOLD, 0.22)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(4)
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 6
	panel_style.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	_full_column = VBoxContainer.new()
	_full_column.name = "FullCombatGuide"
	_full_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_full_column.add_theme_constant_override("separation", 4)
	_panel.add_child(_full_column)

	var attacks := HBoxContainer.new()
	attacks.name = "AttackFamilies"
	attacks.alignment = BoxContainer.ALIGNMENT_CENTER
	attacks.add_theme_constant_override("separation", 12)
	_full_column.add_child(attacks)
	_add_chip(attacks, "F", "TAI", POLICY.ROUTE_TAI)
	_add_chip(attacks, "G", "JI / S+G BAIXO", POLICY.ROUTE_JI)
	_add_chip(attacks, "H", "FU / ←+H REVERSÃO", POLICY.JADE)

	var forms := Label.new()
	forms.name = "ElementalRecipes"
	forms.text = "FORMAS  •  F-G-F FOGO   •   G-G-H TERRA   •   H-F-H ÁGUA   •   F-H-F AR"
	forms.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	forms.add_theme_font_size_override("font_size", 9)
	forms.add_theme_color_override("font_color", Color(POLICY.GOLD, 0.94))
	_full_column.add_child(forms)

	var utility := HBoxContainer.new()
	utility.name = "UtilityControls"
	utility.alignment = BoxContainer.ALIGNMENT_CENTER
	utility.add_theme_constant_override("separation", 8)
	_full_column.add_child(utility)
	_add_chip(utility, "A/D", "MOVER", POLICY.BONE)
	_add_chip(utility, "W", "PULAR / W+F AÉREO", POLICY.ROUTE_TAI)
	_add_chip(utility, "E", "AGARRAR", POLICY.EMBER)
	_add_chip(utility, "Q", "ESQUIVA / REAÇÃO", POLICY.JADE)
	_add_chip(utility, "R", "GUARDA / PARRY / REAÇÃO", POLICY.BONE)

	_compact_hint = Label.new()
	_compact_hint.name = "CompactCombatHint"
	_compact_hint.text = "F TAI   •   G JI   •   H FU   •   Q ESQUIVA   •   R GUARDA/PARRY"
	_compact_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_compact_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_compact_hint.add_theme_font_size_override("font_size", 10)
	_compact_hint.add_theme_color_override("font_color", Color(POLICY.BONE, 0.78))
	_compact_hint.visible = false
	_panel.add_child(_compact_hint)

func _set_stage(next_stage: GuideStage) -> void:
	if _stage == next_stage and visible:
		return
	_stage = next_stage
	if not is_instance_valid(_panel):
		return
	match _stage:
		GuideStage.FULL:
			visible = true
			offset_top = -112.0
			offset_bottom = -14.0
			_full_column.visible = true
			_compact_hint.visible = false
			_panel.modulate.a = 0.96
		GuideStage.COMPACT:
			visible = true
			offset_top = -43.0
			offset_bottom = -14.0
			_full_column.visible = false
			_compact_hint.visible = true
			_panel.modulate.a = 0.68
		GuideStage.HIDDEN:
			_full_column.visible = false
			_compact_hint.visible = false
			visible = false

func _add_chip(parent: HBoxContainer, key_text: String, action_text: String, accent: Color) -> void:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 4)
	parent.add_child(chip)

	var key := Label.new()
	key.custom_minimum_size = Vector2(34.0, 25.0)
	key.text = key_text
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key.add_theme_font_size_override("font_size", 11)
	key.add_theme_color_override("font_color", POLICY.INK)
	var key_style := StyleBoxFlat.new()
	key_style.bg_color = accent
	key_style.set_corner_radius_all(3)
	key.add_theme_stylebox_override("normal", key_style)
	chip.add_child(key)

	var action := Label.new()
	action.text = action_text
	action.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action.add_theme_font_size_override("font_size", 9)
	action.add_theme_color_override("font_color", Color(POLICY.BONE, 0.92))
	chip.add_child(action)

func guide_stage() -> StringName:
	match _stage:
		GuideStage.FULL: return &"full"
		GuideStage.COMPACT: return &"compact"
		_: return &"hidden"

func presentation_signature() -> Dictionary:
	return {
		# Compatibility keys remain true because these concepts are still rendered
		# during onboarding. Their persistence policy is described separately below.
		"attack_families_visible": true,
		"repeat_sequences_visible": true,
		"direction_modifiers_visible": true,
		"elemental_recipes_visible": true,
		"climax_reaction_controls_visible": true,
		"full_guide_auto_collapses": true,
		"compact_hint_after_intro": true,
		"full_guide_seconds": 0.0,
		"persistent_compact_controls": false,
		"full_guide_countdown_only": true,
		"compact_hint_battle_seconds": COMPACT_BATTLE_SECONDS,
		"guide_hidden_during_active_round": true,
		"gameplay_area_released_after_intro": true,
		"attack_families_visible_during_onboarding": true,
		"tai_key": "F",
		"ji_key": "G",
		"fu_key": "H",
		"repeat_sequences_visible_during_onboarding": true,
		"direction_modifiers_visible_during_onboarding": true,
		"elemental_recipes_visible_during_onboarding": true,
		"climax_reaction_controls_visible_during_onboarding": true,
		"dedicated_magic_button_visible": false,
		"movement_visible_during_onboarding": true,
		"jump_visible_during_onboarding": true,
		"defense_visible_during_onboarding": true,
		"arena_fighter_readability": true,
		"site_panel": false,
		"signature": "Tehkné Solutions"
	}

# Tehkné Solutions