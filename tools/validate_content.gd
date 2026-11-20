extends SceneTree

const ROUTES_FILE := "res://data/world/dnieper.json"
# Add a flag here when gameplay gains a new way to unlock a route.
const ROUTE_FLAGS := ["clue"]
const START_LOCATION := "pier"

func _initialize() -> void:
	var scene := load("res://scenes/bootstrap.tscn") as PackedScene
	if scene == null:
		_fail("Bootstrap scene is missing")
		return
	var scene_state := scene.get_state()
	var locations: Variant = null
	var root_script: Script
	for index in scene_state.get_node_property_count(0):
		match scene_state.get_node_property_name(0, index):
			&"locations":
				locations = scene_state.get_node_property_value(0, index)
			&"script":
				root_script = scene_state.get_node_property_value(0, index) as Script
	if root_script == null or not root_script.can_instantiate():
		_fail("Bootstrap script could not be loaded")
		return
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(ROUTES_FILE)) != OK:
		_fail("Could not parse %s: %s" % [ROUTES_FILE, parser.get_error_message()])
		return
	var data: Variant = parser.data
	if not data is Dictionary:
		_fail("World data must be an object")
		return
	var error := route_error(data.get("routes"), locations)
	if not error.is_empty():
		_fail(error)
		return
	print("PASS: route data, destination markers, and round-trip coverage")
	quit()

static func route_error(routes: Variant, locations: Variant) -> String:
	if not routes is Dictionary or routes.is_empty():
		return "World data must contain at least one route"
	if not locations is Dictionary or not locations.has(START_LOCATION):
		return "Locations must contain the starting pier"

	var outgoing: Dictionary = {}
	var incoming: Dictionary = {}
	for location: Variant in locations:
		if not location is String or location.is_empty() or not locations[location] is PackedScene:
			return "Invalid location record: %s" % str(location)
		outgoing[location] = []
		incoming[location] = []

	var unique_links: Dictionary = {}
	for id: Variant in routes:
		var route: Variant = routes[id]
		if not id is String or id.is_empty() or not route is Dictionary:
			return "Route '%s' must be an object with a nonempty ID" % str(id)
		var origin: Variant = route.get("from")
		var destination: Variant = route.get("to")
		var entry: Variant = route.get("entry")
		var flag: Variant = route.get("requires_flag", "")
		if not origin is String or not locations.has(origin):
			return "Route '%s' has an invalid origin" % id
		if not destination is String or not locations.has(destination):
			return "Route '%s' has an invalid destination" % id
		if not entry is String or entry.is_empty():
			return "Route '%s' has an invalid entry" % id
		if not flag is String or (flag.is_empty() and route.has("requires_flag")):
			return "Route '%s' has an invalid required flag" % id
		if not flag.is_empty() and flag not in ROUTE_FLAGS:
			return "Route '%s' has an unknown required flag '%s'" % [id, flag]
		var link := [origin, destination, entry, flag]
		if unique_links.has(link):
			return "Route '%s' duplicates route '%s'" % [id, unique_links[link]]
		unique_links[link] = id
		var place: Node = locations[destination].instantiate()
		if place == null:
			return "Route '%s' could not load location '%s'" % [id, destination]
		var has_marker := place.get_node_or_null(NodePath(entry)) is Marker3D
		place.free()
		if not has_marker:
			return "Route '%s' is missing entry marker '%s' in '%s'" % [id, entry, destination]
		outgoing[origin].append(destination)
		incoming[destination].append(origin)

	var from_pier := _reachable(outgoing)
	var to_pier := _reachable(incoming)
	for location: String in locations:
		if not from_pier.has(location):
			return "Location '%s' is unreachable from pier" % location
		if not to_pier.has(location):
			return "Location '%s' has no return path to pier" % location
	return ""

static func _reachable(adjacency: Dictionary) -> Dictionary:
	var seen := {START_LOCATION: true}
	var pending: Array[String] = [START_LOCATION]
	while not pending.is_empty():
		var origin: String = pending.pop_back()
		for destination: String in adjacency[origin]:
			if seen.has(destination):
				continue
			seen[destination] = true
			pending.append(destination)
	return seen

func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
