extends SceneTree

func _initialize() -> void:
	var script: GDScript = load("res://game/party/progression.gd")
	if script == null:
		_fail("Progression script must load")
		return
	var initial: Dictionary = script.initial_state()
	var progress: RefCounted = script.new(initial)
	var group: Array[String] = ["hero", "companion"]
	var unknown: Array[String] = ["hero", "stranger"]
	var repeated: Array[String] = ["hero", "hero"]
	if progress.level("hero") != 1 or progress.xp("companion") != 0:
		_fail("Both members must start at level one")
		return
	if progress.award("battle", unknown, 3) or progress.award("battle", repeated, 3) or progress.award("", group, 3) or progress.award("battle", group, 0):
		_fail("Invalid awards cannot affect the party")
		return
	if not progress.award("battle", group, 3) or progress.level("hero") != 2 or progress.level("companion") != 2:
		_fail("Every active award recipient must level up after three XP")
		return
	if progress.award("battle", group, 3) or progress.xp("hero") != 3:
		_fail("An earned reward cannot be applied twice")
		return
	if progress.award("overflow", group, 10001) or not progress.award("finish", group, 10000) or progress.xp("hero") != 10000:
		_fail("XP has a hard upper bound")
		return
	if not script.validate(JSON.parse_string(JSON.stringify(initial))):
		_fail("JSON round trips must preserve valid progression")
		return
	var invalid := initial.duplicate(true)
	invalid["xp"]["hero"] = 1.5
	if script.validate(invalid):
		_fail("Fractional experience cannot be loaded")
		return
	print("PASS: progression, level thresholds, validation and one-shot rewards")
	quit()

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
