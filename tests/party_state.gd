extends SceneTree

func _initialize() -> void:
	var script: GDScript = load("res://game/party/party_state.gd")
	if script == null:
		_fail("Missing party state")
		return
	var party: RefCounted = script.new()
	if party.active_ids() != ["hero", "companion"] or party.selected_ids() != party.active_ids():
		_fail("Both field members should initially be selected")
		return
	if not party.select("companion") or party.selected_ids() != ["companion"]:
		_fail("A single selection should replace the group")
		return
	if not party.select("hero", true) or party.selected_ids() != ["companion", "hero"]:
		_fail("An additive selection should retain the previous member")
		return
	if not party.select("companion") or not party.assign_role("companion", "voevoda"):
		_fail("Companion must be eligible to become voevoda")
		return
	if party.active_ids() != ["hero"] or party.selected_ids() != ["hero"] or party.select("companion"):
		_fail("Voevoda cannot be selected as a field member")
		return
	if party.assign_role("hero", "voevoda") or party.assign_role("companion", "unknown"):
		_fail("Invalid role assignments should be rejected")
		return
	if not party.assign_role("companion", "field"):
		_fail("Companion should be able to return to the field")
		return
	party.select_all()
	var copy: Array[String] = party.selected_ids()
	copy.clear()
	if party.selected_ids() != ["hero", "companion"]:
		_fail("Selection should not be mutable through a returned array")
		return
	print("PASS: party selection and field roles")
	quit()

func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
