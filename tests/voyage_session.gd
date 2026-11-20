extends SceneTree

var _failures: int = 0

func _initialize() -> void:
	var script: GDScript = load("res://game/travel/voyage_session.gd")
	if script == null:
		_require(false, "VoyageSession must exist")
	else:
		_test_navigation(script)
		_test_boarding(script)
		_test_other_outcomes(script)
	if _failures == 0:
		print("PASS: river navigation, boarding crew and single-award outcomes")
	quit(1 if _failures > 0 else 0)

func _test_navigation(script: GDScript) -> void:
	var voyage: RefCounted = script.new(Array(["hero"], TYPE_STRING, "", null), 2)
	_require(voyage.position == Vector2(2, 4), "The boat starts at the landing")
	_require(not voyage.steer(Vector2i.ONE), "Diagonal commands do not cross cells")
	_require(voyage.steer(Vector2i.RIGHT) and voyage.steer(Vector2i.RIGHT), "The deep channel is navigable")
	_require(not voyage.steer(Vector2i.UP), "The marked shallow at (4,3) blocks passage")
	_require(voyage.position == Vector2(4, 4) and voyage.heading == Vector2.RIGHT,
		"A rejected move leaves position and heading intact")
	for index in 6:
		_require(voyage.steer(Vector2i.RIGHT), "The boat advances along the deep channel")
	_require(not voyage.steer(Vector2i.RIGHT), "The boat cannot leave the map")

func _test_boarding(script: GDScript) -> void:
	var crew: Array[String] = ["hero", "companion", "hero"]
	var voyage: RefCounted = script.new(crew, 2)
	_require(not voyage.start_boarding("river_patrol"), "Initial separation prevents boarding")
	_require(not voyage.resolve_encounter("victory"), "Victory requires boarding")
	for index in 4:
		voyage.steer(Vector2i.RIGHT)
	_require(not voyage.start_boarding("unknown"), "Unknown encounters cannot be boarded")
	_require(voyage.start_boarding("river_patrol"), "Nearby patrol can be boarded")
	_require(not voyage.start_boarding("river_patrol"), "Boarding cannot be entered twice")
	_require(voyage.boarding_crew() == ["hero", "companion"], "Each active fighter boards once")
	_require(not voyage.steer(Vector2i.RIGHT), "Steering suspends during boarding")
	_require(not voyage.resolve_encounter("negotiated"), "Boarding uses combat outcomes")
	_require(voyage.resolve_encounter("victory"), "Victory resolves boarding")
	_require(not voyage.resolve_encounter("victory") and voyage.cargo == 3, "Cargo award is issued once")
	_require(voyage.outcome == "victory", "Outcome remains victory")

func _test_other_outcomes(script: GDScript) -> void:
	var crew: Array[String] = ["hero"]
	var negotiation: RefCounted = script.new(crew, 2)
	_require(not negotiation.resolve_encounter("negotiated"), "Negotiation requires proximity")
	for index in 4:
		negotiation.steer(Vector2i.RIGHT)
	_require(negotiation.resolve_encounter("negotiated") and negotiation.cargo == 2,
		"Negotiation preserves cargo")
	var retreat: RefCounted = script.new(crew, 2)
	_require(retreat.resolve_encounter("retreated") and not retreat.steer(Vector2i.RIGHT),
		"Retreat ends the encounter")
	var passing: RefCounted = script.new(crew, 2)
	_require(not passing.resolve_encounter("passed"), "Passing requires reaching the far bank")
	for index in 8:
		passing.steer(Vector2i.RIGHT)
	_require(passing.resolve_encounter("passed") and passing.cargo == 2,
		"Reaching the far bank preserves cargo")

func _require(condition: bool, failure: String) -> void:
	if not condition:
		_failures += 1
		push_error(failure)
