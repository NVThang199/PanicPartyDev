@tool
extends SceneTree

func _init() -> void:
	var scn = load("res://scenes/minigames/gold_miner/gold_miner.tscn") as PackedScene
	if not scn:
		quit(1)
	var inst = scn.instantiate()
	root.add_child(inst)

	var f = FileAccess.open("res://lights_info.txt", FileAccess.WRITE)
	_dump_lights(inst, f)
	f.close()
	inst.free()
	quit(0)

func _dump_lights(node: Node, f: FileAccess) -> void:
	if node is Light3D:
		var l = node as Light3D
		f.store_line("LIGHT: " + l.name + " (" + l.get_class() + ") visible=" + str(l.visible) + " energy=" + str(l.light_energy) + " shadow=" + str(l.shadow_enabled) + " pos=" + str(l.global_position))
	for c in node.get_children():
		_dump_lights(c, f)
