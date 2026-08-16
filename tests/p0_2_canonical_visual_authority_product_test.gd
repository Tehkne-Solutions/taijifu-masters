extends SceneTree

const BATTLE_SCENE := "res://scenes/vertical_slice/first_playable.tscn"
const MAX_WAIT_FRAMES := 480
const AUTHORITY_META := &"canonical_visual_authority"
const RETIRED_CHILD_VISUALS: Array[StringName] = [
	&"VisualOverlay",
	&"ExpressionOverlay",
	&"WeaponTrail",
	&"CosmeticSockets",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_cleanup()
	FirstPlayableSession.reset()
	FirstPlayableSession.set_difficulty(&"apprentice")

	var packed := load(BATTLE_SCENE) as PackedScene
	var battle := packed.instantiate() as FirstPlayableController if packed != null else null
	if battle == null:
		_fail("P0_2_CANONICAL_VISUAL_GATE=BLOCKED battle_scene")
		return
	battle.countdown_step_seconds = 0.01
	battle.fight_command_seconds = 0.01
	battle.match_time_limit_seconds = 40.0
	root.add_child(battle)

	if not await _wait_for_authority(battle):
		_fail("P0_2_CANONICAL_VISUAL_GATE=BLOCKED authority_timeout", battle)
		return
	var p1 := battle.player_one
	var p2 := battle.player_two
	if not is_instance_valid(p1) or not is_instance_valid(p2):
		_fail("P0_2_CANONICAL_VISUAL_GATE=BLOCKED fighters", battle)
		return

	var p1_presenter := p1.get_node_or_null("FirstPlayableRealAssetPresenter") as FirstPlayableLot01Presenter
	var p2_presenter := p2.get_node_or_null("FirstPlayableRealAssetPresenter") as TrainingRivalLot01Presenter
	if p1_presenter == null or p2_presenter == null:
		_fail("P0_2_CANONICAL_VISUAL_GATE=BLOCKED presenters", battle)
		return
	var p1_signature := p1_presenter.canonical_visual_authority_signature()
	var p2_signature := p2_presenter.canonical_visual_authority_signature()
	for entry in [p1_signature, p2_signature]:
		if not bool(entry.get("active", false)):
			_fail("P0_2_CANONICAL_VISUAL_GATE=BLOCKED signature_inactive:%s" % str(entry), battle)
			return
		if float(entry.get("fighter_self_modulate_alpha", 1.0)) > 0.001:
			_fail("P0_2_CANONICAL_VISUAL_GATE=BLOCKED self_modulate_alpha:%s" % str(entry), battle)
			return
		if bool(entry.get("provisional_fighter_draw_visible", true)):
			_fail("P0_2_CANONICAL_VISUAL_GATE=BLOCKED provisional_draw_visible:%s" % str(entry), battle)
			return
		if not bool(entry.get("provisional_child_visuals_retired", false)):
			_fail("P0_2_CANONICAL_VISUAL_GATE=BLOCKED provisional_children_active:%s" % str(entry), battle)
			return
		if bool(entry.get("collision_changes", true)) or bool(entry.get("combat_logic_changes", true)):
			_fail("P0_2_CANONICAL_VISUAL_GATE=BLOCKED owner_scope:%s" % str(entry), battle)
			return

	for fighter in [p1, p2]:
		if not bool(fighter.get_meta(AUTHORITY_META, false)):
			_fail("P0_2_CANONICAL_VISUAL_GATE=BLOCKED fighter_meta:index=%d" % fighter.player_index, battle)
			return
		if fighter.self_modulate.a > 0.001:
			_fail("P0_2_CANONICAL_VISUAL_GATE=BLOCKED fighter_self_alpha:index=%d value=%.4f" % [fighter.player_index, fighter.self_modulate.a], battle)
			return
		if fighter.modulate.a < 0.999 or not fighter.visible:
			_fail("P0_2_CANONICAL_VISUAL_GATE=BLOCKED child_visibility_chain:index=%d" % fighter.player_index, battle)
			return
		if not _provisional_children_retired(fighter):
			_fail("P0_2_CANONICAL_VISUAL_GATE=BLOCKED provisional_child_surface:index=%d" % fighter.player_index, battle)
			return
		var regional_hit_flash := fighter.get_node_or_null("RegionalHitFlash") as CanvasItem
		if regional_hit_flash == null or not regional_hit_flash.visible or regional_hit_flash.process_mode == Node.PROCESS_MODE_DISABLED:
			_fail("P0_2_CANONICAL_VISUAL_GATE=BLOCKED regional_hit_flash_retired:index=%d" % fighter.player_index, battle)
			return

	var modular := p1.get_node_or_null("FirstPlayableModularFighterPresenter") as FirstPlayableModularFighterPresenter
	var rival_sprite := p2_presenter.get_node_or_null("TrainingRivalLot01AnimatedSprite") as AnimatedSprite2D
	if modular == null or not modular.using_modular_assets() or modular.assembler() == null:
		_fail("P0_2_CANONICAL_VISUAL_GATE=BLOCKED p1_modular_child", battle)
		return
	if not modular.assembler().is_visible_in_tree():
		_fail("P0_2_CANONICAL_VISUAL_GATE=BLOCKED p1_child_hidden_by_self_modulate", battle)
		return
	if rival_sprite == null or not rival_sprite.is_visible_in_tree():
		_fail("P0_2_CANONICAL_VISUAL_GATE=BLOCKED p2_child_hidden_by_self_modulate", battle)
		return

	var pose_runtime := battle.get_node_or_null("FirstPlayableModularPoseRuntime") as FirstPlayableModularPoseRuntime
	if pose_runtime == null or not pose_runtime.authority_active():
		_fail("P0_2_CANONICAL_VISUAL_GATE=BLOCKED skeletal_authority", battle)
		return

	print("P0_2_CANONICAL_VISUAL_AUTHORITY=PASS p1=true p2=true")
	print("P0_2_PROVISIONAL_FIGHTER_DRAW=RETIRED p1=true p2=true self_modulate_alpha=0")
	print("P0_2_PROVISIONAL_CHILD_VISUALS=RETIRED p1=true p2=true regional_hit_flash=preserved")
	print("P0_2_CANONICAL_CHILD_PRESENTERS=PASS p1=modular_polygon p2=lot01_sprite")
	print("P0_2_CANONICAL_VISUAL_PRODUCT_GATE=PASS")
	print("SIGNATURE=Tehkné Solutions")
	battle.queue_free()
	await process_frame
	_cleanup()
	FirstPlayableSession.reset()
	quit(0)

func _wait_for_authority(battle: FirstPlayableController) -> bool:
	for _frame in range(MAX_WAIT_FRAMES):
		if is_instance_valid(battle.player_one) and is_instance_valid(battle.player_two):
			var p1_presenter := battle.player_one.get_node_or_null("FirstPlayableRealAssetPresenter") as FirstPlayableLot01Presenter
			var p2_presenter := battle.player_two.get_node_or_null("FirstPlayableRealAssetPresenter") as TrainingRivalLot01Presenter
			var modular := battle.player_one.get_node_or_null("FirstPlayableModularFighterPresenter") as FirstPlayableModularFighterPresenter
			var pose_runtime := battle.get_node_or_null("FirstPlayableModularPoseRuntime") as FirstPlayableModularPoseRuntime
			if (
				p1_presenter != null and p1_presenter.using_real_assets()
				and p2_presenter != null and p2_presenter.using_real_assets()
				and modular != null and modular.using_modular_assets()
				and pose_runtime != null and pose_runtime.authority_active()
				and bool(battle.player_one.get_meta(AUTHORITY_META, false))
				and bool(battle.player_two.get_meta(AUTHORITY_META, false))
			):
				return true
		await process_frame
	return false

func _provisional_children_retired(fighter: FighterController) -> bool:
	for node_name in RETIRED_CHILD_VISUALS:
		var surface := fighter.get_node_or_null(NodePath(String(node_name))) as CanvasItem
		if surface == null or surface.visible or surface.process_mode != Node.PROCESS_MODE_DISABLED:
			return false
	return true

func _cleanup() -> void:
	ModularFighterPresetStore.delete_user_preset(FirstPlayableSession.PRODUCTION_DEFAULT_PRESET_ID)

func _fail(message: String, battle: Node = null) -> void:
	Engine.time_scale = 1.0
	push_error(message)
	print(message)
	print("SIGNATURE=Tehkné Solutions")
	if is_instance_valid(battle):
		battle.queue_free()
	_cleanup()
	FirstPlayableSession.reset()
	quit(2)

# Tehkné Solutions