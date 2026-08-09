class_name FirstPlayableModularFighterPresenter
extends Node2D

## Shared modular animation runtime for creator presets in the First Playable.
## The complete ModularFighterAssembler is animated as one visual unit; identity
## and pack modules are never flattened into preset-specific sprite sheets.
## Tehkné Solutions

const BASE_TEXTURE_PATH := "res://assets/modular_fighters/base_00/base_fighter_v1_master.png"
const CANONICAL_PIVOT := Vector2(0.5, 0.92)
const TARGET_VISUAL_HEIGHT := 132.0
const HIT_VISUAL_SECONDS := 0.18
const RUNTIME_ID := "shared_modular_animation_runtime_v1"
const ANIMATION_STATES := [
	"idle", "run", "jump_start", "airborne", "fall",
	"attack_light", "guard", "dodge", "hit", "ko",
]

var _fighter: FighterController
var _assembler: ModularFighterAssembler
var _active := false
var _base_scale := 1.0
var _last_health := -1.0
var _hit_visual_timer := 0.0
var _visual_state: StringName = &"idle"
var _state_time := 0.0
var _preset_id: StringName = &""
var _hair_style_id: StringName = &"hair_none"

func _ready() -> void:
	_fighter = get_parent() as FighterController
	z_index = 6
	_try_activate()

func _process(delta: float) -> void:
	if not _active or not is_instance_valid(_fighter) or not is_instance_valid(_assembler):
		return
	if _last_health >= 0.0 and _fighter.health < _last_health - 0.001 and _fighter.health > 0.0:
		_hit_visual_timer = HIT_VISUAL_SECONDS
	_last_health = _fighter.health
	_hit_visual_timer = maxf(0.0, _hit_visual_timer - delta)

	var next_state := _resolve_visual_state()
	if next_state != _visual_state:
		_visual_state = next_state
		_state_time = 0.0
	else:
		_state_time += delta
	_apply_state_transform()

func using_modular_assets() -> bool:
	return _active

func active_preset_id() -> StringName:
	return _preset_id

func active_hair_style_id() -> StringName:
	return _hair_style_id

func visual_state() -> StringName:
	return _visual_state

func assembler() -> ModularFighterAssembler:
	return _assembler

func runtime_signature() -> Dictionary:
	return {
		"runtime": RUNTIME_ID,
		"active": _active,
		"preset_id": String(_preset_id),
		"hair_style_id": String(_hair_style_id),
		"states": ANIMATION_STATES.duplicate(),
		"state_count": ANIMATION_STATES.size(),
		"world_translation_owner": "fighter_physics",
		"identity_animation_policy": "animate_complete_assembler",
		"preset_specific_sprite_sheet": false,
		"lian_fallback_preserved": true,
		"collision_changes": false,
		"signature": "Tehkné Solutions",
	}

func _try_activate() -> void:
	if not is_instance_valid(_fighter) or _fighter.player_index != 1:
		print("C65_MODULAR_PRESENTER=BLOCKED reason=not_player_one")
		return
	if not FirstPlayableSession.has_creator_preset():
		print("C65_MODULAR_PRESENTER=BLOCKED reason=no_creator_preset")
		return
	var profile_result := FirstPlayableSession.creator_profile_result()
	if not bool(profile_result.get("ok", false)):
		print("C65_MODULAR_PRESENTER=BLOCKED reason=profile_unavailable")
		return
	var profile = profile_result.get("profile")
	if not (profile is ModularFighterProfile):
		print("C65_MODULAR_PRESENTER=BLOCKED reason=profile_invalid")
		return
	if not ResourceLoader.exists(BASE_TEXTURE_PATH):
		print("C65_MODULAR_PRESENTER=BLOCKED reason=base_texture_missing")
		return
	var texture := load(BASE_TEXTURE_PATH) as Texture2D
	if texture == null:
		print("C65_MODULAR_PRESENTER=BLOCKED reason=base_texture_invalid")
		return
	var source_image := texture.get_image()
	if source_image == null or source_image.is_empty():
		print("C65_MODULAR_PRESENTER=BLOCKED reason=base_image_invalid")
		return
	var used := source_image.get_used_rect()
	if used.size.y <= 0:
		print("C65_MODULAR_PRESENTER=BLOCKED reason=base_alpha_bounds")
		return

	var candidate := ModularFighterAssembler.new()
	candidate.name = "AnimatedModularAssembler"
	add_child(candidate)
	var failures := candidate.configure(profile as ModularFighterProfile)
	if not failures.is_empty():
		candidate.queue_free()
		print("C65_MODULAR_PRESENTER=BLOCKED reason=configure failures=%s" % ",".join(failures))
		return

	var body := Sprite2D.new()
	body.texture = texture
	body.centered = true
	body.position = Vector2(
		texture.get_width() * (0.5 - CANONICAL_PIVOT.x),
		texture.get_height() * (0.5 - CANONICAL_PIVOT.y)
	)
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if not candidate.attach_visual_module(&"body_base", body):
		candidate.queue_free()
		print("C65_MODULAR_PRESENTER=BLOCKED reason=body_attach")
		return

	failures = candidate.assemble_base01_profile_identity()
	if not failures.is_empty():
		candidate.queue_free()
		print("C65_MODULAR_PRESENTER=BLOCKED reason=identity_assembly failures=%s" % ",".join(failures))
		return

	# C66.1 composes optional Hair after BASE-01 identity is valid. hair_none is a
	# no-op, so all existing presets preserve the exact C65 visual behavior.
	failures = ModularFighterHairRuntime.assemble_profile(profile as ModularFighterProfile, candidate)
	if not failures.is_empty():
		candidate.queue_free()
		print("C65_MODULAR_PRESENTER=BLOCKED reason=hair_assembly failures=%s" % ",".join(failures))
		return
	_hair_style_id = ModularFighterHairRuntime.profile_style_id(profile as ModularFighterProfile)

	_base_scale = TARGET_VISUAL_HEIGHT / float(used.size.y)
	candidate.scale = Vector2.ONE * _base_scale
	candidate.position = Vector2.ZERO
	candidate.rotation = 0.0
	candidate.skew = 0.0
	_assembler = candidate
	_preset_id = FirstPlayableSession.creator_preset_id()
	_last_health = _fighter.health
	_active = true
	_hide_lian_fallback()
	_promote_battle_handoff()
	print("C65_MODULAR_PRESENTER=PASS preset=%s state_count=%d" % [String(_preset_id), ANIMATION_STATES.size()])
	print("C65_MODULAR_BASE_ALIGNMENT=PASS pivot=%.2f,%.2f used=%s body_position=%s scale=%.6f" % [
		CANONICAL_PIVOT.x,
		CANONICAL_PIVOT.y,
		str(used),
		str(body.position),
		_base_scale,
	])
	print("C65_MODULAR_IDENTITY=PASS skin=%s face=%s eyes=%s brows=%s" % [
		String(_assembler.active_skin_palette_id()),
		String(_assembler.active_identity_module_id(&"face")),
		String(_assembler.active_identity_module_id(&"eyes")),
		String(_assembler.active_identity_module_id(&"brows")),
	])
	if _hair_style_id != &"hair_none":
		var hair_signature := ModularFighterHairRuntime.runtime_signature(profile as ModularFighterProfile, _assembler)
		print("C66_1_HAIR_RUNTIME=PASS style=%s back_z=%d front_z=%d" % [
			String(_hair_style_id),
			int(hair_signature.get("hair_back_z", -1)),
			int(hair_signature.get("hair_front_z", -1)),
		])
	print("C65_LIAN_FALLBACK=HIDDEN_PRESERVED")
	print("SIGNATURE=Tehkné Solutions")

func _hide_lian_fallback() -> void:
	if not is_instance_valid(_fighter):
		return
	var fallback := _fighter.get_node_or_null("FirstPlayableRealAssetPresenter") as CanvasItem
	if fallback != null:
		fallback.visible = false

func _promote_battle_handoff() -> void:
	var handoff := FirstPlayableSession.creator_battle_handoff_signature()
	handoff["visual_activation"] = true
	handoff["visual_blocker"] = ""
	handoff["visual_runtime"] = RUNTIME_ID
	handoff["animation_states"] = ANIMATION_STATES.duplicate()
	handoff["hair_style_id"] = String(_hair_style_id)
	handoff["static_sprite_regression_allowed"] = false
	handoff["lian_fallback_preserved"] = true
	handoff["preset_specific_sprite_sheet"] = false
	_fighter.set_meta("creator_battle_handoff", handoff)

func _resolve_visual_state() -> StringName:
	if _fighter.health <= 0.0:
		return &"ko"
	if _hit_visual_timer > 0.0:
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

func _apply_state_transform() -> void:
	var facing_sign := -1.0 if _fighter.facing < 0.0 else 1.0
	var local_scale := Vector2.ONE
	var target_rotation := 0.0
	var target_skew := 0.0
	var target_offset := Vector2.ZERO
	match _visual_state:
		&"idle":
			var breath := sin(_state_time * 2.4) * 0.004
			local_scale = Vector2(1.0 - breath * 0.5, 1.0 + breath)
		&"run":
			target_skew = -0.055 * facing_sign
			target_offset.y = sin(_state_time * 15.0) * 1.2
		&"jump_start":
			local_scale = Vector2(1.025, 0.965)
		&"airborne":
			target_rotation = -0.025 * facing_sign
		&"fall":
			target_rotation = 0.035 * facing_sign
		&"attack_light":
			target_skew = -0.095 * facing_sign
			target_rotation = -0.018 * facing_sign
		&"guard":
			local_scale = Vector2(1.02, 0.975)
			target_rotation = 0.012 * facing_sign
		&"dodge":
			target_skew = 0.115 * facing_sign
			local_scale = Vector2(1.015, 0.985)
		&"hit":
			target_skew = 0.10 * facing_sign
			target_rotation = 0.025 * facing_sign
		&"ko":
			target_rotation = clampf(_state_time / 0.35, 0.0, 1.0) * (PI * 0.5) * facing_sign

	_assembler.position = _assembler.position.lerp(target_offset, 0.34)
	_assembler.rotation = lerpf(_assembler.rotation, target_rotation, 0.34)
	_assembler.skew = lerpf(_assembler.skew, target_skew, 0.34)
	_assembler.scale = Vector2(
		_base_scale * local_scale.x * facing_sign,
		_base_scale * local_scale.y
	)

# Tehkné Solutions