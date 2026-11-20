extends SceneTree

const Validator = preload("res://tools/validate_content.gd")
const PIER = preload("res://scenes/regions/dnieper/pier.tscn")
const LANDING = preload("res://scenes/regions/dnieper/landing.tscn")

func _initialize() -> void:
	var locations := {"pier": PIER, "landing": LANDING}
	var outgoing := {"from": "pier", "to": "landing", "entry": "landing_pier", "requires_flag": "clue"}
	var returning := {"from": "landing", "to": "pier", "entry": "pier_landing"}
	var routes := {"outgoing": outgoing, "returning": returning}
	if not _expect(routes, locations, ""):
		return
	if not _expect({"returning": returning}, locations, "unreachable from pier"):
		return
	if not _expect({"outgoing": outgoing}, locations, "no return path"):
		return
	routes["duplicate"] = outgoing.duplicate()
	if not _expect(routes, locations, "duplicates route"):
		return
	routes.erase("duplicate")
	outgoing["requires_flag"] = "cleu"
	if not _expect(routes, locations, "unknown required flag"):
		return
	outgoing["requires_flag"] = false
	if not _expect(routes, locations, "invalid required flag"):
		return
	outgoing.erase("requires_flag")
	outgoing["entry"] = []
	if not _expect(routes, locations, "invalid entry"):
		return
	outgoing["entry"] = "nowhere"
	if not _expect(routes, locations, "missing entry marker"):
		return
	routes["outgoing"] = 42
	if not _expect(routes, locations, "must be an object"):
		return
	print("PASS: route coverage, schema, gates and entry validation")
	quit()

func _expect(routes: Dictionary, locations: Dictionary, expected: String) -> bool:
	var error: String = Validator.route_error(routes, locations)
	if (expected.is_empty() and error.is_empty()) or (not expected.is_empty() and error.contains(expected)):
		return true
	push_error("Expected '%s', got '%s'" % [expected, error])
	quit(1)
	return false
