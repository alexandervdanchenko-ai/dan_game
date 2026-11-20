extends RefCounted

const SETTLEMENT_ID := "landing"
const PROJECT_IDS: Array[String] = ["dock", "workshop", "guard"]
const BUILD_COST := 4
const BUILD_DAYS := 2
const MAX_DAY := 1_000_000

var _bag: Dictionary

func _init(bag: Dictionary) -> void:
	_bag = bag

static func initial_state() -> Dictionary:
	return {
		"owned": false,
		"treasury": 0,
		"day": 0,
		"reeve": "",
		"construction": {},
		"buildings": {},
	}

static func validate(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var owned: Variant = value.get("owned")
	var treasury: Variant = value.get("treasury")
	var day: Variant = value.get("day")
	var reeve: Variant = value.get("reeve")
	var construction: Variant = value.get("construction")
	var buildings: Variant = value.get("buildings")
	if not owned is bool or not _is_whole_number(treasury) or not _is_whole_number(day):
		return false
	if not reeve is String or reeve not in ["", "companion"]:
		return false
	if not construction is Dictionary or not buildings is Dictionary:
		return false
	if not owned:
		return treasury == 0 and reeve == "" and construction.is_empty() and buildings.is_empty()
	for id: Variant in buildings:
		if id not in PROJECT_IDS or not buildings[id] is bool or not buildings[id]:
			return false
	if construction.is_empty():
		return true
	var project_id: Variant = construction.get("project_id")
	var finish_day: Variant = construction.get("finish_day")
	return project_id in PROJECT_IDS and not buildings.has(project_id) \
		and _is_whole_number(finish_day) and finish_day > day and finish_day <= day + BUILD_DAYS

static func _is_whole_number(value: Variant) -> bool:
	return (value is int or value is float) and value >= 0 and value <= MAX_DAY and value == floorf(value)

func claim() -> bool:
	if _bag["owned"]:
		return false
	_bag["owned"] = true
	_bag["treasury"] = BUILD_COST
	return true

func assign_reeve(member_id: String) -> bool:
	if not _bag["owned"] or member_id not in ["", "companion"]:
		return false
	_bag["reeve"] = member_id
	return true

func queue_building(settlement_id: String, project_id: String) -> bool:
	if settlement_id != SETTLEMENT_ID or project_id not in PROJECT_IDS or not _bag["owned"]:
		return false
	if not _bag["construction"].is_empty() or _bag["buildings"].has(project_id):
		return false
	var day := int(_bag["day"])
	var treasury := int(_bag["treasury"])
	if treasury < BUILD_COST or day > MAX_DAY - BUILD_DAYS:
		return false
	_bag["treasury"] = treasury - BUILD_COST
	_bag["construction"] = {"project_id": project_id, "finish_day": day + BUILD_DAYS}
	return true

func advance_day(day: int) -> void:
	var previous_day := int(_bag["day"])
	if day <= previous_day or day > MAX_DAY:
		return
	_bag["day"] = day
	if not _bag["owned"]:
		return
	_bag["treasury"] = mini(MAX_DAY, int(_bag["treasury"]) + day - previous_day)
	var construction: Dictionary = _bag["construction"]
	if not construction.is_empty() and day >= int(construction["finish_day"]):
		_bag["buildings"][construction["project_id"]] = true
		_bag["construction"] = {}
