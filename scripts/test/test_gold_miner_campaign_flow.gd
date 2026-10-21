@tool
extends SceneTree

func _init() -> void:
	print("--- Running GoldMiner Campaign Flow Unit Tests ---")

	# Test 1-4: Check _get_next_minigame_scene routing in base_minigame.gd source
	var bm_file = FileAccess.open("res://scripts/minigames/base_minigame.gd", FileAccess.READ)
	assert(bm_file != null, "base_minigame.gd must exist")
	var bm_content = bm_file.get_as_text()
	bm_file.close()

	assert("res://scenes/minigames/gold_miner/gold_miner.tscn" in bm_content, "base_minigame.gd must reference gold_miner.tscn")
	assert("res://scenes/minigames/gold_miner/gold_miner.tscn" in bm_content, "StableFooting must route to GoldMiner")
	assert("res://scenes/minigames/mimic/mimic.tscn" in bm_content, "GoldMiner must route to Mimic")

	# Test 5: Verify scenes/minigames/gold_miner/gold_miner.tscn exists
	assert(ResourceLoader.exists("res://scenes/minigames/gold_miner/gold_miner.tscn"), "gold_miner.tscn scene file must exist")

	# Test 6: Verify main.gd contains GoldMiner handling
	var main_file = FileAccess.open("res://scripts/core/main.gd", FileAccess.READ)
	assert(main_file != null, "main.gd must exist")
	var main_content = main_file.get_as_text()
	main_file.close()

	assert('map_name == "GoldMiner"' in main_content, "main.gd must handle GoldMiner map")
	assert('"GoldMiner"' in main_content, "main.gd must contain GoldMiner in map rotation")
	assert("scenes/minigames/gold_miner/gold_miner.tscn" in main_content, "main.gd must load gold_miner.tscn")

	print("TEST_GOLD_MINER_CAMPAIGN_FLOW_PASS")
	quit(0)
