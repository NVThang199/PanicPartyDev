extends SceneTree

func _init():
	var scene = load("res://scenes/players/player.tscn")
	var p = scene.instantiate()
	root.add_child(p)

	# Load animation library
	var anim_player = p.get_node("AnimationPlayer")
	var hb_lib = load("res://assets/animations/hot_bomb_animations.res")
	if hb_lib:
		anim_player.add_animation_library("hot_bomb", hb_lib)

	var skel: Skeleton3D = p.get_node("Model/Rig_Medium/Skeleton3D")
	var bone_r = skel.find_bone("handslot.r")
	var bone_l = skel.find_bone("handslot.l")
	var hand_r = skel.find_bone("hand.r")
	print("Bone indices: handslot.r=%d, handslot.l=%d, hand.r=%d" % [bone_r, bone_l, hand_r])

	# Check pose in Holding_A
	anim_player.play("hot_bomb/Holding_A")
	anim_player.advance(0.1)

	print("Holding_A global pose handslot.r: ", skel.get_bone_global_pose(bone_r))
	print("Holding_A global pose hand.r: ", skel.get_bone_global_pose(hand_r))
	print("Holding_A global pose handslot.l: ", skel.get_bone_global_pose(bone_l))

	# Check pose in Running_HoldingRifle
	anim_player.play("hot_bomb/Running_HoldingRifle")
	anim_player.advance(0.1)
	print("Running_HoldingRifle global pose handslot.r: ", skel.get_bone_global_pose(bone_r))
	print("Running_HoldingRifle global pose handslot.l: ", skel.get_bone_global_pose(bone_l))

	quit()
