extends SceneTree

class TravelState extends RefCounted:
	var current_location: String = "pier"
	var flags: Dictionary = {}

func _initialize() -> void:
	var graph_script: GDScript = load("res://game/world/world_graph.gd")
	if graph_script == null:
		_fail("The world graph script could not be loaded")
		return
	var graph: RefCounted = graph_script.new()
	var state := TravelState.new()

	if not graph.can_travel("pier_to_landing", state):
		_fail("The landing must be reachable from the pier")
		return
	if graph.can_travel("landing_to_pier", state) or graph.can_travel("unknown_route", state):
		_fail("Routes from other locations and unknown IDs must be rejected")
		return
	if graph.can_travel("pier_to_hideout", state):
		_fail("The hideout route must require the clue")
		return
	state.flags["clue"] = false
	if graph.can_travel("pier_to_hideout", state):
		_fail("A false clue flag must not enable the hideout route")
		return
	state.flags["clue"] = true
	if not graph.can_travel("pier_to_hideout", state):
		_fail("Finding the clue must enable the hideout route")
		return

	var route: Dictionary = graph.get_route("pier_to_hideout")
	if route.get("to") != "hideout" or route.get("entry") != "hideout_pier":
		_fail("The hideout route must identify the destination and entry")
		return
	route["to"] = "landing"
	if graph.get_route("pier_to_hideout").get("to") != "hideout":
		_fail("Editing a returned route must not modify the graph")
		return

	state.current_location = "landing"
	if not graph.can_travel("landing_to_pier", state):
		_fail("The landing must have a return route")
		return
	state.current_location = "hideout"
	if not graph.can_travel("hideout_to_pier", state):
		_fail("The hideout must have a return route")
		return
	print("PASS: world graph directions, entries, and clue gating")
	quit()

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
