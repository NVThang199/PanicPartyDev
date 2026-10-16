extends SceneTree

func _init():
	var bomb_scene = load("res://scenes/minigames/bomb.tscn")
	var b = bomb_scene.instantiate()
	var m = b.get_node("Model")
	print("Bomb model scale: ", m.scale)
	for c in m.get_children():
		print("  child: ", c.name, " type: ", c.get_class())
		if c is MeshInstance3D and c.mesh:
			print("    AABB: ", c.mesh.get_aabb())
	quit()
