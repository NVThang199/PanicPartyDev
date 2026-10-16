extends SceneTree

func _init():
	var bomb_scene = load("res://scenes/minigames/bomb.tscn")
	var b = bomb_scene.instantiate()
	var m = b.get_node("Model")
	var sm = m.get_node("smokebomb") as MeshInstance3D
	print("smokebomb transform: ", sm.transform)
	print("smokebomb mesh AABB size: ", sm.mesh.get_aabb().size)
	print("Actual visual size with Model scale (3,3,3): ", sm.mesh.get_aabb().size * m.scale * sm.scale)
	quit()
