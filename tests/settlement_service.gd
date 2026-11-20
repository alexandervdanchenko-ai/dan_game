extends SceneTree

const Settlement = preload("res://game/settlements/settlement_service.gd")

func _initialize() -> void:
	var bag := Settlement.initial_state()
	var service := Settlement.new(bag)
	if not _check(Settlement.validate(bag), "fresh holdings validate"):
		return
	if not _check(not service.queue_building("landing", "dock"), "holdings require ownership"):
		return
	service.advance_day(3)
	if not _check(bag["treasury"] == 0 and bag["day"] == 3, "unowned days do not generate revenue"):
		return
	if not _check(service.claim() and not service.claim() and bag["treasury"] == 4, "claim grants starting funds once"):
		return
	if not _check(not service.assign_reeve("hero") and service.assign_reeve("companion"), "only the companion can serve as reeve"):
		return
	if not _check(service.assign_reeve("") and bag["reeve"] == "", "the reeve can return to service"):
		return
	if not _check(not service.queue_building("elsewhere", "dock") and not service.queue_building("landing", "unknown"), "unknown settlement and project are rejected"):
		return
	if not _check(service.queue_building("landing", "dock") and bag["treasury"] == 0, "queue spends funds once"):
		return
	if not _check(not service.queue_building("landing", "dock") and not service.queue_building("landing", "guard"), "construction occupies the only work slot"):
		return
	service.advance_day(4)
	service.advance_day(4)
	service.advance_day(2)
	if not _check(bag["treasury"] == 1 and not bag["buildings"].has("dock"), "repeated or past day has no effect"):
		return
	var restored: Variant = JSON.parse_string(JSON.stringify(bag))
	if not _check(Settlement.validate(restored), "ongoing project survives JSON round trip"):
		return
	var restored_service := Settlement.new(restored)
	restored_service.advance_day(5)
	if not _check(restored["construction"].is_empty() and restored["buildings"].get("dock") == true, "dock opens after the second day"):
		return
	if not _check(not restored_service.queue_building("landing", "workshop") and restored["treasury"] == 2, "short treasury leaves state intact"):
		return
	restored_service.advance_day(8)
	if not _check(restored["treasury"] == 5 and not restored_service.queue_building("landing", "dock"), "completed buildings cannot be bought again"):
		return
	if not _check(restored_service.queue_building("landing", "guard") and restored["treasury"] == 1, "other projects unlock as the treasury recovers"):
		return
	restored["construction"]["finish_day"] = 8
	if not _check(not Settlement.validate(restored), "an overdue pending project is invalid"):
		return
	print("PASS: settlement ownership, reeve, construction, days and persistence")
	quit()

func _check(condition: bool, message: String) -> bool:
	if not condition:
		push_error(message)
		quit(1)
	return condition
