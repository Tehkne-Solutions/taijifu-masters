extends Node2D

const FIGHTER_SCENE := preload("res://scenes/fighter/fighter.tscn")
const ELEMENT_IDS: Array[StringName] = [&"fire", &"water", &"earth", &"air"]

enum MatchState { PREPARATION, ENTRANCE, BATTLE }

@onready var arena: TriplePathArena = $Arena
@onready var camera: Camera2D = $Camera2D
@onready var player_one_label: Label = $HUD/PlayerOne
@onready var player_two_label: Label = $HUD/PlayerTwo
@onready var center_label: Label = $HUD/CenterInfo
@onready var controls_label: Label = $HUD/Controls
@onready var preparation_runtime: BattlePreparationRuntime = $BattlePreparationRuntime
@onready var entrance_runtime: ArenaEntranceRuntime = $ArenaEntranceRuntime
@onready var master_training_runtime: MasterTrainingRuntime = $MasterTrainingRuntime

var player_one: FighterController
var player_two: FighterController
var _resetting_round := false
var _state: MatchState = MatchState.PREPARATION
var _preset_ids: Array[StringName] = []
var _selected_preset_indices: Array[int] = [0, 2]
var _selected_element_indices: Array[int] = [3, 2]
var _message_sequence := 0
var _skill_dock: Control
var _skill_labels: Array[Dictionary] = [{}, {}]

func _ready() -> void:
	_register_prototype_inputs()
	_preset_ids = BuildProfile.available_prototype_presets()
	arena.sector_shifted.connect(_on_sector_shifted)
	preparation_runtime.start_requested.connect(_start_battle)
	_build_skill_dock()
	_enter_preparation()

func _process(delta: float) -> void:
	if _state == MatchState.PREPARATION:
		return
	if not is_instance_valid(player_one) or not is_instance_valid(player_two):
		return
	_update_camera(delta)
	_update_hud()
	if _state == MatchState.ENTRANCE:
		return
	_check_world_limits()

func _enter_preparation() -> void:
	_state = MatchState.PREPARATION
	camera.global_position = arena.world_center()
	camera.zoom = Vector2(0.72, 0.72)
	center_label.text = "PREPARAÇÃO COMPLETA"
	controls_label.text = "Configure os dois loadouts e confirme individualmente."
	if is_instance_valid(_skill_dock):
		_skill_dock.visible = false
	_sync_legacy_preparation_state()
	preparation_runtime.open()

func _sync_legacy_preparation_state() -> void:
	for player_index in [1, 2]:
		var loadout := preparation_runtime.loadout_for_player(player_index)
		var preset_id := StringName(loadout.get("preset_id", &"adaptive_staff"))
		var element_id := StringName(loadout.get("element_id", &"air"))
		var preset_index := _preset_ids.find(preset_id)
		var element_index := ELEMENT_IDS.find(element_id)
		if preset_index >= 0:
			_selected_preset_indices[player_index - 1] = preset_index
		if element_index >= 0:
			_selected_element_indices[player_index - 1] = element_index

func _start_battle() -> void:
	if _state != MatchState.PREPARATION or not preparation_runtime.all_players_ready():
		return
	_sync_legacy_preparation_state()
	preparation_runtime.close()
	_state = MatchState.ENTRANCE
	_cleanup_temporary_loot()
	arena.reset_battle_flow()
	_spawn_fighters()
	center_label.text = "ENTRADA NA ARENA"
	controls_label.text = "Controles bloqueados até o comando LUTEM."
	if is_instance_valid(_skill_dock):
		_skill_dock.visible = false
	entrance_runtime.play(player_one, player_two)
	await entrance_runtime.entrance_finished
	if _state != MatchState.ENTRANCE:
		return
	arena.start_battle_flow()
	_state = MatchState.BATTLE
	center_label.text = "RUÍNAS DO CAMINHO TRIPLO\nTAI • JI • FU"
	controls_label.text = ""
	if is_instance_valid(_skill_dock):
		_skill_dock.visible = true

func _spawn_fighters() -> void:
	player_one = _spawn_fighter(1, preparation_runtime.loadout_for_player(1), Color(0.25, 0.70, 1.0))
	player_two = _spawn_fighter(2, preparation_runtime.loadout_for_player(2), Color(1.0, 0.40, 0.24))

func _spawn_fighter(player_index: int, loadout: Dictionary, color: Color) -> FighterController:
	var fighter := FIGHTER_SCENE.instantiate() as FighterController
	fighter.player_index = player_index
	fighter.build_preset = StringName(loadout.get("preset_id", &"adaptive_staff"))
	fighter.fighter_color = color
	fighter.position = arena.respawn_point(player_index)
	_connect_fighter_signals(fighter)
	add_child(fighter)
	fighter.build.element_id = StringName(loadout.get("element_id", fighter.build.element_id))
	if fighter is WeaponKitFighterController:
		var weapon_fighter := fighter as WeaponKitFighterController
		weapon_fighter.build.weapon_id = StringName(loadout.get("primary_weapon_id", weapon_fighter.build.weapon_id))
		weapon_fighter.build.secondary_weapon_id = StringName(loadout.get("secondary_weapon_id", weapon_fighter.build.secondary_weapon_id))
		weapon_fighter._configure_original_loadout()
		var profile_id := "p%d" % player_index
		var unlocked := master_training_runtime.ledger.unlocked_variants(profile_id)
		weapon_fighter.set_unlocked_variants(MasterTrainingCatalog.variant_mapping(unlocked))
		weapon_fighter.set_selected_training_variant(StringName(loadout.get("variant_id", &"")))
	fighter.queue_redraw()
	return fighter

func _connect_fighter_signals(fighter: FighterController) -> void:
	fighter.defeated.connect(_on_fighter_defeated)
	fighter.parry_performed.connect(_on_parry_performed)
	fighter.posture_broken.connect(_on_posture_broken)
	fighter.weapon_disarmed.connect(_on_weapon_disarmed)
	fighter.loot_collected.connect(_on_loot_collected)
	fighter.grab_started.connect(_on_grab_started)
	fighter.grab_finished.connect(_on_grab_finished)
	if fighter.has_signal("elemental_state_changed"):
		fighter.connect("elemental_state_changed", Callable(self, "_on_elemental_state_changed"))
	if fighter.has_signal("elemental_interaction"):
		fighter.connect("elemental_interaction", Callable(self, "_on_elemental_interaction"))

func _update_camera(delta: float) -> void:
	var midpoint := (player_one.global_position + player_two.global_position) * 0.5
	midpoint.y = clampf(midpoint.y - 80.0, 280.0, 720.0)
	midpoint.x = clampf(midpoint.x, arena.camera_left_limit(), TriplePathArena.WORLD_WIDTH - 420.0)
	camera.global_position = camera.global_position.lerp(midpoint, 1.0 - exp(-5.0 * delta))
	var distance := player_one.global_position.distance_to(player_two.global_position)
	var desired_zoom := clampf(1180.0 / maxf(900.0, distance + 420.0), 0.62, 1.0)
	camera.zoom = camera.zoom.lerp(Vector2.ONE * desired_zoom, 1.0 - exp(-4.0 * delta))

func _update_hud() -> void:
	player_one_label.text = _fighter_summary(player_one, "P1 — %s" % player_one.build.character_name.to_upper())
	player_two_label.text = _fighter_summary(player_two, "P2 — %s" % player_two.build.character_name.to_upper())
	_update_skill_dock_player(1, player_one)
	_update_skill_dock_player(2, player_two)

func _fighter_summary(fighter: FighterController, title: String) -> String:
	var element_label := String(fighter.build.element_id).to_upper()
	var state_label := "ESTÁVEL"
	if fighter is ElementalFighterController:
		var elemental := fighter as ElementalFighterController
		element_label = elemental.current_element_label()
		state_label = elemental.current_elemental_status_label()
	return "%s\nVIDA %d  •  POST %d  •  FÔL %d\n%s • %s" % [
		title, roundi(fighter.health), roundi(fighter.posture), roundi(fighter.stamina), element_label, state_label
	]

func _build_skill_dock() -> void:
	_skill_dock = Control.new()
	_skill_dock.name = "MedievalSkillDock"
	_skill_dock.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_skill_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(_skill_dock)
	var dock := PanelContainer.new()
	dock.anchor_left = 0.5
	dock.anchor_top = 1.0
	dock.anchor_right = 0.5
	dock.anchor_bottom = 1.0
	dock.offset_left = -500.0
	dock.offset_top = -112.0
	dock.offset_right = 500.0
	dock.offset_bottom = -12.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.045, 0.025, 0.94)
	style.border_color = Color(0.66, 0.45, 0.20, 0.96)
	style.set_border_width_all(3)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	dock.add_theme_stylebox_override("panel", style)
	_skill_dock.add_child(dock)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	dock.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)
	row.add_child(_build_player_skill_strip(1))
	var seal := Label.new()
	seal.text = "TAI\nJI\nFU"
	seal.custom_minimum_size = Vector2(54, 78)
	seal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal.add_theme_font_size_override("font_size", 13)
	seal.add_theme_color_override("font_color", Color(0.95, 0.78, 0.40))
	row.add_child(seal)
	row.add_child(_build_player_skill_strip(2))
	_skill_dock.visible = false

func _build_player_skill_strip(player_index: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(445, 78)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.09, 0.05, 0.92)
	style.border_color = Color(0.36, 0.58, 0.76) if player_index == 1 else Color(0.72, 0.34, 0.22)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	var title := Label.new()
	title.text = "MESTRE %d • CÍRCULO DE TÉCNICAS" % player_index
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.92, 0.82, 0.58))
	column.add_child(title)
	var skills := HBoxContainer.new()
	skills.add_theme_constant_override("separation", 5)
	column.add_child(skills)
	var entries := [
		{"id":"dodge", "p1":"Q", "p2":"N0", "label":"ESQUIVA"},
		{"id":"technique", "p1":"F", "p2":"N1", "label":"TÉCNICA"},
		{"id":"push", "p1":"G", "p2":"N2", "label":"IMPULSO"},
		{"id":"grab", "p1":"E", "p2":"N4", "label":"AGARRÃO"},
		{"id":"element", "p1":"C", "p2":"N6", "label":"ELEMENTO"},
		{"id":"echo", "p1":"H", "p2":"N5", "label":"ECO"},
		{"id":"block", "p1":"R", "p2":"N3", "label":"DEFESA"}
	]
	var labels := {}
	for entry in entries:
		var slot := Label.new()
		var key := String(entry.p1) if player_index == 1 else String(entry.p2)
		slot.text = "%s\n%s" % [key, String(entry.label)]
		slot.custom_minimum_size = Vector2(57, 42)
		slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_theme_font_size_override("font_size", 9)
		slot.add_theme_color_override("font_color", Color(0.90, 0.86, 0.72))
		var slot_style := StyleBoxFlat.new()
		slot_style.bg_color = Color(0.06, 0.045, 0.03, 0.96)
		slot_style.border_color = Color(0.48, 0.34, 0.16, 0.9)
		slot_style.set_border_width_all(1)
		slot_style.corner_radius_top_left = 4
		slot_style.corner_radius_top_right = 4
		slot_style.corner_radius_bottom_left = 4
		slot_style.corner_radius_bottom_right = 4
		slot.add_theme_stylebox_override("normal", slot_style)
		skills.add_child(slot)
		labels[String(entry.id)] = slot
	_skill_labels[player_index - 1] = labels
	return panel

func _update_skill_dock_player(player_index: int, fighter: FighterController) -> void:
	if _skill_labels.size() < player_index:
		return
	var labels: Dictionary = _skill_labels[player_index - 1]
	if labels.is_empty():
		return
	var technique: Label = labels.get("technique")
	var element: Label = labels.get("element")
	var echo: Label = labels.get("echo")
	if technique != null:
		technique.tooltip_text = fighter.current_technique_label()
	if element != null:
		element.tooltip_text = String(fighter.build.element_id).to_upper()
	if echo != null:
		echo.tooltip_text = fighter.current_echo_label()

func _check_world_limits() -> void:
	for fighter in [player_one, player_two]:
		arena.apply_sector_pressure(fighter)
		if fighter.global_position.y > TriplePathArena.WORLD_HEIGHT + 120.0:
			fighter.receive_hit(9999.0, 9999.0, Vector2.ZERO, fighter.global_position)

func _on_parry_performed(_fighter: FighterController) -> void:
	_show_combat_event("APARO PERFEITO • FU", 0.45)

func _on_posture_broken(_fighter: FighterController, region_id: StringName) -> void:
	_show_combat_event("POSTURA QUEBRADA • %s" % String(region_id).to_upper(), 0.60)

func _on_weapon_disarmed(_fighter: FighterController, _weapon_id: StringName) -> void:
	_show_combat_event("DESARMAMENTO • ESPÓLIO LIBERADO", 0.72)

func _on_loot_collected(_fighter: FighterController, loot_type: StringName, _item_id: StringName) -> void:
	var label := "ARMA TOMADA" if loot_type == &"weapon" else "ECO DE TÉCNICA CAPTURADO"
	_show_combat_event(label, 0.72)

func _on_grab_started(_attacker: FighterController, _target: FighterController) -> void:
	_show_combat_event("CONTROLE JI • ESCOLHA A PROJEÇÃO", 0.42)

func _on_grab_finished(_attacker: FighterController, _target: FighterController) -> void:
	_show_combat_event("PROJEÇÃO DIRECIONAL • JI", 0.52)

func _on_elemental_state_changed(_fighter: FighterController, status_id: StringName) -> void:
	_show_combat_event("ESTADO ELEMENTAL • %s" % String(status_id).to_upper(), 0.56)

func _on_elemental_interaction(_fighter: FighterController, interaction_id: StringName, _element_id: StringName) -> void:
	var labels := {
		&"steam": "VAPOR • FOGO + ÁGUA", &"combustion": "COMBUSTÃO • FOGO + AR",
		&"mud": "LAMA • ÁGUA + TERRA", &"extinguished": "CHAMA EXTINTA • ÁGUA",
		&"air_resisted": "RAJADA CONTIDA • TERRA"
	}
	_show_combat_event(labels.get(interaction_id, "INTERAÇÃO ELEMENTAL"), 0.72)

func _on_sector_shifted(stage: int, _boundary_x: float) -> void:
	if stage == 0:
		return
	_show_combat_event(arena.closure_stage_label(), 0.95)

func _show_combat_event(message: String, duration: float) -> void:
	_message_sequence += 1
	var sequence := _message_sequence
	center_label.text = message
	await get_tree().create_timer(duration).timeout
	if sequence == _message_sequence and not _resetting_round:
		center_label.text = "RUÍNAS DO CAMINHO TRIPLO\nTAI • JI • FU"

func _on_fighter_defeated(_fighter: FighterController) -> void:
	if _resetting_round:
		return
	_resetting_round = true
	_message_sequence += 1
	center_label.text = "FLUXO INTERROMPIDO"
	await get_tree().create_timer(1.15).timeout
	_cleanup_temporary_loot()
	arena.reset_battle_flow()
	player_one.reset_fighter(arena.respawn_point(1))
	player_two.reset_fighter(arena.respawn_point(2))
	center_label.text = "ADAPTE-SE"
	await get_tree().create_timer(0.75).timeout
	center_label.text = "RUÍNAS DO CAMINHO TRIPLO\nTAI • JI • FU"
	_resetting_round = false

func _cleanup_temporary_loot() -> void:
	for loot in get_tree().get_nodes_in_group("temporary_loot"):
		loot.queue_free()

func _register_prototype_inputs() -> void:
	_add_key_action(&"p1_left", KEY_A)
	_add_key_action(&"p1_right", KEY_D)
	_add_key_action(&"p1_down", KEY_S)
	_add_key_action(&"p1_jump", KEY_W)
	_add_key_action(&"p1_dodge", KEY_Q)
	_add_key_action(&"p1_attack", KEY_F)
	_add_key_action(&"p1_push", KEY_G)
	_add_key_action(&"p1_grab", KEY_E)
	_add_key_action(&"p1_echo", KEY_H)
	_add_key_action(&"p1_block", KEY_R)
	_add_key_action(&"p1_element", KEY_C)
	_add_key_action(&"p1_swap", KEY_T)
	_add_key_action(&"p2_left", KEY_LEFT)
	_add_key_action(&"p2_right", KEY_RIGHT)
	_add_key_action(&"p2_down", KEY_DOWN)
	_add_key_action(&"p2_jump", KEY_UP)
	_add_key_action(&"p2_dodge", KEY_KP_0)
	_add_key_action(&"p2_attack", KEY_KP_1)
	_add_key_action(&"p2_push", KEY_KP_2)
	_add_key_action(&"p2_block", KEY_KP_3)
	_add_key_action(&"p2_grab", KEY_KP_4)
	_add_key_action(&"p2_echo", KEY_KP_5)
	_add_key_action(&"p2_element", KEY_KP_6)
	_add_key_action(&"p2_swap", KEY_KP_7)
	_add_key_action(&"start_match", KEY_ENTER)
	_register_gamepad_controls(1, 0)
	_register_gamepad_controls(2, 1)

func _register_gamepad_controls(player_index: int, device: int) -> void:
	_add_joy_axis(_player_action(player_index, "left"), JOY_AXIS_LEFT_X, -1.0, device)
	_add_joy_axis(_player_action(player_index, "right"), JOY_AXIS_LEFT_X, 1.0, device)
	_add_joy_axis(_player_action(player_index, "down"), JOY_AXIS_LEFT_Y, 1.0, device)
	_add_joy_button(_player_action(player_index, "jump"), JOY_BUTTON_A, device)
	_add_joy_button(_player_action(player_index, "dodge"), JOY_BUTTON_B, device)
	_add_joy_button(_player_action(player_index, "attack"), JOY_BUTTON_X, device)
	_add_joy_button(_player_action(player_index, "push"), JOY_BUTTON_Y, device)
	_add_joy_button(_player_action(player_index, "grab"), JOY_BUTTON_LEFT_SHOULDER, device)
	_add_joy_button(_player_action(player_index, "block"), JOY_BUTTON_RIGHT_SHOULDER, device)
	_add_joy_button(_player_action(player_index, "element"), JOY_BUTTON_LEFT_STICK, device)
	_add_joy_button(_player_action(player_index, "echo"), JOY_BUTTON_RIGHT_STICK, device)
	_add_joy_button(_player_action(player_index, "swap"), JOY_BUTTON_BACK, device)

func _player_action(player_index: int, suffix: String) -> StringName:
	return StringName("p%d_%s" % [player_index, suffix])

func _add_key_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.5)
	for existing_event in InputMap.action_get_events(action):
		if existing_event is InputEventKey and existing_event.physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)

func _add_joy_button(action: StringName, button_index: JoyButton, device: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.5)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton and existing.button_index == button_index and existing.device == device:
			return
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.device = device
	InputMap.action_add_event(action, event)

func _add_joy_axis(action: StringName, axis: JoyAxis, axis_value: float, device: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.5)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadMotion and existing.axis == axis and is_equal_approx(existing.axis_value, axis_value) and existing.device == device:
			return
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	event.device = device
	InputMap.action_add_event(action, event)
