extends RefCounted

const ROUTE_FILE: String = "res://data/world/dnieper.json"

var _routes: Dictionary = {}

func _init() -> void:
	var file := FileAccess.open(ROUTE_FILE, FileAccess.READ)
	if file == null:
		push_error("Could not open world routes: " + ROUTE_FILE)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary or parsed.get("routes") is not Dictionary:
		push_error("World route file must contain a routes dictionary")
		return
	_routes = parsed["routes"]

func get_route(route_id: String) -> Dictionary:
	var route: Variant = _routes.get(route_id)
	if route is not Dictionary:
		return {}
	return route.duplicate(true)

func can_travel(route_id: String, state: RefCounted) -> bool:
	var route: Dictionary = get_route(route_id)
	if state == null or route.is_empty() or route.get("from") != state.current_location:
		return false
	var required_flag: String = route.get("requires_flag", "")
	return required_flag.is_empty() or state.flags.get(required_flag, false) == true
