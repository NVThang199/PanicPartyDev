extends SceneTree

func _init():
	var p_scene = load("res://scenes/players/player.tscn")
	var p = p_scene.instantiate()
	root.add_child(p)

	var b_scene = load("res://scenes/minigames/bomb.tscn")
	var b = b_scene.instantiate()
	root.add_child(b)

	var skel: Skeleton3D = p.get_node("Model/Rig_Medium/Skeleton3D")
	var ba = BoneAttachment3D.new()
	ba.name = "RightHandAttachment"
	ba.bone_name = "handslot.r"
	skel.add_child(ba)

	var anim = p.get_node("AnimationPlayer")
	var hb_lib = load("res://assets/animations/hot_bomb_animations.res")
	if hb_lib:
		anim.add_animation_library("hot_bomb", hb_lib)

	anim.play("hot_bomb/Holding_A")
	anim.seek(0.0, true)

	print("p.global_position: ", p.global_position)
	print("ba.global_position: ", ba.global_position)
	print("ba.position (local to skel): ", ba.position)

	anim.play("hot_bomb/Running_HoldingRifle")
	anim.seek(0.2, true)
	print("Running ba.global_position: ", ba.global_position)

	quit()
