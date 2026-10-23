extends SceneTree

func _init():
    var scn = load("res://assets/terrains/dungeon/chest_gold.fbx")
    var inst = scn.instantiate()
    var mi = inst.get_node_or_null("chest_gold") as MeshInstance3D
    if mi and mi.mesh:
        print("Chest mesh AABB: ", mi.mesh.get_aabb())
    inst.free()
    quit(0)