extends SceneTree

const Items = preload("res://game/items/item_service.gd")

func _initialize() -> void:
	var bag := Items.starter_pack()
	var shop := Items.new(bag)
	assert(not shop.apply_upgrade("shield", "rim", "stranger"))
	assert(bag["iron"] == 2)
	assert(shop.apply_upgrade("shield", "rim", "kanev_smith"))
	assert(shop.stats("shield") == {"defense": 3, "weight": 3})
	assert(not shop.apply_upgrade("shield", "rim", "kanev_smith"))
	assert(bag["iron"] == 1)
	assert(shop.repair("shield", "kanev_smith"))
	assert(bag["shield"]["condition"] == 5 and bag["iron"] == 0)
	print("PASS: upgrade, rejection, cost and repair")
	quit()
