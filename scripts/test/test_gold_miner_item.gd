@tool
extends SceneTree

func _init() -> void:
	print("--- Running GoldMinerItem Unit Tests ---")
	var item_script = load("res://scripts/minigames/gold_miner/gold_miner_item.gd")
	assert(item_script != null, "GoldMinerItem script must exist")

	# Test 1: Instantiation via .new() and GOLD_LARGE setup
	var item = item_script.new()
	item.setup_item(1, item_script.Type.GOLD_LARGE, Vector3(0, -5, 0))
	assert(item.item_id == 1, "item_id should be 1")
	assert(item.get_item_value() == 500, "Large gold should be 500 pts")
	assert(item.get_item_weight() >= 3.0, "Large gold should be heavy")
	assert(item.is_grabbable() == true, "Gold should be grabbable")
	assert(item.position == Vector3(0, -5, 0), "Position should match")

	# Test 2: OBSTACLE setup
	item.setup_item(2, item_script.Type.OBSTACLE, Vector3(2, -5, 0))
	assert(item.get_item_value() == 0, "Obstacle should be 0 pts")
	assert(item.is_grabbable() == false, "Obstacle should not be grabbable")

	# Test 3: DIAMOND setup
	item.setup_item(3, item_script.Type.DIAMOND, Vector3(1, -2, 0))
	assert(item.get_item_value() == 800, "Diamond should be 800 pts")
	assert(item.get_item_weight() == 0.5, "Diamond should be light (weight 0.5)")
	assert(item.is_grabbable() == true, "Diamond should be grabbable")

	# Test 4: ROCK_LARGE and ROCK_SMALL
	item.setup_item(4, item_script.Type.ROCK_LARGE, Vector3(3, -4, 0))
	assert(item.get_item_value() == 50, "Rock large should be 50 pts")
	assert(item.get_item_weight() == 5.0, "Rock large should be 5.0")
	item.setup_item(5, item_script.Type.ROCK_SMALL, Vector3(4, -4, 0))
	assert(item.get_item_value() == 25, "Rock small should be 25 pts")
	assert(item.get_item_weight() == 2.5, "Rock small should be 2.5")
	item.free()

	# Test 5: Scene instantiation and visual/collision update
	var scene = load("res://scenes/minigames/gold_miner/gold_miner_item.tscn")
	assert(scene != null, "Scene gold_miner_item.tscn must exist")
	var scene_item = scene.instantiate()
	assert(scene_item is Area3D, "Scene item must be Area3D")
	scene_item.setup_item(10, item_script.Type.GOLD_SMALL, Vector3(-1, -3, 0))
	assert(scene_item.get_item_value() == 100, "Small gold should be 100 pts")
	var col = scene_item.get_node_or_null("CollisionShape3D") as CollisionShape3D
	assert(col != null and col.shape is SphereShape3D, "Collision shape must be SphereShape3D")
	assert(abs((col.shape as SphereShape3D).radius - 0.4) < 0.01, "Collision radius should match config (0.4)")
	scene_item.free()

	print("TEST_GOLD_MINER_ITEM_PASS")
	quit(0)
