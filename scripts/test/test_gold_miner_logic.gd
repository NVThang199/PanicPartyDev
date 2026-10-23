@tool
extends SceneTree

func _init() -> void:
	print("--- Running GoldMiner Logic Unit Tests ---")
	var gm_script = load("res://scripts/minigames/gold_miner/gold_miner.gd")
	assert(gm_script != null, "GoldMiner script must exist")
	var gm = gm_script.new()

	# Test 1: Khởi tạo default hook data
	var h = gm.create_default_hook_data(Vector3(0, 5, 0))
	assert(h.state == gm_script.HookState.SWINGING, "Hook must start SWINGING")
	assert(h.origin == Vector3(0, 5, 0), "Hook origin must match input")
	assert(h.angle == 0.0, "Hook angle should start at 0")
	assert(is_equal_approx(h.length, gm_script.BASE_SWING_LENGTH), "Hook length should start at BASE_SWING_LENGTH")
	assert(h.target_item_id == -1, "Target item id should be -1")
	assert(h.direction == Vector3(0, -1.0, 0), "Direction should default to Vector3(0, -1.0, 0)")

	# Test 2: First-hit sorting
	# Vật thể 1 tại (0, 0, 0) cách origin (0, 5, 0) 5m
	# Vật thể 2 tại (0, 3, 0) cách origin (0, 5, 0) 2m
	var items = {
		1: {"pos": Vector3(0, 0, 0), "radius": 0.8, "active": true, "grabbable": true},
		2: {"pos": Vector3(0, 3, 0), "radius": 0.8, "active": true, "grabbable": true}
	}
	var hit_id = gm.find_first_hit(Vector3(0, 5, 0), Vector3(0, -1, 0), 6.0, items)
	assert(hit_id == 2, "Must hit item 2 first because it is closest along the ray")

	# Test 2.1: Item ngoài tầm với (length < distance)
	var hit_short = gm.find_first_hit(Vector3(0, 5, 0), Vector3(0, -1, 0), 1.0, items)
	assert(hit_short == -1, "Should not hit if hook length is too short")

	# Test 2.2: Item inactive
	var items_disabled = {
		1: {"pos": Vector3(0, 3, 0), "radius": 0.8, "active": false, "grabbable": true}
	}
	var hit_disabled = gm.find_first_hit(Vector3(0, 5, 0), Vector3(0, -1, 0), 6.0, items_disabled)
	assert(hit_disabled == -1, "Should ignore inactive items")

	# Test 2.2b: Item obstacle/non-grabbable vẫn va chạm để hook dội về
	var items_obs = {
		1: {"pos": Vector3(0, 3, 0), "radius": 0.8, "active": true, "grabbable": false}
	}
	var hit_obs = gm.find_first_hit(Vector3(0, 5, 0), Vector3(0, -1, 0), 6.0, items_obs)
	assert(hit_obs == 1, "Should detect obstacle hit for recoil")

	# Test 2.3: Hỗ trợ GoldMinerItem node thực tế
	var item_script = load("res://scripts/minigames/gold_miner/gold_miner_item.gd")
	var node_item = item_script.new()
	node_item.setup_item(99, item_script.Type.GOLD_LARGE, Vector3(0, 2, 0))
	var items_with_node = {
		99: node_item
	}
	var hit_node = gm.find_first_hit(Vector3(0, 5, 0), Vector3(0, -1, 0), 4.0, items_with_node)
	assert(hit_node == 99, "Must hit GoldMinerItem instance")
	node_item.free()

	# Test 3: Công thức tính tốc độ thu dây
	var speed_diamond = gm.calculate_retract_speed(0.5)
	var speed_rock = gm.calculate_retract_speed(5.0)
	assert(speed_diamond > speed_rock, "Diamond must retract faster than rock")
	assert(is_equal_approx(speed_diamond, 12.0 / 0.5), "Speed diamond formula check")
	assert(is_equal_approx(speed_rock, 12.0 / 5.0), "Speed rock formula check")

	# Test 4: Va chạm môi trường (Floor & Rubble)
	# Origin tại y=10, bắn thẳng xuống (0, -1, 0), sàn tại y=-13 => khoảng cách = 23m
	var env_dist_hit = gm._check_environment_hit_distance(Vector3(0, 10, 0), Vector3(0, -1, 0), 25.0)
	assert(is_equal_approx(env_dist_hit, 23.0), "Must hit MineFloor at 23m distance")

	var env_dist_miss = gm._check_environment_hit_distance(Vector3(0, 10, 0), Vector3(0, -1, 0), 10.0)
	assert(env_dist_miss < 0.0, "Should not hit floor if length is less than distance")

	gm.free()
	print("TEST_GOLD_MINER_LOGIC_PASS")
	quit(0)
