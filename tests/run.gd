extends SceneTree

func _initialize() -> void:
	var script: GDScript = load("res://game/pier_routes.gd")
	if script == null:
		push_error("Missing pier route planner")
		quit(1)
		return
	var planner: RefCounted = script.new()
	var path: PackedVector2Array = planner.route(Vector2i(-4, 0), Vector2i(4, 0))
	if path.is_empty() or path[-1] != Vector2(4, 0):
		push_error("Route must reach the destination")
		quit(1)
		return
	for cell: Vector2 in path:
		if absf(cell.x) <= 1 and absf(cell.y) <= 1:
			push_error("Route crosses the storehouse")
			quit(1)
			return
	var blocked: PackedVector2Array = planner.route(Vector2i(-4, 0), Vector2i.ZERO)
	if not blocked.is_empty():
		push_error("Blocked destinations must be rejected")
		quit(1)
		return
	print("PASS: pier routes")
	quit()
