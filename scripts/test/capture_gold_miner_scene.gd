extends SceneTree

func _init() -> void:
	var f = FileAccess.open("res://parse_check.txt", FileAccess.WRITE)
	var scn = load("res://scenes/minigames/gold_miner/gold_miner.tscn") as PackedScene
	if not scn:
		if f:
			f.store_line("FAILED_TO_LOAD")
			f.close()
		quit(1)
		return
	if f:
		f.store_line("SCENE_LOAD_OK")
	var inst = scn.instantiate()
	root.add_child(inst)

	if inst.has_method("_spawn_default_minerals"):
		inst._spawn_default_minerals()

	var spawns = inst._get_spawn_positions()
	for i in range(4):
		var p_origin = Vector3(spawns[i].x, 9.9, 0.0)
		var h = inst.create_default_hook_data(p_origin)
		h["angle"] = [-0.4, 0.3, -0.2, 0.5][i]
		h["length"] = 4.0
		inst.hooks[i + 1] = h

	inst._update_hook_visuals()

	for i in range(12):
		await process_frame

	var vp = root.get_viewport()
	var tex = vp.get_texture()
	if tex:
		var img = tex.get_image()
		if img:
			img.save_png("res://screenshot_gold_miner.png")

	inst.queue_free()
	if f:
		f.store_line("SCENE_INSTANTIATE_AND_RUN_OK")
		f.close()
	quit(0)

