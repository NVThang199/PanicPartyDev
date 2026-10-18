extends SceneTree

func _init():
	call_deferred("_run_test")

func _run_test():
	var arena = load("res://scenes/minigames/hot_bomb.tscn").instantiate()
	root.add_child(arena)

	for i in range(5):
		await process_frame

	var bomb = load("res://scenes/minigames/bomb.tscn").instantiate()
	arena.add_child(bomb)

	var dummy_target = Node3D.new()
	dummy_target.name = "1"
	dummy_target.add_to_group("player")
	arena.add_child(dummy_target)

	bomb.target_player = dummy_target
	var nav: NavigationAgent3D = bomb.get_node("NavigationAgent3D")

	var test_cases = [
		{
			"name": "Obstacle1 (Crates)",
			"bomb_pos": Vector3(-5.0, 0.5, 0.0),
			"target_pos": Vector3(-5.0, 0.5, -10.0),
			"obs_x": -5.0
		},
		{
			"name": "Obstacle_Barrels",
			"bomb_pos": Vector3(7.5, 0.5, -4.0),
			"target_pos": Vector3(7.5, 0.5, -12.0),
			"obs_x": 7.5
		},
		{
			"name": "Obstacle_Tent",
			"bomb_pos": Vector3(-7.74, 0.5, 4.0),
			"target_pos": Vector3(-7.74, 0.5, 12.0),
			"obs_x": -7.74
		},
		{
			"name": "Obstacle2 (Resources/Cart)",
			"bomb_pos": Vector3(5.0, 0.5, 0.0),
			"target_pos": Vector3(5.0, 0.5, 10.0),
			"obs_x": 5.0
		}
	]

	for tc in test_cases:
		bomb.global_position = tc.bomb_pos
		dummy_target.global_position = tc.target_pos
		nav.target_position = tc.target_pos
		await process_frame
		await process_frame

		var next_pos = nav.get_next_path_position()
		var deviation = abs(next_pos.x - tc.obs_x)
		print("[TEST %s] Next pos: %s, Deviation: %.3f" % [tc.name, next_pos, deviation])
		assert(deviation > 0.4, "Navigation failed for %s: path did not route around obstacle!" % tc.name)

	print("[TEST] ALL 4 OBSTACLE PATHFINDING CHECKS PASSED!")
	quit(0)
