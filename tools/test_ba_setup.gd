extends SceneTree

func _init():
	var scene = load("res://scenes/players/player.tscn")
	var p = scene.instantiate()
	root.add_child(p)

	var skel: Skeleton3D = p.get_node("Model/Rig_Medium/Skeleton3D")
	var ba = BoneAttachment3D.new()
	ba.name = "RightHandAttachment"
	ba.bone_name = "handslot.r"
	skel.add_child(ba)

	print("BoneAttachment3D configured: bone_name=%s, parent=%s" % [ba.bone_name, ba.get_parent().name])

	quit()
