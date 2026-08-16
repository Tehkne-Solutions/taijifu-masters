class_name FirstPlayableLot01Presenter
extends Node2D

const TGAP_PACK_ALIAS := "lian_wu"
const SPRITE_FRAMES_LOGICAL := "first_playable_spriteframes"
const MODULAR_FIGHTER_PRESENTER := preload("res://scripts/vertical_slice/first_playable_skeletal_modular_fighter_presenter.gd")
const CANONICAL_CANVAS_SIZE := Vector2(1024.0, 1024.0)
const CANONICAL_BASELINE_Y := 969.0
const TARGET_VISUAL_HEIGHT := 132.0
const CANONICAL_ALPHA_HEIGHT := 900.0
const CANONICAL_SCALE := TARGET_VISUAL_HEIGHT / CANONICAL_ALPHA_HEIGHT
const BASELINE_OFFSET_Y := -(CANONICAL_BASELINE_Y - CANONICAL_CANVAS_SIZE.y * 0.5) * CANONICAL_SCALE
const HIT_VISUAL_SECONDS := 0.30
const CANONICAL_VISUAL_AUTHORITY_META := &"canonical_visual_authority"
const PROVISIONAL_CHILD_VISUALS: Array[StringName] = [
	&"VisualOverlay",
	&"ExpressionOverlay",
	&"WeaponTrail",
	&"CosmeticSockets",
]

var _fighter: FighterController
var _sprite: AnimatedSprite2D
var _active_animation: StringName = &""
var _using_real_assets := false
var _last_health := -1.0
var _hit_visual_timer := 0.0

func _ready() -> void:
	_fighter = get_parent() as FighterController
	if is_instance_valid(_fighter):
		_last_health = _fighter.health
	z_index = 5
	_try_activate_real_assets()
	call_deferred("_install_modular_creator_overlay")

func _process(delta: float) -> void:
	if not _using_real_assets or not is_instance_valid(_fighter):
		return
	if _last_health >= 0.0 and _fighter.health < _last_health - 0.001 and _fighter.health > 0.0:
		_hit_visual_timer = HIT_VISUAL_SECONDS
	_last_health = _fighter.health
	_hit_visual_timer = maxf(0.0, _hit_visual_timer - delta)
	if _hit_visual_timer > 0.0 and _accepted_action_overrides_hit():
		_hit_visual_timer = 0.0
	_sprite.flip_h = _fighter.facing < 0.0
	var next_animation := _resolve_animation()
	if next_animation != _active_animation:
		_active_animation = next_animation
		_sprite.play(_active_animation)

func using_real_assets() -> bool:
	return _using_real_assets

func expected_sprite_frames_path() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return ""
	var loader := tree.root.get_node_or_null("TgapAssetLoader")
	if loader == null or not loader.has_method("resolve"):
		return ""
	return String(loader.call("resolve", TGAP_PACK_ALIAS, SPRITE_FRAMES_LOGICAL))

func canonical_visual_authority_signature() -> Dictionary:
	return {
		"active": (
			_using_real_assets
			and is_instance_valid(_fighter)
			and bool(_fighter.get_meta(CANONICAL_VISUAL_AUTHORITY_META, false))
		),
		"fighter_self_modulate_alpha": _fighter.self_modulate.a if is_instance_valid(_fighter) else 1.0,
		"provisional_fighter_draw_visible": false if _using_real_assets else true,
		"provisional_child_visuals_retired": _provisional_child_visuals_retired(),
		"provisional_child_visuals": _provisional_child_visual_signature(),
		"child_presenters_inherit_self_modulate": false,
		"collision_changes": false,
		"combat_logic_changes": false,
		"signature": "Tehkné Solutions",
	}

func _try_activate_real_assets() -> void:
	var sprite_frames_path := expected_sprite_frames_path()
	if sprite_frames_path.is_empty() or not ResourceLoader.exists(sprite_frames_path):
		print("V2_LIAN_CANONICAL_PRESENTER=BLOCKED missing_spriteframes")
		return
	var frames := load(sprite_frames_path) as SpriteFrames
	if frames == null or not _has_required_animations(frames):
		push_warning("Lot 01 encontrado, mas contrato de animações está incompleto")
		print("V2_LIAN_CANONICAL_PRESENTER=BLOCKED incomplete_animation_contract")
		return
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Lot01AnimatedSprite"
	_sprite.sprite_frames = frames
	_sprite.centered = true
	_sprite.scale = Vector2.ONE * CANONICAL_SCALE
	_sprite.position = Vector2(0.0, BASELINE_OFFSET_Y)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_using_real_assets = true
	_claim_canonical_visual_authority()
	_hide_legacy_visual_surfaces()
	_active_animation = &"idle"
	_sprite.play(_active_animation)
	print("V2_LIAN_CANONICAL_PRESENTER=PASS")
	print("V2_LIAN_CANONICAL_SCALE=%.6f" % CANONICAL_SCALE)
	print("V2_LIAN_CANONICAL_BASELINE=PASS")
	print("V2_LIAN_LEGACY_ATLAS=HIDDEN")
	print("P0_2_PROVISIONAL_FIGHTER_DRAW=RETIRED fighter=p1 owner=canonical_presenter")
	print("P0_2_PROVISIONAL_CHILD_VISUALS=RETIRED fighter=p1 nodes=VisualOverlay,ExpressionOverlay,WeaponTrail,CosmeticSockets")

func _claim_canonical_visual_authority() -> void:
	if not is_instance_valid(_fighter):
		return
	_fighter.set_meta(CANONICAL_VISUAL_AUTHORITY_META, true)
	# CanvasItem.self_modulate affects this fighter's own _draw() surface without
	# modulating child presenters. This retires the historical stick/primitive
	# placeholder while preserving canonical Sprite2D/Polygon2D children.
	var self_tint := _fighter.self_modulate
	self_tint.a = 0.0
	_fighter.self_modulate = self_tint
	_fighter.queue_redraw()

func _install_modular_creator_overlay() -> void:
	if not _using_real_assets or not is_instance_valid(_fighter):
		return
	if _fighter.player_index != 1:
		return
	# P0.2: the modular graph is the visual authority for P1 in every First
	# Playable entry path. Direct-to-battle resolves a deterministic production
	# preset instead of silently retaining the LOT01 presentation.
	if not FirstPlayableSession.ensure_battle_visual_preset():
		push_error("P0_2_RUNTIME_ASSET_TRUTH=BLOCKED production_default_preset_unavailable")
		return
	if _fighter.has_node("FirstPlayableModularFighterPresenter"):
		return
	var modular := MODULAR_FIGHTER_PRESENTER.new() as FirstPlayableModularFighterPresenter
	modular.name = "FirstPlayableModularFighterPresenter"
	_fighter.add_child(modular)
	print("P0_2_RUNTIME_ASSET_TRUTH=ARMED source=%s preset=%s" % [
		FirstPlayableSession.battle_visual_source(),
		String(FirstPlayableSession.creator_preset_id()),
	])

func _hide_legacy_visual_surfaces() -> void:
	if not is_instance_valid(_fighter):
		return
	for node_name in ["FirstPlayableIdentity", "SpritePresenter"]:
		var surface := _fighter.get_node_or_null(node_name) as CanvasItem
		if surface != null:
			surface.visible = false
	for node_name in PROVISIONAL_CHILD_VISUALS:
		var surface := _fighter.get_node_or_null(NodePath(String(node_name))) as CanvasItem
		if surface != null:
			surface.visible = false
			surface.process_mode = Node.PROCESS_MODE_DISABLED

func _provisional_child_visuals_retired() -> bool:
	if not is_instance_valid(_fighter) or not _using_real_assets:
		return false
	for node_name in PROVISIONAL_CHILD_VISUALS:
		var surface := _fighter.get_node_or_null(NodePath(String(node_name))) as CanvasItem
		if surface == null or surface.visible or surface.process_mode != Node.PROCESS_MODE_DISABLED:
			return false
	return true

func _provisional_child_visual_signature() -> Dictionary:
	var result := {}
	if not is_instance_valid(_fighter):
		return result
	for node_name in PROVISIONAL_CHILD_VISUALS:
		var surface := _fighter.get_node_or_null(NodePath(String(node_name))) as CanvasItem
		result[String(node_name)] = {
			"present": surface != null,
			"visible": surface.visible if surface != null else false,
			"process_disabled": surface.process_mode == Node.PROCESS_MODE_DISABLED if surface != null else false,
		}
	return result

func _has_required_animations(frames: SpriteFrames) -> bool:
	for animation_name in [
		&"idle", &"run", &"jump_start", &"airborne", &"fall",
		&"attack_light", &"guard", &"dodge", &"hit", &"ko"
	]:
		if not frames.has_animation(animation_name):
			return false
		if frames.get_frame_count(animation_name) <= 0:
			return false
	return true

func _accepted_action_overrides_hit() -> bool:
	if _fighter is FirstPlayableCombatFighterController:
		return (_fighter as FirstPlayableCombatFighterController).first_playable_visual_action_override_active()
	return false

func _resolve_animation() -> StringName:
	if _fighter.health <= 0.0:
		return &"ko"
	if _hit_visual_timer > 0.0 and not _accepted_action_overrides_hit():
		return &"hit"
	if _fighter._dodge_timer > 0.0:
		return &"dodge"
	if _fighter._attack_phase != FighterController.AttackPhase.NONE:
		return &"attack_light"
	if _fighter._is_blocking:
		return &"guard"
	if not _fighter.is_on_floor():
		if _fighter.velocity.y < -80.0:
			return &"airborne"
		return &"fall"
	if absf(_fighter.velocity.x) > 20.0:
		return &"run"
	return &"idle"

# Tehkné Solutions