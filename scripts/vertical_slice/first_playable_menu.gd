class_name FirstPlayableMenuController
extends Control

const FIRST_PLAYABLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const DEFAULT_PARTICIPANT_CODE := "TJFP-001"

@onready var play_button: Button = $Content/Actions/PlayButton
@onready var prototype_button: Button = $Content/Actions/PrototypeButton
@onready var exit_button: Button = $Content/Actions/ExitButton
@onready var participant_panel: Control = $Content/Participant
@onready var participant_input: LineEdit = $Content/Participant/ParticipantInput
@onready var participant_status: Label = $Content/Participant/ParticipantStatus
@onready var difficulty_label: Label = $Content/Difficulty/DifficultyLabel
@onready var easy_button: Button = $Content/Difficulty/Options/EasyButton
@onready var normal_button: Button = $Content/Difficulty/Options/NormalButton
@onready var hard_button: Button = $Content/Difficulty/Options/HardButton

var _participant_edit_guard := false

func _ready() -> void:
	get_tree().paused = false
	play_button.pressed.connect(_start_first_playable)
	exit_button.pressed.connect(_exit_game)
	easy_button.pressed.connect(select_difficulty.bind(&"apprentice"))
	normal_button.pressed.connect(select_difficulty.bind(&"disciple"))
	hard_button.pressed.connect(select_difficulty.bind(&"master"))

	# Sprint 0: uma única tela nativa e entrada imediata no First Playable.
	prototype_button.visible = false
	prototype_button.disabled = true
	participant_panel.visible = false
	set_participant_code(DEFAULT_PARTICIPANT_CODE)
	play_button.disabled = false
	play_button.text = "JOGAR CONTRA IA"
	_update_difficulty_ui()
	play_button.grab_focus()

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
			KEY_ENTER:
				_start_first_playable()
			KEY_ESCAPE:
				_exit_game()

func select_difficulty(difficulty_id: StringName) -> void:
	FirstPlayableSession.set_difficulty(difficulty_id)
	_update_difficulty_ui()

func set_participant_code(raw_value: String) -> bool:
	var normalized := FirstPlayableSession.normalize_participant_code(raw_value)
	_participant_edit_guard = true
	participant_input.text = normalized if normalized != "" else raw_value.strip_edges().to_upper()
	participant_input.caret_column = participant_input.text.length()
	_participant_edit_guard = false
	if normalized != "":
		FirstPlayableSession.set_participant_code(normalized)
	else:
		FirstPlayableSession.clear_participant_code()
	_update_participant_ui()
	return normalized != ""

func flow_signature() -> Dictionary:
	return {
		"main_action": &"play_vs_ai",
		"first_playable_scene": FIRST_PLAYABLE_SCENE,
		"difficulty_ids": FirstPlayableSession.VALID_DIFFICULTIES.duplicate(),
		"participant_code_required": false,
		"participant_code": DEFAULT_PARTICIPANT_CODE,
		"legacy_prototype_exposed": false,
		"keyboard_shortcuts": {"play": "Enter", "easy": "1", "normal": "2", "hard": "3"},
		"mouse_supported": true,
		"gamepad_focus_supported": true
	}

func _start_first_playable() -> void:
	if not FirstPlayableSession.has_valid_participant_code():
		set_participant_code(DEFAULT_PARTICIPANT_CODE)
	get_tree().change_scene_to_file(FIRST_PLAYABLE_SCENE)

func _exit_game() -> void:
	get_tree().quit()

func _update_participant_ui() -> void:
	var normalized := FirstPlayableSession.normalize_participant_code(participant_input.text)
	var valid := normalized != "" and normalized == FirstPlayableSession.participant_code
	participant_status.text = "PILOTO • %s" % normalized if valid else "PILOTO AUTOMÁTICO"

func _update_difficulty_ui() -> void:
	var selected := FirstPlayableSession.selected_difficulty_id
	difficulty_label.text = "DIFICULDADE DA IA • %s" % FirstPlayableSession.difficulty_label()
	easy_button.text = "%s 1 • APRENDIZ" % ("●" if selected == &"apprentice" else "○")
	normal_button.text = "%s 2 • DISCÍPULO" % ("●" if selected == &"disciple" else "○")
	hard_button.text = "%s 3 • MESTRE" % ("●" if selected == &"master" else "○")
