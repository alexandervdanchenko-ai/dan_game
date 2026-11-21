extends RefCounted

const PATROL_ID := "river_patrol"
const CHANNEL := Rect2i(0, 0, 11, 9)
const SHOAL := Rect2i(4, 3, 3, 1)
const BOARDING_DISTANCE := 2

var position: Vector2 = Vector2(2, 4)
var heading: Vector2 = Vector2.RIGHT
var opponent_position: Vector2 = Vector2(8, 4)
var cargo: int
var has_pilot: bool = false
var outcome: String = ""

var _crew: Array[String] = []
var _boarding: bool = false

func _init(active_ids: Array[String], initial_cargo: int = 0, pilot: bool = false) -> void:
	has_pilot = pilot
	for member_id in active_ids:
		if not member_id.is_empty() and not member_id in _crew:
			_crew.append(member_id)
	cargo = maxi(0, initial_cargo)

func steer(direction: Vector2i) -> bool:
	if not outcome.is_empty() or _boarding or absi(direction.x) + absi(direction.y) != 1:
		return false
	var next := Vector2i(position) + direction
	if not CHANNEL.has_point(next) or (is_shallow(next) and not has_pilot):
		return false
	position = Vector2(next)
	heading = Vector2(direction)
	return true

func is_shallow(cell: Vector2i) -> bool:
	return SHOAL.has_point(cell)

func can_board() -> bool:
	return outcome.is_empty() and not _boarding and not _crew.is_empty() and _within_hailing_distance()

func start_boarding(encounter_id: String) -> bool:
	if encounter_id != PATROL_ID or not can_board():
		return false
	_boarding = true
	return true

func boarding_crew() -> Array[String]:
	if not _boarding:
		return []
	return _crew.duplicate()

func resolve_encounter(outcome_id: String) -> bool:
	if not outcome.is_empty():
		return false
	match outcome_id:
		"victory", "defeat":
			if not _boarding:
				return false
		"negotiated":
			if _boarding or not _within_hailing_distance():
				return false
		"passed":
			if _boarding or position.x != CHANNEL.end.x - 1:
				return false
		"retreated":
			pass
		_:
			return false
	if outcome_id == "victory":
		cargo += 1
	outcome = outcome_id
	_boarding = false
	return true

func _within_hailing_distance() -> bool:
	var separation := (opponent_position - position).abs()
	return separation.x + separation.y <= BOARDING_DISTANCE
