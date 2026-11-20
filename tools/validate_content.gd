extends SceneTree

const ROUTES_FILE := "res://data/world/dnieper.json"

func _initialize() -> void:
	var scene := load("res://scenes/bootstrap.tscn") as PackedScene
	if scene == null:
		_fail("Bootstrap scene is missing")
		return
	var scene_state := scene.get_state()
	var locations: Dictionary = {}
	for index in scene_state.get_node_property_count(0):
		if scene_state.get_node_property_name(0, index) == &"locations":
			locations = scene_state.get_node_property_value(0, index)
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROUTES_FILE))
	var valid := data is Dictionary and data.get("routes") is Dictionary
	if valid:
		valid = _validate_routes(data["routes"], locations)
	if not valid:
		_fail("World data has an invalid route or missing entry marker")
		return
	print("PASS: route data and destination markers")
	quit()

func _validate_routes(routes: Dictionary, locations: Dictionary) -> bool:
	for id: Variant in routes:
		var route: Variant = routes[id]
		if not id is String or not route is Dictionary:
			return false
		if not locations.has(route.get("from")) or not locations.has(route.get("to")):
			return false
		var place: Node = locations[route["to"]].instantiate()
		var marker := place.get_node_or_null(NodePath(route.get("entry", ""))) as Marker3D
		var has_marker := marker != null
		place.free()
		if not has_marker:
			return false
	return not routes.is_empty()

func _fail(reason: String) -> void:
	push_error(reason)
	quit(1)
