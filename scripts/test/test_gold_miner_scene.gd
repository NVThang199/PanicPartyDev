@tool
extends SceneTree

func _init() -> void:
	print("--- Running Gold Miner Scene 3D Tests ---")

	var gm_script = load("res://scripts/minigames/gold_miner/gold_miner.gd")
	assert(gm_script != null, "GoldMiner script must exist")

	var scene = load("res://scenes/minigames/gold_miner/gold_miner.tscn")
	assert(scene != null, "Scene gold_miner.tscn must exist and load")
	assert(scene is PackedScene, "gold_miner.tscn must be a PackedScene")

	var instance = scene.instantiate()
	assert(instance != null, "Must instantiate gold_miner.tscn")
	assert(instance.get_script() == gm_script, "Root node script must be gold_miner.gd")

	# Check Camera3D
	var camera = instance.get_node_or_null("Camera3D") as Camera3D
	assert(camera != null, "Camera3D must exist")
	assert(camera.current == true, "Camera3D must have current = true")

	# Check Lighting & Env
	assert(instance.get_node_or_null("DirectionalLight3D") != null, "DirectionalLight3D must exist")
	assert(instance.get_node_or_null("WorldEnvironment") != null, "WorldEnvironment must exist")

	# Check Containers & Collision
	var mining_area = instance.get_node_or_null("MiningArea")
	assert(mining_area != null, "MiningArea must exist")
	var top_ground = mining_area.get_node_or_null("TopGround")
	assert(top_ground != null, "TopGround must exist")
	assert(top_ground is StaticBody3D, "TopGround must be a StaticBody3D for player collision")
	assert(top_ground.get_node_or_null("CollisionShape3D") != null, "TopGround must have CollisionShape3D")
	assert(instance.get_node_or_null("MineralsContainer") != null, "MineralsContainer must exist")
	assert(instance.get_node_or_null("HooksContainer") != null, "HooksContainer must exist")

	# Check RigPositions
	var rig_positions = instance.get_node_or_null("RigPositions")
	assert(rig_positions != null, "RigPositions must exist")
	assert(rig_positions.get_child_count() >= 4, "Must have at least 4 rig positions")

	# Check spawn positions function
	var spawns = instance._get_spawn_positions()
	assert(spawns.size() == 4, "Should return 4 spawn positions")
	assert(spawns[0] == Vector3(-9, 0, -6), "Slot 0 mismatch: %s" % spawns[0])
	assert(spawns[1] == Vector3(-3, 0, -6), "Slot 1 mismatch: %s" % spawns[1])
	assert(spawns[2] == Vector3(3, 0, -6), "Slot 2 mismatch: %s" % spawns[2])
	assert(spawns[3] == Vector3(9, 0, -6), "Slot 3 mismatch: %s" % spawns[3])

	# Check UI components
	assert(instance.get_node_or_null("UI/MatchTimerLabel") != null, "MatchTimerLabel must exist in UI")
	assert(instance.get_node_or_null("UI/PlayerScoresPanel") != null, "PlayerScoresPanel must exist in UI")
	assert(instance.get_node_or_null("UI/WinnerBanner") != null, "WinnerBanner must exist in UI")

	# Check Tutorial Data
	var tut = instance._get_tutorial_data()
	assert(tut.has("title") and tut.has("rules") and tut.has("controls"), "Tutorial data must contain required keys")

	instance.free()
	print("TEST_GOLD_MINER_SCENE_PASS")
	quit(0)
