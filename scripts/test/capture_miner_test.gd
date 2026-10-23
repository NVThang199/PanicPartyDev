extends Node

func _ready() -> void:
	var fbx_path = "res://assets/animations/KayKit_Character_Animations_1.1/Animations/fbx/Rig_Medium/Rig_Medium_Tools.fbx"
	var scn = load(fbx_path) as PackedScene
	var fa = FileAccess.open("res://anim_check.txt", FileAccess.WRITE)
	if scn:
		var inst = scn.instantiate()
		var ap: AnimationPlayer = inst.get_node_or_null("AnimationPlayer")
		if ap:
			fa.store_line("Anims in Rig_Medium_Tools: " + str(ap.get_animation_list()))
		inst.free()
	else:
		fa.store_line("Cannot load FBX: " + fbx_path)
	fa.close()

	var real_scn = load("res://scenes/minigames/gold_miner/gold_miner.tscn") as PackedScene
	assert(scn != null)
	var inst = scn.instantiate()
	add_child(inst)

	if inst.has_method("_spawn_default_minerals"):
		inst._spawn_default_minerals()

	var spawns = inst._get_spawn_positions()
	# Tạo 4 hook ở các trạng thái khác nhau để kiểm tra visual:
	# Player 0: Móc vung sang trái
	# Player 1: Móc phóng xuống giữa đường
	# Player 2: Móc gắp vàng đang kéo lên
	# Player 3: Móc vung sang phải
	var angles = [-0.45, 0.1, -0.25, 0.4]
	var lengths = [3.0, 12.0, 7.5, 4.0]
	var states = [inst.HookState.SWINGING, inst.HookState.EXTENDING, inst.HookState.RETRACTING, inst.HookState.SWINGING]

	var player_scene = load("res://scenes/players/player.tscn") as PackedScene
	for i in range(4):
		var p_origin = Vector3(spawns[i].x, 9.9, 0.0)
		var h = inst.create_default_hook_data(p_origin)
		h["angle"] = angles[i]
		h["length"] = lengths[i]
		h["state"] = states[i]
		inst.hooks[i + 1] = h

		if player_scene:
			var p = player_scene.instantiate()
			p.position = spawns[i]
			inst.add_child(p)
			inst.players[i + 1] = p
			if states[i] == inst.HookState.RETRACTING:
				p.play_anim("tools/Working_C")
			else:
				p.play_anim("general/Idle_A")

	inst._update_hook_visuals(0.0)

	for i in range(10):
		await get_tree().process_frame

	var vp = get_viewport()
	if vp:
		var tex = vp.get_texture()
		if tex:
			var img = tex.get_image()
			if img:
				img.save_png("res://screenshot_gold_miner.png")
				print("SAVED_HOOK_AND_WINCH_SCREENSHOT")

	inst.queue_free()
	get_tree().quit(0)
