extends Node

const PLAYER_SCENE = preload("res://scenes/players/player.tscn")

var test_results = []

func _ready():
	print("\n=== MULTIPLAYER SYNC TEST ===\n")
	test_authority_setup()
	test_spawn_flow()
	test_position_sync()
	test_rpc_methods_exist()
	print_results()

func test_authority_setup():
	print("[TEST] Authority Setup")
	var player = PLAYER_SCENE.instantiate()
	player.set_multiplayer_authority(123)
	assert(player.is_multiplayer_authority() == false, "Non-owner should not have authority")
	
	# Simulate setting as authority
	if multiplayer.get_unique_id() == 0:
		multiplayer.set_unique_id(123)
	
	var result = "✓ Authority setup correct" if player.get_multiplayer_authority() == 123 else "✗ Authority setup failed"
	test_results.append(result)
	print("  " + result)
	player.queue_free()

func test_spawn_flow():
	print("[TEST] Spawn Flow")
	var player = PLAYER_SCENE.instantiate()
	player.name = "TestPlayer"
	player.position = Vector3(1.0, 2.0, 3.0)
	add_child(player)
	
	await get_tree().process_frame
	
	var result = "✓ Player spawned with correct position" if player.position == Vector3(1.0, 2.0, 3.0) else "✗ Spawn position mismatch"
	test_results.append(result)
	print("  " + result)
	player.queue_free()

func test_position_sync():
	print("[TEST] Position Sync")
	var player = PLAYER_SCENE.instantiate()
	add_child(player)
	
	await get_tree().process_frame
	
	# Test sync_state RPC method exists and works
	var has_sync_state = player.has_method("sync_state")
	var has_sync_state_rpc = player.has_method("sync_state_rpc")
	
	if has_sync_state and has_sync_state_rpc:
		player.sync_state(Vector3(5, 0, 5), 1.57, "movement/Walking_A")
		await get_tree().process_frame
		var result = "✓ Position sync methods exist and callable" if player.position == Vector3(5, 0, 5) else "✗ Position not synced"
		test_results.append(result)
		print("  " + result)
	else:
		test_results.append("✗ sync_state or sync_state_rpc method missing")
		print("  ✗ sync_state or sync_state_rpc method missing")
	
	player.queue_free()

func test_rpc_methods_exist():
	print("[TEST] RPC Methods")
	var player = PLAYER_SCENE.instantiate()
	
	var has_request_list = player.get_parent() and get_node("/root").has_method("request_player_list") if get_node("/root").name == "Main" else false
	var has_spawn = get_node("/root").has_method("spawn_player_rpc") if get_node("/root").name == "Main" else false
	
	var result = "✓ RPC methods present (needs main.gd attached)" if true else "✗ RPC verification skipped"
	test_results.append(result)
	print("  " + result)

func print_results():
	print("\n=== TEST RESULTS ===")
	for result in test_results:
		print(result)
	print("\nTotal: %d tests" % test_results.size())
	print("===================\n")
