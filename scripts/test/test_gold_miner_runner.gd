extends Node

func _ready() -> void:
	print("--- Running Gold Miner Comprehensive Suite (Scene Context) ---")

	# 1. Test Scene
	var scene = load("res://scenes/minigames/gold_miner/gold_miner.tscn")
	assert(scene != null, "Scene gold_miner.tscn must exist and load")
	var instance = scene.instantiate()
	assert(instance != null, "Must instantiate gold_miner.tscn")

	var top_ground = instance.get_node_or_null("MiningArea/TopGround")
	assert(top_ground is StaticBody3D, "TopGround must be StaticBody3D")
	assert(top_ground.get_node_or_null("CollisionShape3D") != null, "TopGround must have CollisionShape3D")

	# Check MineFloor, Rubble2_Body, Rubble3_Body
	var mine_floor = instance.get_node_or_null("MiningArea/MineFloor")
	assert(mine_floor is StaticBody3D, "MineFloor must be StaticBody3D")
	var rubble2_body = instance.get_node_or_null("MiningArea/Rubble2_Body")
	assert(rubble2_body is StaticBody3D, "Rubble2_Body must be StaticBody3D")
	assert(rubble2_body.get_node_or_null("CollisionShape3D") != null, "Rubble2_Body must have CollisionShape3D")
	var rubble3_body = instance.get_node_or_null("MiningArea/Rubble3_Body")
	assert(rubble3_body is StaticBody3D, "Rubble3_Body must be StaticBody3D")
	assert(rubble3_body.get_node_or_null("CollisionShape3D") != null, "Rubble3_Body must have CollisionShape3D")

	# Check Winches 3D
	for i in range(4):
		var winch_node = instance.get_node_or_null("MiningArea/Winch%d" % i)
		assert(winch_node != null, "Winch%d must exist in MiningArea" % i)

	# Check Working_C animation in Rig_Medium_Tools
	var fbx_path = "res://assets/animations/KayKit_Character_Animations_1.1/Animations/fbx/Rig_Medium/Rig_Medium_Tools.fbx"
	var scn_tools = load(fbx_path) as PackedScene
	var fa = FileAccess.open("res://anim_check.txt", FileAccess.WRITE)
	if scn_tools:
		var inst_tools = scn_tools.instantiate()
		var ap: AnimationPlayer = inst_tools.get_node_or_null("AnimationPlayer")
		if ap:
			fa.store_line("Has Working_C: " + str(ap.has_animation("Working_C")))
			fa.store_line("Anims: " + str(ap.get_animation_list()))
		inst_tools.free()
	fa.close()

	var hook_vis = instance._get_or_create_hook_visual(1)
	assert(hook_vis != null and hook_vis.get("head") != null, "Hook visual head must exist")
	assert(hook_vis.get("cable") != null, "Hook visual cable must exist")

	# Check Camera3D
	var camera = instance.get_node_or_null("Camera3D") as Camera3D
	assert(camera != null and camera.current, "Camera3D must exist with current=true")

	# Check Working_C animation in Player
	var player_scene = load("res://scenes/players/player.tscn") as PackedScene
	assert(player_scene != null, "player.tscn must exist")
	var p_test = player_scene.instantiate()
	add_child(p_test)
	var p_ap = p_test.get_node_or_null("AnimationPlayer") as AnimationPlayer
	assert(p_ap != null, "Player must have AnimationPlayer")
	assert(p_ap.has_animation("tools/Working_C"), "Player must have tools/Working_C animation")
	p_test.play_anim("tools/Working_C")
	assert(p_test.current_anim == "tools/Working_C", "Player should play tools/Working_C")
	p_test.play_anim("general/Idle_A")
	assert(p_test.current_anim == "general/Idle_A", "Player should return to general/Idle_A")
	p_test.queue_free()

	# Check Hook Data & Logic
	var spawns = instance._get_spawn_positions()
	assert(spawns.size() == 4, "Should have 4 spawn positions")
	var h0 = instance.create_default_hook_data(spawns[0])
	assert(h0["state"] == instance.HookState.SWINGING, "Hook starts SWINGING")
	assert(is_equal_approx(h0["length"], instance.BASE_SWING_LENGTH), "Hook length starts at BASE_SWING_LENGTH")
	assert(h0["direction"] == Vector3(0, -1.0, 0), "Hook direction is Vector3(0, -1.0, 0)")

	# Check freeze players
	instance._freeze_all_players(true)

	# Check first-hit sorting
	var items = {
		1: {"pos": Vector3(0, 0, 0), "radius": 0.8, "active": true, "grabbable": true},
		2: {"pos": Vector3(0, 3, 0), "radius": 0.8, "active": true, "grabbable": true}
	}
	var hit_id = instance.find_first_hit(Vector3(0, 5, 0), Vector3(0, -1, 0), 6.0, items)
	assert(hit_id == 2, "Must hit item 2 first")

	# Check retract speed
	var speed_diamond = instance.calculate_retract_speed(0.5)
	var speed_rock = instance.calculate_retract_speed(5.0)
	assert(speed_diamond > speed_rock, "Diamond faster than rock")

	# Check next minigame scene
	assert(instance.get_next_minigame_scene() == "res://scenes/minigames/mimic/mimic.tscn", "Next scene is mimic.tscn")

	# Check tutorial texture load direct from file
	var real_path = ProjectSettings.globalize_path("res://assets/ui/tutorial/gold_miner.png")
	var img = Image.load_from_file(real_path)
	assert(img != null and not img.is_empty(), "Image must load from file")
	var tex = ImageTexture.create_from_image(img)
	assert(tex != null, "ImageTexture must be created")
	print("Direct Image load succeeded: size = ", img.get_size())

	# Check FBX model instancing for all 5 item types
	var item_scene = load("res://scenes/minigames/gold_miner/gold_miner_item.tscn")
	assert(item_scene != null, "gold_miner_item.tscn must exist")
	var item_script = load("res://scripts/minigames/gold_miner/gold_miner_item.gd")
	for t in [item_script.Type.GOLD_LARGE, item_script.Type.GOLD_MEDIUM, item_script.Type.GOLD_SMALL, item_script.Type.DIAMOND, item_script.Type.ROCK_LARGE, item_script.Type.ROCK_SMALL, item_script.Type.OBSTACLE]:
		var itm = item_scene.instantiate()
		itm.setup_item(100 + t, t, Vector3(0, 0, 0))
		assert(itm.model_node != null, "Model FBX node should be instantiated for type: %d" % t)
		itm.free()

	# Add instance into tree to test child structure
	add_child(instance)
	if instance.has_method("_spawn_default_minerals"):
		instance._spawn_default_minerals()

	var hook_spawns = instance._get_spawn_positions()
	var test_angles = [-0.45, 0.15, -0.2, 0.4]
	var test_lengths = [3.5, 9.0, 13.5, 5.0]
	for i in range(4):
		var origin = Vector3(hook_spawns[i].x, 9.9, 0.0)
		var h = instance.create_default_hook_data(origin)
		h["angle"] = test_angles[i]
		h["length"] = test_lengths[i]
		instance.hooks[i + 1] = h

	for i in range(10):
		instance._update_hook_visuals(0.0)
		await get_tree().process_frame

	var vp = get_viewport()
	if vp:
		var vp_tex = vp.get_texture()
		if vp_tex:
			var shot = vp_tex.get_image()
			if shot:
				shot.save_png("res://screenshot_gold_miner.png")

	instance.queue_free()
	var f = FileAccess.open("res://test_runner_result.txt", FileAccess.WRITE)
	if f:
		f.store_string("ALL_GOLD_MINER_TESTS_PASS\n")
		f.close()
	print("ALL_GOLD_MINER_TESTS_PASS")
	get_tree().quit(0)
