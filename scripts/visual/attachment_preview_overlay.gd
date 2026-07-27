class_name AttachmentPreviewOverlay
extends Control

var _character_id: StringName = &"kael"
var _state_id: StringName = &"idle"
var _frame_index := 0
var _visible_guides := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func configure(character_id: StringName, state_id: StringName, frame_index: int) -> void:
	_character_id = character_id
	_state_id = state_id
	_frame_index = frame_index
	queue_redraw()

func set_guides_visible(value: bool) -> void:
	_visible_guides = value
	queue_redraw()

func guides_visible() -> bool:
	return _visible_guides

func _draw() -> void:
	if not _visible_guides:
		return
	var attachment := CharacterAttachmentCatalog.attachment(_character_id, _state_id, _frame_index, 1.0)
	var hand: Vector2 = attachment.get("hand", Vector2.ZERO)
	var rear_hand: Vector2 = attachment.get("rear_hand", Vector2.ZERO)
	var preview_scale := minf(size.x, size.y) / 150.0
	var origin := size * 0.5 + Vector2(0.0, 17.0 * preview_scale)
	var hand_point := origin + hand * preview_scale
	var rear_point := origin + rear_hand * preview_scale
	var facing_axis := origin + Vector2(42.0 * preview_scale, 0.0)
	draw_line(origin, facing_axis, Color(0.32, 0.82, 1.0, 0.38), 2.0)
	draw_circle(origin, 5.0, Color(0.34, 0.72, 0.96, 0.90))
	draw_line(rear_point, hand_point, Color(1.0, 0.78, 0.32, 0.82), 3.0)
	draw_circle(hand_point, 7.0, Color(1.0, 0.36, 0.24, 0.92))
	draw_circle(rear_point, 6.0, Color(0.72, 0.48, 1.0, 0.92))
	var angle := float(attachment.get("angle", 0.0))
	var direction := Vector2(cos(angle), sin(angle))
	draw_line(hand_point, hand_point + direction * 55.0 * preview_scale, Color(0.98, 0.92, 0.66, 0.90), 3.0)
