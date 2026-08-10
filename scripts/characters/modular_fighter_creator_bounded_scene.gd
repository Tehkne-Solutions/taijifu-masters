extends ModularFighterCreatorScene

## Bounds the reviewed public Creator selectors after their item catalogs are built.
## Godot OptionButton expands its minimum width to the longest item by default;
## BASE-05.4 keeps complete dropdown labels while clipping only the closed-button text
## to the reviewed 1280x720 control band.
## Tehkné Solutions

const REVIEWED_CONTROL_BOUNDS := {
	"armor": {"position": Vector2(470.0, 38.0), "size": Vector2(145.0, 42.0)},
	"back": {"position": Vector2(625.0, 38.0), "size": Vector2(145.0, 42.0)},
	"uniform": {"position": Vector2(780.0, 38.0), "size": Vector2(145.0, 42.0)},
	"hair": {"position": Vector2(935.0, 38.0), "size": Vector2(145.0, 42.0)},
	"weapon": {"position": Vector2(1090.0, 38.0), "size": Vector2(165.0, 42.0)},
}

func _ready() -> void:
	super._ready()
	call_deferred("_enforce_reviewed_control_bounds")

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

# Tehkné Solutions
