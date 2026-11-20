extends RefCounted

var grid := AStarGrid2D.new()

func _init() -> void:
	grid.region = Rect2i(-8, -5, 17, 11)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	grid.fill_solid_region(Rect2i(-1, -1, 3, 3))

func route(from: Vector2i, to: Vector2i) -> PackedVector2Array:
	if not grid.region.has_point(from) or not grid.region.has_point(to):
		return PackedVector2Array()
	if grid.is_point_solid(from) or grid.is_point_solid(to):
		return PackedVector2Array()
	return grid.get_point_path(from, to)
