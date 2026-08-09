class_name ModularFighterLayerPolicy
extends RefCounted

## Canonical z-order contract for layered modular fighter visuals.
## Art packs consume this policy; individual modules must not invent local z-order.
## Tehkné Solutions

const SLOT_Z := {
	"hair_back": 5,
	"body_base": 10,
	"skin": 10,
	"torso_inner": 11,
	"legs": 11,
	"feet": 12,
	"arms": 12,
	"hands": 13,
	"waist": 14,
	"face_plate": 15,
	"face": 20,
	"eyes": 30,
	"brows": 40,
	"hair_front": 50,
	"head_accessory": 60,
	"torso_outer": 65,
	"shoulders": 70,
	"back_accessory": 4,
	"weapon_back": 3,
	"weapon_main": 80,
	"weapon_offhand": 81,
	"fx_aura": 90,
}

const HAIR_BACK_SLOT := &"hair_back"
const HAIR_FRONT_SLOT := &"hair_front"

static func z_index_for(slot: StringName) -> int:
	return int(SLOT_Z.get(String(slot), 10))

static func hair_order_is_valid() -> bool:
	return (
		z_index_for(HAIR_BACK_SLOT) < z_index_for(&"body_base")
		and z_index_for(&"body_base") < z_index_for(&"face_plate")
		and z_index_for(&"face_plate") < z_index_for(&"face")
		and z_index_for(&"face") < z_index_for(&"eyes")
		and z_index_for(&"eyes") < z_index_for(&"brows")
		and z_index_for(&"brows") < z_index_for(HAIR_FRONT_SLOT)
		and z_index_for(HAIR_FRONT_SLOT) < z_index_for(&"head_accessory")
	)

static func hair_slots() -> PackedStringArray:
	return PackedStringArray([String(HAIR_BACK_SLOT), String(HAIR_FRONT_SLOT)])

static func contract_signature() -> Dictionary:
	return {
		"policy": "modular_fighter_layer_policy_v1",
		"hair_back": z_index_for(HAIR_BACK_SLOT),
		"hair_front": z_index_for(HAIR_FRONT_SLOT),
		"head_accessory": z_index_for(&"head_accessory"),
		"hair_order_valid": hair_order_is_valid(),
		"signature": "Tehkné Solutions",
	}
