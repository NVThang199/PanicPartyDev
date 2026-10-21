@tool
extends SceneTree

## Test tích hợp toàn diện cho Gold Miner 3D (Headless Integration Test)
## Kiểm tra toàn bộ vòng đời: Scene, Players, Minerals, Hook Drop, Hit Detection, Retract & Score, Timeout, Tournament Ranking & Next Scene Transition

func _init() -> void:
	print("--- Running Gold Miner Full Integration Tests ---")

	# 1. Load và instantiate scene
	var scene = load("res://scenes/minigames/gold_miner/gold_miner.tscn")
	assert(scene != null, "Scene gold_miner.tscn must exist and load")
	var gm = scene.instantiate()
	assert(gm != null, "Must instantiate gold_miner.tscn")
	assert(gm is GoldMiner, "Instance must be GoldMiner")

	# 2. Giả lập 2 player tham gia
	gm.player_states = {
		1: {"name": "Host", "alive": true, "score": 0, "death_timer": 0.0},
		2: {"name": "Client", "alive": true, "score": 0, "death_timer": 0.0}
	}
	gm.synced_peers = {1: true, 2: true}

	# Khởi tạo game state & hooks
	gm._on_minigame_ready()
	assert(gm.match_timer == 60.0, "Match timer should start at 60.0")

	var spawns = gm._get_spawn_positions()
	assert(spawns.size() >= 2, "Must have spawn positions for 2 players")
	gm.hooks[1] = gm.create_default_hook_data(spawns[0])
	gm.hooks[2] = gm.create_default_hook_data(spawns[1])
	gm.gold_scores[1] = 0
	gm.gold_scores[2] = 0

	# 3. Giả lập sinh khoáng sản mẫu (Vàng Lớn: value=500, weight=4.0)
	var item_script = load("res://scripts/minigames/gold_miner/gold_miner_item.gd")
	assert(item_script != null, "GoldMinerItem script must exist")

	var gold_large = item_script.new()
	# Đặt thẳng phía trước hướng hook của Player 1: origin + (0, 0, 1) * 8m
	var p1_origin = spawns[0]
	var item_pos = p1_origin + Vector3(0, 0, 8.0)
	gold_large.setup_item(101, item_script.Type.GOLD_LARGE, item_pos)
	gm.minerals[101] = gold_large
	assert(gold_large.get_item_value() == 500, "GOLD_LARGE value should be 500")
	assert(gold_large.get_item_weight() == 4.0, "GOLD_LARGE weight should be 4.0")

	# 4. Giả lập Player 1 click thả móc
	var h1 = gm.hooks[1]
	assert(h1["state"] == GoldMiner.HookState.SWINGING, "Hook 1 must start SWINGING")
	h1["angle"] = 0.0
	h1["direction"] = Vector3(0, 0, 1.0) # Hướng thẳng trục Z tới quặng vàng
	h1["state"] = GoldMiner.HookState.EXTENDING
	assert(h1["state"] == GoldMiner.HookState.EXTENDING, "Hook 1 state should transition to EXTENDING")

	# 5. Giả lập server tick hook bay trúng quặng Vàng Lớn
	# BASE_EXTEND_SPEED = 14.0 m/s. Sau delta = 0.6s, length = 8.4m > 8.0m (trúng item_pos)
	gm._tick_hook_server(1, 0.6)
	assert(h1["state"] == GoldMiner.HookState.RETRACTING, "Hook 1 must transition to RETRACTING upon hitting item")
	assert(h1["target_item_id"] == 101, "Target item ID must be 101")
	assert(gold_large.is_hooked == true, "Gold large must be marked as hooked")

	# 6. Giả lập hook kéo về gốc (RETRACTING -> SWINGING) và cộng điểm
	# Tốc độ kéo: calculate_retract_speed(4.0) = 12.0 / 4.0 = 3.0 m/s
	# Chiều dài hiện tại ~8.4m, sau 3.0s kéo về 0
	gm._tick_hook_server(1, 3.5)
	assert(h1["state"] == GoldMiner.HookState.SWINGING, "Hook 1 must return to SWINGING after full retract")
	assert(h1["target_item_id"] == -1, "Target item id must reset to -1")
	assert(gm.gold_scores[1] == 500, "Player 1 must receive 500 points for collecting GOLD_LARGE")
	assert(101 not in gm.minerals, "Collected mineral 101 must be removed from minerals dict")

	# 7. Giả lập hết giờ (timer = 0) -> Kiểm tra kết thúc và tính điểm tournament
	# Player 1 có 500 điểm vàng, Player 2 có 0 điểm vàng
	gm.match_timer = 0.0
	gm.end_game_timeout()
	assert(gm.state == BaseMinigame.GameState.ENDED, "Game state must be ENDED after timeout")

	# Kiểm tra elimination_order: [Player 2 (0đ), Player 1 (500đ)]
	assert(gm.elimination_order.size() == 2, "Elimination order must contain 2 players")
	assert(gm.elimination_order[0] == 2, "Player 2 with lowest score should be rank 1 (first in order)")
	assert(gm.elimination_order[1] == 1, "Player 1 with highest score should be rank 2 (last in order, winner)")

	# Kiểm tra _calculate_round_scores: Người rank cao nhất (cuối cùng) nhận 1000 điểm tournament
	var round_scores = gm.calculate_round_scores()
	assert(round_scores[1] == 1000, "Winner (Player 1) must receive 1000 tournament points")
	assert(round_scores[2] == 0, "Loser (Player 2) must receive 0 tournament points")

	# 8. Kiểm tra chuyển cảnh sang minigame tiếp theo (Campaign flow)
	gm.name = "GoldMiner"
	var next_scene = gm.get_next_minigame_scene()
	assert(next_scene == "res://scenes/minigames/mimic/mimic.tscn", "Next scene after GoldMiner must be mimic.tscn")

	# Dọn dẹp
	gm.free()

	print("TEST_GOLD_MINER_FULL_PASS")
	quit(0)
