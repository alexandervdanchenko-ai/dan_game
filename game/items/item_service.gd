extends RefCounted

const SMITH := "kanev_smith"
const MAX_CONDITION := 5
var inventory: Dictionary

func _init(bag: Dictionary) -> void:
	inventory = bag

static func starter_pack() -> Dictionary:
	return {"iron": 2, "shield": {"owner": "hero", "condition": 3, "rim": false}}

static func validate(bag: Variant) -> bool:
	if not bag is Dictionary or not _whole_number(bag.get("iron"), 999):
		return false
	var shield: Variant = bag.get("shield")
	return shield is Dictionary and shield.get("owner") == "hero" \
		and _whole_number(shield.get("condition"), MAX_CONDITION) and shield.get("rim") is bool

static func _whole_number(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and value >= 0 and value <= maximum and value == floorf(value)

func stats(item_id: String) -> Dictionary:
	if item_id != "shield":
		return {}
	var shield: Dictionary = inventory[item_id]
	return {"defense": 1 + (2 if shield["rim"] else 0), "weight": 2 + (1 if shield["rim"] else 0)}

func apply_upgrade(item_id: String, recipe_id: String, smith_id: String) -> bool:
	if item_id != "shield" or recipe_id != "rim" or smith_id != SMITH or inventory["iron"] < 1:
		return false
	var shield: Dictionary = inventory[item_id]
	if shield["rim"]:
		return false
	shield["rim"] = true
	inventory["iron"] -= 1
	return true

func repair(item_id: String, smith_id: String) -> bool:
	if item_id != "shield" or smith_id != SMITH or inventory["iron"] < 1:
		return false
	var shield: Dictionary = inventory[item_id]
	if shield["condition"] == MAX_CONDITION:
		return false
	shield["condition"] = MAX_CONDITION
	inventory["iron"] -= 1
	return true

func absorb_wear() -> void:
	var shield: Dictionary = inventory["shield"]
	shield["condition"] = maxi(0, int(shield["condition"]) - 1)
