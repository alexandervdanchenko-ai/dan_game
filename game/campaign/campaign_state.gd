class_name CampaignState
extends RefCounted

const Items = preload("res://game/items/item_service.gd")
const SAVE_VERSION: int = 1

var current_location: String = "pier"
var entry: String = "default"
var flags: Dictionary = {}
var party_positions: Array[Vector3] = []
var inventory := Items.starter_pack()

func to_payload() -> Dictionary:
	var positions: Array = []
	for position: Vector3 in party_positions:
		positions.append([position.x, position.y, position.z])
	return {
		"version": SAVE_VERSION,
		"current_location": current_location,
		"entry": entry,
		"flags": flags.duplicate(),
		"party_positions": positions,
		"inventory": inventory.duplicate(true),
	}

func restore(payload: Dictionary) -> bool:
	var location_value: Variant = payload.get("current_location")
	var entry_value: Variant = payload.get("entry")
	var saved_flags: Variant = payload.get("flags")
	var positions: Variant = payload.get("party_positions")
	if typeof(location_value) != TYPE_STRING or location_value.is_empty():
		return false
	if typeof(entry_value) != TYPE_STRING or entry_value.is_empty():
		return false
	if typeof(saved_flags) != TYPE_DICTIONARY or typeof(positions) != TYPE_ARRAY:
		return false
	for key: Variant in saved_flags:
		if typeof(key) != TYPE_STRING or typeof(saved_flags[key]) != TYPE_BOOL:
			return false

	var restored_positions: Array[Vector3] = []
	for point: Variant in positions:
		if typeof(point) != TYPE_ARRAY or point.size() != 3:
			return false
		for coordinate: Variant in point:
			if typeof(coordinate) != TYPE_FLOAT and typeof(coordinate) != TYPE_INT:
				return false
		var position := Vector3(point[0], point[1], point[2])
		if not position.is_finite():
			return false
		restored_positions.append(position)

	var bag: Variant = payload.get("inventory", Items.starter_pack())
	if not Items.validate(bag):
		return false
	inventory = bag.duplicate(true)
	current_location = location_value
	entry = entry_value
	flags = saved_flags.duplicate()
	party_positions = restored_positions
	return true
