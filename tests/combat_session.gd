extends SceneTree

const CombatSession = preload("res://game/combat/combat_session.gd")

func _initialize() -> void:
	var session := CombatSession.new()
	session.active_members.assign(["leader", "guard"])
	session.paused = true
	if not session.issue_order(["leader", "guard"], {"kind": "attack"}):
		_fail("Valid group orders should be queued while paused")
		return
	if session.orders.size() != 2 or session.strike("leader", 3) or session.retreat() or session.enemy_health != 6:
		_fail("Paused combat must retain its orders without resolving actions")
		return
	if session.issue_order(["leader", "inactive"], {"kind": "hold"}) or session.orders["leader"]["kind"] != "attack":
		_fail("An invalid group order should leave every order unchanged")
		return
	var move := {"kind": "move", "destination": Vector3.ZERO}
	if not session.issue_order(["guard"], move):
		_fail("An individual can replace their current order")
		return
	move["kind"] = "attack"
	if session.orders["guard"]["kind"] != "move" or session.orders["leader"]["kind"] != "attack":
		_fail("Changing the input must not alter queued orders")
		return
	if session.issue_order([], {"kind": "hold"}) or session.issue_order(["leader"], {"kind": "invalid"}):
		_fail("Empty and unknown orders must be rejected")
		return
	session.paused = false
	if session.strike("guard", 1) or session.strike("inactive", 1) or session.strike("leader", 0):
		_fail("Only attacking active members should deal positive damage")
		return
	if not session.strike("leader", 3) or session.enemy_health != 3 or session.outcome != "active":
		_fail("Nonlethal damage should leave the encounter active")
		return
	if not session.strike("leader", 5) or session.enemy_health != 0 or session.outcome != "victory":
		_fail("Defeating the enemy should close the encounter")
		return
	if session.retreat() or session.strike("leader", 1) or session.issue_order(["leader"], {"kind": "attack"}):
		_fail("A closed encounter should reject subsequent orders and actions")
		return
	session = CombatSession.new()
	session.active_members.assign(["leader"])
	if not session.issue_order(["leader"], {"kind": "retreat"}) or not session.retreat():
		_fail("Retreat must resolve from an active encounter")
		return
	if session.outcome != "retreated" or session.enemy_health != 6:
		_fail("Retreat should close the encounter without enemy damage")
		return
	print("PASS: group and individual orders, tactical pause, victory and retreat")
	quit()

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
