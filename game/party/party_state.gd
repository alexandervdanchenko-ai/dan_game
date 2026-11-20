extends RefCounted

const HERO: String = "hero"
const FIELD: String = "field"
const VOEVODA: String = "voevoda"

var _roles: Dictionary[String, String] = {
	HERO: FIELD,
	"companion": FIELD,
}
var _selected: Array[String] = [HERO, "companion"]

func selected_ids() -> Array[String]:
	return _selected.duplicate()

func select(member_id: String, additive: bool = false) -> bool:
	if _roles.get(member_id) != FIELD:
		return false
	if not additive:
		_selected.clear()
	if not _selected.has(member_id):
		_selected.append(member_id)
	return true

func select_all() -> void:
	_selected = active_ids()

func assign_role(member_id: String, role_id: String) -> bool:
	if not _roles.has(member_id) or (role_id != FIELD and role_id != VOEVODA):
		return false
	if member_id == HERO and role_id == VOEVODA:
		return false
	_roles[member_id] = role_id
	if role_id == VOEVODA:
		_selected.erase(member_id)
		if _selected.is_empty():
			_selected.append(HERO)
	return true

func active_ids() -> Array[String]:
	var members: Array[String] = []
	for member_id in _roles:
		if _roles[member_id] == FIELD:
			members.append(member_id)
	return members
