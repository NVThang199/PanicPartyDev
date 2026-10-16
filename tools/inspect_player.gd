extends SceneTree

func _init():
	var scene = load("res://scenes/players/player.tscn")
	var p = scene.instantiate()
	print_nodes(p, "")
	quit()

func print_nodes(n: Node, indent: String):
	print(indent + n.name + " (" + n.get_class() + ")")
	if n is Skeleton3D:
		print(indent + "  [Skeleton3D] bone_count: ", n.get_bone_count())
		for i in range(n.get_bone_count()):
			var bname = n.get_bone_name(i)
			if "hand" in bname.to_lower() or "arm" in bname.to_lower() or "wrist" in bname.to_lower() or "item" in bname.to_lower() or "attach" in bname.to_lower() or "prop" in bname.to_lower():
				print(indent + "    bone %d: %s" % [i, bname])
	for c in n.get_children():
		print_nodes(c, indent + "  ")
