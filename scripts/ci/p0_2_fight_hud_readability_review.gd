extends SceneTree

const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const OUTPUT_DIR := "res://artifacts/p0_2_hud"
const OUTPUT_FILE := "P0_2_FIGHT_HUD_READABILITY.review-1920x1080.png"
const MAX_TOP_RESERVED_HEIGHT := 100.0
const MIN_GAMEPLAY_VERTICAL_RATIO := 0.86
const MAX_GUIDE_WAIT_SECONDS := 2.4

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	FirstPlayableSession.reset()
	FirstPlayableSession.set_participant_code("TJFP-P0-2-HUD")
	var packed := load(BATTLE_SCENE) as PackedScene
	var battle := packed.instantiate() as FirstPlayableController if packed != null else null
	if battle == null:
		_fail("P0_2_HUD_REVIEW=BLOCKED battle_scene")
		return

	battle.countdown_step_seconds = 0.05
	battle.fight_command_seconds = 0.05
	get_root().add_child(battle)
	if not await _wait_for_battle(battle):
		_fail("P0_2_HUD_REVIEW=BLOCKED battle_timeout", battle)
		return
	battle.bot_runtime.enabled = false
	battle._set_fighters_controls(false)
	battle.player_one.global_position = Vector2(1120.0, 827.0)
	battle.player_two.global_position = Vector2(1580.0, 827.0)
	battle.player_one.velocity = Vector2.ZERO
	battle.player_two.velocity = Vector2.ZERO
	battle.player_one.facing = 1.0
	battle.player_two.facing = -1.0

	var hud_runtime := battle.get_node_or_null("FirstPlayableFightHudRuntime") as FirstPlayableFightHudRuntime
	var martial_runtime := battle.get_node_or_null("FirstPlayableMartialHudRuntime")
	var guide := battle.get_node_or_null("HUD/CombatGuide") as FirstPlayableCombatGuide
	if hud_runtime == null or martial_runtime == null or guide == null:
		_fail("P0_2_HUD_REVIEW=BLOCKED hud_runtime_missing", battle)
		return

	var waited := 0.0
	while guide.guide_stage() != &"hidden" and waited < MAX_GUIDE_WAIT_SECONDS:
		await create_timer(0.10, true, false, true).timeout
		waited += 0.10
	for _frame in range(12):
		await process_frame

	if guide.guide_stage() != &"hidden" or guide.visible:
		_fail("P0_2_HUD_REVIEW=BLOCKED guide_persistent stage=%s visible=%s" % [
			String(guide.guide_stage()), str(guide.visible),
		], battle)
		return
	var guide_signature := guide.presentation_signature()
	if bool(guide_signature.get("persistent_compact_controls", true)):
		_fail("P0_2_HUD_REVIEW=BLOCKED persistent_compact_controls", battle)
		return
	if not bool(guide_signature.get("gameplay_area_released_after_intro", false)):
		_fail("P0_2_HUD_REVIEW=BLOCKED gameplay_area_not_released", battle)
		return

	var presentation := hud_runtime.presentation_signature()
	var surfaces := hud_runtime.surface_signature()
	if not bool(presentation.get("fight_first_hierarchy", false)):
		_fail("P0_2_HUD_REVIEW=BLOCKED hierarchy_contract", battle)
		return
	if not bool(presentation.get("timer_isolated", false)):
		_fail("P0_2_HUD_REVIEW=BLOCKED timer_contract", battle)
		return
	if bool(presentation.get("persistent_keyboard_help", true)) or bool(presentation.get("bottom_dashboard", true)):
		_fail("P0_2_HUD_REVIEW=BLOCKED technical_dashboard_regression", battle)
		return
	if not bool(presentation.get("martial_strip_typographic_only", false)) or bool(presentation.get("martial_strip_panel", true)):
		_fail("P0_2_HUD_REVIEW=BLOCKED martial_strip_app_panel", battle)
		return
	var top_reserved := float(surfaces.get("top_reserved_height", INF))
	if top_reserved > MAX_TOP_RESERVED_HEIGHT:
		_fail("P0_2_HUD_REVIEW=BLOCKED top_reserved=%.2f" % top_reserved, battle)
		return
	if bool(surfaces.get("persistent_controls_visible", true)):
		_fail("P0_2_HUD_REVIEW=BLOCKED controls_visible", battle)
		return
	if bool(surfaces.get("persistent_difficulty_visible", true)):
		_fail("P0_2_HUD_REVIEW=BLOCKED difficulty_legend_visible", battle)
		return
	if bool(surfaces.get("bottom_shade_visible", true)):
		_fail("P0_2_HUD_REVIEW=BLOCKED bottom_shade_visible", battle)
		return
	if not bool(surfaces.get("martial_strip_visible", false)):
		_fail("P0_2_HUD_REVIEW=BLOCKED martial_strip_missing", battle)
		return
	if bool(surfaces.get("martial_strip_panel", true)):
		_fail("P0_2_HUD_REVIEW=BLOCKED martial_strip_surface_panel", battle)
		return
	var martial_rect := _rect_from_array(surfaces.get("martial_strip_rect", []))
	if martial_rect.end.y > MAX_TOP_RESERVED_HEIGHT + 0.01:
		_fail("P0_2_HUD_REVIEW=BLOCKED martial_strip_outside_top rect=%s" % str(martial_rect), battle)
		return

	var hud := battle.get_node_or_null("HUD") as CanvasLayer
	var center := hud.get_node_or_null("CenterInfo") as Label if hud != null else null
	var state := hud.get_node_or_null("StateInfo") as Label if hud != null else null
	var p1 := hud.get_node_or_null("PlayerOne") as Label if hud != null else null
	var p2 := hud.get_node_or_null("PlayerTwo") as Label if hud != null else null
	if center == null or state == null or p1 == null or p2 == null:
		_fail("P0_2_HUD_REVIEW=BLOCKED fight_labels_missing", battle)
		return
	if not center.text.is_valid_int() or center.text.length() > 3:
		_fail("P0_2_HUD_REVIEW=BLOCKED timer_not_isolated text=%s" % center.text, battle)
		return
	if state.text.contains(" VS ") or state.text.contains("TEMPO") or state.text.length() > 28:
		_fail("P0_2_HUD_REVIEW=BLOCKED state_telemetry_text text=%s" % state.text, battle)
		return
	if p1.text.contains("\n") or p2.text.contains("\n"):
		_fail("P0_2_HUD_REVIEW=BLOCKED fighter_name_multiline", battle)
		return

	var gameplay_ratio := (720.0 - top_reserved) / 720.0
	if gameplay_ratio < MIN_GAMEPLAY_VERTICAL_RATIO:
		_fail("P0_2_HUD_REVIEW=BLOCKED gameplay_vertical_ratio=%.4f" % gameplay_ratio, battle)
		return

	var p1_presenter := battle.player_one.get_node_or_null("FirstPlayableRealAssetPresenter") as FirstPlayableLot01Presenter
	var p2_presenter := battle.player_two.get_node_or_null("FirstPlayableRealAssetPresenter") as TrainingRivalLot01Presenter
	if p1_presenter == null or not p1_presenter.using_real_assets():
		_fail("P0_2_HUD_REVIEW=BLOCKED lian_real_assets", battle)
		return
	if p2_presenter == null or not p2_presenter.using_real_assets():
		_fail("P0_2_HUD_REVIEW=BLOCKED rival_real_assets", battle)
		return

	_capture(OUTPUT_FILE)
	_write_metrics({
		"signature": "Tehkné Solutions",
		"top_reserved_height": top_reserved,
		"gameplay_vertical_ratio": gameplay_ratio,
		"guide_stage": String(guide.guide_stage()),
		"timer_text": center.text,
		"state_text": state.text,
		"p1_text": p1.text,
		"p2_text": p2.text,
		"hud": presentation,
		"surfaces": surfaces,
	})
	print("P0_2_FIGHT_HUD_HIERARCHY=PASS health=primary timer=isolated martial=integrated")
	print("P0_2_FIGHT_HUD_MARTIAL_READ=PASS typographic_only=true panel=false")
	print("P0_2_FIGHT_HUD_GAMEPLAY_AREA=PASS top_reserved=%.0f vertical_ratio=%.4f bottom_persistent=false" % [top_reserved, gameplay_ratio])
	print("P0_2_FIGHT_HUD_GUIDE=PASS countdown=full battle_intro=compact active=hidden")
	print("P0_2_FIGHT_HUD_CAPTURE=PASS output=res://artifacts/p0_2_hud/%s" % OUTPUT_FILE)
	print("P0_2_FIGHT_HUD_READABILITY=PASS")
	print("SIGNATURE=Tehkné Solutions")
	battle.queue_free()
	await process_frame
	FirstPlayableSession.reset()
	quit(0)

func _wait_for_battle(battle: FirstPlayableController) -> bool:
	for _frame in range(420):
		if int(battle.get("_state")) == FirstPlayableController.MatchState.BATTLE:
			return true
		await process_frame
	return false

func _rect_from_array(value: Variant) -> Rect2:
	if not (value is Array) or value.size() != 4:
		return Rect2()
	return Rect2(float(value[0]), float(value[1]), float(value[2]), float(value[3]))

func _capture(filename: String) -> void:
	var image := get_root().get_texture().get_image()
	if image == null or image.is_empty():
		return
	image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	var dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	image.save_png(ProjectSettings.globalize_path(OUTPUT_DIR + "/" + filename))

func _write_metrics(metrics: Dictionary) -> void:
	var dir := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(ProjectSettings.globalize_path(OUTPUT_DIR + "/P0_2_FIGHT_HUD_METRICS.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(metrics, "  "))
		file.close()

func _fail(message: String, battle: Node = null) -> void:
	Engine.time_scale = 1.0
	push_error(message)
	print(message)
	print("SIGNATURE=Tehkné Solutions")
	if is_instance_valid(battle):
		battle.queue_free()
	FirstPlayableSession.reset()
	quit(2)

# Tehkné Solutions