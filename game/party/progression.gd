extends RefCounted

const XP_PER_LEVEL: int = 3
const MAX_XP: int = 10000

var _bag: Dictionary

static func initial_state() -> Dictionary:
	return {"xp": {"hero": 0, "companion": 0}, "awards": {}}

static func validate(value: Variant) -> bool:
	if value is not Dictionary or value.size() != 2:
		return false
	var experience: Variant = value.get("xp")
	var awards: Variant = value.get("awards")
	if experience is not Dictionary or awards is not Dictionary:
		return false
	if not experience.has("hero") or not experience.has("companion"):
		return false
	for member_id: Variant in experience:
		if member_id is not String or member_id.strip_edges().is_empty():
			return false
		var amount: Variant = experience[member_id]
		if amount is not int and amount is not float:
			return false
		if not is_finite(float(amount)) or amount < 0 or amount > MAX_XP:
			return false
		if amount != int(amount):
			return false
	for source_id: Variant in awards:
		if source_id is not String or source_id.strip_edges().is_empty() or awards[source_id] is not bool or not awards[source_id]:
			return false
	return true

func _init(bag: Dictionary) -> void:
	_bag = bag

func award(source_id: String, member_ids: Array[String], amount: int) -> bool:
	if source_id.strip_edges().is_empty() or member_ids.is_empty() or amount <= 0 or amount > MAX_XP:
		return false
	if not validate(_bag) or _bag["awards"].has(source_id):
		return false
	var recipients: Dictionary = {}
	for member_id: String in member_ids:
		if not _bag["xp"].has(member_id) or recipients.has(member_id):
			return false
		recipients[member_id] = mini(xp(member_id) + amount, MAX_XP)
	_bag["xp"].merge(recipients, true)
	_bag["awards"][source_id] = true
	return true

func level(member_id: String) -> int:
	var amount := xp(member_id)
	if amount < 0:
		return 0
	return 1 + floori(float(amount) / XP_PER_LEVEL)

func xp(member_id: String) -> int:
	var experience: Variant = _bag.get("xp")
	if experience is not Dictionary or not experience.has(member_id):
		return -1
	var amount: Variant = experience[member_id]
	if amount is not int and amount is not float:
		return -1
	if not is_finite(float(amount)) or amount < 0 or amount > MAX_XP or amount != int(amount):
		return -1
	return int(amount)
