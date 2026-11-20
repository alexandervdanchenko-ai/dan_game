extends RefCounted

const ORDER_KINDS: Array[String] = ["move", "attack", "hold", "retreat"]

var paused: bool = false
var active_members: Array[String] = []
var orders: Dictionary = {}
var outcome: String = "active"
var enemy_health: int = 6

func issue_order(member_ids: Array[String], order: Dictionary) -> bool:
	if outcome != "active" or member_ids.is_empty() or order.get("kind") not in ORDER_KINDS:
		return false
	for member_id in member_ids:
		if member_id not in active_members:
			return false
	for member_id in member_ids:
		orders[member_id] = order.duplicate(true)
	return true

func strike(member_id: String, damage: int) -> bool:
	if paused or outcome != "active" or damage <= 0 or member_id not in active_members:
		return false
	var order: Dictionary = orders.get(member_id, {})
	if order.get("kind") != "attack":
		return false
	enemy_health = maxi(0, enemy_health - damage)
	if enemy_health == 0:
		outcome = "victory"
	return true

func retreat() -> bool:
	if paused or outcome != "active":
		return false
	outcome = "retreated"
	return true
