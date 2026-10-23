extends SceneTree

func _init() -> void:
	var f = FileAccess.open("res://debug_hook_out.txt", FileAccess.WRITE)
	f.store_line("START")
	f.flush()
	var scn = load("res://scenes/minigames/gold_miner/gold_miner.tscn") as PackedScene
	f.store_line("SCN LOADED: " + str(scn != null))
	f.flush()
	var inst = scn.instantiate()
	f.store_line("INSTANTIATED: " + str(inst != null))
	f.flush()
	root.add_child(inst)
	f.store_line("ADDED TO ROOT")
	f.flush()
	var spawns = inst._get_spawn_positions()
	f.store_line("Spawns: " + str(spawns))
	f.flush()
	for i in range(4):
		var p_origin = Vector3(spawns[i].x, 9.9, 0.0)
		var h = inst.create_default_hook_data(p_origin)
		h["angle"] = [-0.4, 0.2, -0.1, 0.3][i]
		h["length"] = [4.0, 8.0, 12.0, 5.0][i]
		inst.hooks[i + 1] = h
	f.store_line("HOOKS POPULATED: " + str(inst.hooks.size()))
	f.flush()
	inst._update_hook_visuals(0.0)
	f.store_line("UPDATE HOOK VISUALS DONE")
	f.flush()
	var hc = inst.get_node_or_null("HooksContainer")
	f.store_line("HooksContainer child count: " + str(hc.get_child_count() if hc else "null"))
	if hc:
		for c in hc.get_children():
			f.store_line("  child: " + c.name + " class: " + c.get_class() + " pos: " + str(c.global_position) + " vis: " + str(c.visible))
			if c is Node3D and c.get_child_count() > 0:
				for gc in c.get_children():
					f.store_line("    subchild: " + gc.name + " class: " + gc.get_class() + " pos: " + str(gc.global_position if gc is Node3D else ""))
	f.close()
	quit(0)
