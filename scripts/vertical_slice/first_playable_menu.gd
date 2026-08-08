class_name FirstPlayableMenuController
extends Control

const POLICY := preload("res://scripts/vertical_slice/first_playable_visual_policy.gd")
const FIRST_PLAYABLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const CREATOR_SCENE := "res://scenes/characters/modular_fighter_creator_shell.tscn"
const DEFAULT_PARTICIPANT_CODE := "TJFP-001"
const C44_RUNTIME_PROOF_ARG := "--v2-c44-runtime-proof"

@onready var play_button: Button = $Content/Actions/PlayButton
@onready var creator_button: Button = $Content/Actions/CreatorButton
@onready var exit_button: Button = $Content/Actions/ExitButton
@onready var difficulty_label: Label = $Content/Difficulty/DifficultyLabel
@onready var easy_button: Button = $Content/Difficulty/Options/EasyButton
@onready var normal_button: Button = $Content/Difficulty/Options/NormalButton
@onready var hard_button: Button = $Content/Difficulty/Options/HardButton

func _ready() -> void:
	get_tree().paused = false
	play_button.pressed.connect(_start_first_playable)
	creator_button.pressed.connect(_open_character_creator)
	exit_button.pressed.connect(_exit_game)
	easy_button.pressed.connect(select_difficulty.bind(&"apprentice"))
	normal_button.pressed.connect(select_difficulty.bind(&"disciple"))
	hard_button.pressed.connect(select_difficulty.bind(&"master"))

	# Identificador técnico interno: não existe formulário ou bloqueio para o jogador.
	FirstPlayableSession.set_participant_code(DEFAULT_PARTICIPANT_CODE)
	play_button.disabled = false
	creator_button.disabled = false
	_apply_visual_policy()
	_update_difficulty_ui()
	play_button.grab_focus()

	# C44 needs to prove the exported package enters the exact combat scene where
	# the canonical arena is selected. This opt-in user argument is inert during
	# normal interactive play and avoids treating a successful menu boot as arena proof.
	if C44_RUNTIME_PROOF_ARG in OS.get_cmdline_user_args():
		print("V2_C44_RUNTIME_PROOF=ENTER_COMBAT")
		call_deferred("_start_first_playable")

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey:
		match event.physical_keycode:
			KEY_1:
				select_difficulty(&"apprentice")
			KEY_2:
				select_difficulty(&"disciple")
			KEY_3:
				select_difficulty(&"master")
			KEY_C:
				_open_character_creator()
			KEY_ENTER:
				_start_first_playable()
			KEY_ESCAPE:
				_exit_game()

func select_difficulty(difficulty_id: StringName) -> void:
	FirstPlayableSession.set_difficulty(difficulty_id)
	_update_difficulty_ui()

func flow_signature() -> Dictionary:
	return {
		"main_action": &"play_vs_ai",
		"first_playable_scene": FIRST_PLAYABLE_SCENE,
		"creator_scene": CREATOR_SCENE,
		"creator_entry_exposed": true,
		"creator_entry_role": "secondary_non_blocking",
		"difficulty_ids": FirstPlayableSession.VALID_DIFFICULTIES.duplicate(),
		"participant_code_required": false,
		"participant_code": DEFAULT_PARTICIPANT_CODE,
		"legacy_prototype_exposed": false,
		"legacy_nodes_removed": true,
		"site_like_panels": false,
		"form_fields": 0,
		"visible_primary_actions": 2,
		"visible_creator_actions": 1,
		"visual_policy": POLICY.UI_READ,
		"quick_game_ui": true,
		"quick_game_path_unchanged": true,
		"keyboard_shortcuts": {"play": "Enter", "creator": "C", "easy": "1", "normal": "2", "hard": "3"},
		"mouse_supported": true,
		"gamepad_focus_supported": true,
		"signature": "Tehkné Solutions"
	}

func _start_first_playable() -> void:
	if not FirstPlayableSession.has_valid_participant_code():
		FirstPlayableSession.set_participant_code(DEFAULT_PARTICIPANT_CODE)
	get_tree().change_scene_to_file(FIRST_PLAYABLE_SCENE)

func _open_character_creator() -> void:
	get_tree().change_scene_to_file(CREATOR_SCENE)

func _exit_game() -> void:
	get_tree().quit()

func _update_difficulty_ui() -> void:
	var selected := FirstPlayableSession.selected_difficulty_id
	difficulty_label.text = "IA • %s" % FirstPlayableSession.difficulty_label()
	easy_button.text = "%s APRENDIZ" % ("●" if selected == &"apprentice" else "○")
	normal_button.text = "%s DISCÍPULO" % ("●" if selected == &"disciple" else "○")
	hard_button.text = "%s MESTRE" % ("●" if selected == &"master" else "○")

func _apply_visual_policy() -> void:
	var background := get_node_or_null("Background") as ColorRect
	if background:
		background.color = Color(POLICY.INK, 1.0)
	var sky_wash := get_node_or_null("SkyWash") as ColorRect
	if sky_wash:
		sky_wash.color = Color(0.055, 0.12, 0.14, 0.72)
	var ember_wash := get_node_or_null("EmberWash") as ColorRect
	if ember_wash:
		ember_wash.color = Color(0.18, 0.055, 0.035, 0.32)

	var title := get_node_or_null("Title") as Label
	if title:
		title.add_theme_color_override("font_color", POLICY.GOLD)
	var subtitle := get_node_or_null("Subtitle") as Label
	if subtitle:
		subtitle.add_theme_color_override("font_color", POLICY.BONE)
	var lian_name := get_node_or_null("Content/Fighters/Lian/Name") as Label
	if lian_name:
		lian_name.add_theme_color_override("font_color", POLICY.LIAN_WU_WATER.lightened(0.30))
	var rival_name := get_node_or_null("Content/Fighters/Rival/Name") as Label
	if rival_name:
		rival_name.add_theme_color_override("font_color", POLICY.RIVAL_EMBER.lightened(0.18))

	_style_difficulty_button(easy_button)
	_style_difficulty_button(normal_button)
	_style_difficulty_button(hard_button)
	_style_primary_button(play_button)
	_style_secondary_button(creator_button)
	_style_secondary_button(exit_button)

func _style_difficulty_button(button: Button) -> void:
	button.add_theme_color_override("font_color", POLICY.BONE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _button_box(Color(0.055, 0.060, 0.058, 0.92), Color(POLICY.GOLD, 0.30), 2))
	button.add_theme_stylebox_override("hover", _button_box(Color(0.085, 0.095, 0.085, 0.98), Color(POLICY.GOLD, 0.72), 2))
	button.add_theme_stylebox_override("focus", _button_box(Color(0.085, 0.095, 0.085, 0.98), POLICY.GOLD, 2))

func _style_primary_button(button: Button) -> void:
	button.add_theme_color_override("font_color", Color(0.07, 0.08, 0.07, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.03, 0.035, 0.03, 1.0))
	button.add_theme_stylebox_override("normal", _button_box(POLICY.GOLD, POLICY.GOLD.lightened(0.16), 3))
	button.add_theme_stylebox_override("hover", _button_box(POLICY.GOLD.lightened(0.10), Color.WHITE, 3))
	button.add_theme_stylebox_override("focus", _button_box(POLICY.GOLD.lightened(0.06), Color.WHITE, 3))

func _style_secondary_button(button: Button) -> void:
	button.add_theme_color_override("font_color", Color(POLICY.BONE, 0.72))
	button.add_theme_stylebox_override("normal", _button_box(Color(0.035, 0.038, 0.036, 0.76), Color(POLICY.BONE, 0.16), 2))
	button.add_theme_stylebox_override("hover", _button_box(Color(0.065, 0.070, 0.064, 0.90), Color(POLICY.BONE, 0.38), 2))
	button.add_theme_stylebox_override("focus", _button_box(Color(0.065, 0.070, 0.064, 0.90), POLICY.GOLD, 2))

func _button_box(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 9
	box.content_margin_bottom = 9
	return box

# Tehkné Solutions
