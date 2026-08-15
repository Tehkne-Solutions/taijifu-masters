extends ModularFighterCreatorScene

## Bounds the reviewed public Creator selectors after their item catalogs are built.
## Godot OptionButton expands its minimum width to the longest item by default;
## BASE-05.4 keeps complete dropdown labels while clipping only the closed-button text
## to the reviewed 1280x720 control band.
## P0.2 additionally exposes the real production-backed option counts and makes the
## provisional modular-motion status visible instead of presenting transform-only
## animation as final authored motion.
## Tehkné Solutions

const REVIEWED_CONTROL_BOUNDS := {
	"armor": {"position": Vector2(470.0, 38.0), "size": Vector2(145.0, 42.0)},
	"back": {"position": Vector2(625.0, 38.0), "size": Vector2(145.0, 42.0)},
	"uniform": {"position": Vector2(780.0, 38.0), "size": Vector2(145.0, 42.0)},
	"hair": {"position": Vector2(935.0, 38.0), "size": Vector2(145.0, 42.0)},
	"weapon": {"position": Vector2(1090.0, 38.0), "size": Vector2(165.0, 42.0)},
}

var _product_readiness_label: Label

func _ready() -> void:
	super._ready()
	call_deferred("_enforce_reviewed_control_bounds")
	call_deferred("_install_product_readiness_label")
	creator_state_changed.connect(_refresh_product_readiness_label)

func _enforce_reviewed_control_bounds() -> void:
	var controls := {
		"armor": armor_set_option(),
		"back": back_accessory_option(),
		"uniform": uniform_set_option(),
		"hair": hair_style_option(),
		"weapon": weapon_set_option(),
	}
	for key in controls:
		var option := controls[key] as OptionButton
		if option == null:
			continue
		var contract: Dictionary = REVIEWED_CONTROL_BOUNDS[key]
		option.fit_to_longest_item = false
		option.clip_text = true
		option.position = contract["position"]
		option.size = contract["size"]

func _install_product_readiness_label() -> void:
	if is_instance_valid(_product_readiness_label):
		_refresh_product_readiness_label()
		return
	_product_readiness_label = Label.new()
	_product_readiness_label.name = "ProductReadiness"
	_product_readiness_label.position = Vector2(470.0, 88.0)
	_product_readiness_label.size = Vector2(785.0, 24.0)
	_product_readiness_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_product_readiness_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_product_readiness_label.add_theme_font_size_override("font_size", 10)
	_product_readiness_label.add_theme_color_override("font_color", Color("d9b76d"))
	add_child(_product_readiness_label)
	_refresh_product_readiness_label()

func _refresh_product_readiness_label() -> void:
	if not is_instance_valid(_product_readiness_label):
		return
	var readiness := creator_product_readiness_signature()
	_product_readiness_label.text = (
		"PRODUÇÃO REAL • identidade %d • cabelo %d • uniforme %d • armadura %d • costas %d • arma %d   |   MOVIMENTO MODULAR: PROVISÓRIO"
		% [
			int(readiness.get("identity_options", 0)),
			int(readiness.get("hair_options", 0)),
			int(readiness.get("uniform_options", 0)),
			int(readiness.get("armor_options", 0)),
			int(readiness.get("back_accessory_options", 0)),
			int(readiness.get("weapon_options", 0)),
		]
	)

func creator_product_readiness_signature() -> Dictionary:
	var base_signature := super.flow_signature()
	return {
		"identity_options": int(base_signature.get("identity_options", 0)),
		"hair_options": ModularFighterHairRuntime.creator_style_ids().size(),
		"uniform_options": ModularFighterUniformRuntime.creator_set_ids().size(),
		"armor_options": ModularFighterArmorRuntime.creator_armor_set_ids().size(),
		"back_accessory_options": ModularFighterArmorRuntime.creator_back_accessory_ids().size(),
		"weapon_options": ModularFighterEquipmentRuntime.creator_weapon_set_ids().size(),
		"options_are_production_backed": true,
		"live_preview": true,
		"battle_handoff_runtime": "shared_modular_animation_runtime_v1",
		"battle_visual_activation": "on_complete_assembly",
		"fallback_policy": "lian_only_on_explicit_assembly_failure",
		"motion_quality": "placeholder_transform_runtime",
		"authored_motion_final": false,
		"pack04_required_for_final_motion": true,
		"human_review_required": true,
		"signature": "Tehkné Solutions",
	}

# Tehkné Solutions
