extends Node

const SIGNATURE := "Tehkné Solutions"

var _last_battle_instance_id := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if not (scene is FirstPlayableController):
		_last_battle_instance_id = 0
		return
	var battle := scene as FirstPlayableController
	_last_battle_instance_id = battle.get_instance_id()
	var hud := battle.hud_controller
	if not is_instance_valid(hud):
		return
	if not FirstPlayableSession.pilot_enforcement_enabled:
		_release_navigation(hud)
		return
	if not is_instance_valid(hud.result_overlay) or not hud.result_overlay.visible:
		return
	_apply_result_gate(battle, hud)

func _apply_result_gate(battle: FirstPlayableController, hud: FirstPlayableHudController) -> void:
	var feedback_done := bool(battle.get("_feedback_submitted"))
	if not feedback_done:
		hud.rematch_button.disabled = true
		hud.result_menu_button.disabled = true
		if not bool(hud.get("_qa_visible")):
			hud.call("_set_qa_visible", true)
		_focus_feedback(hud)
		return

	if FirstPlayableSession.pilot_complete():
		hud.rematch_button.disabled = true
		hud.rematch_button.text = "PILOTO CONCLUÍDO"
		hud.result_menu_button.disabled = false
		if not hud.result_menu_button.has_focus():
			hud.result_menu_button.grab_focus()
		return

	hud.rematch_button.disabled = false
	hud.result_menu_button.disabled = false

func _focus_feedback(hud: FirstPlayableHudController) -> void:
	var feedback_buttons_variant: Variant = hud.get("_feedback_buttons")
	if not (feedback_buttons_variant is Array):
		return
	for button_variant in feedback_buttons_variant:
		if button_variant is Button:
			var button := button_variant as Button
			if is_instance_valid(button) and not button.disabled:
				button.grab_focus()
				return

func _release_navigation(hud: FirstPlayableHudController) -> void:
	if is_instance_valid(hud.rematch_button):
		hud.rematch_button.disabled = false
	if is_instance_valid(hud.result_menu_button):
		hud.result_menu_button.disabled = false

func presentation_signature() -> Dictionary:
	return {
		"pilot_id": FirstPlayableSession.PILOT_ID,
		"feedback_required_before_navigation": true,
		"auto_open_feedback_controls": true,
		"rematch_blocked_until_feedback": true,
		"menu_blocked_until_feedback": true,
		"seventh_match_blocked": true,
		"outside_pilot_inert": true,
		"last_battle_instance_id": _last_battle_instance_id,
		"signature": SIGNATURE,
	}

# Tehkné Solutions
