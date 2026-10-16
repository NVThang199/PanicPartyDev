extends SceneTree

func _process(delta):
	return false

func _init():
	var scene = load("res://scenes/players/player.tscn")
	var p = scene.instantiate()
	root.add_child(p)

	var anim_player = p.get_node("AnimationPlayer")
	var hb_lib = load("res://assets/animations/hot_bomb_animations.res")
	if hb_lib:
		anim_player.add_animation_library("hot_bomb", hb_lib)

	var skel: Skeleton3D = p.get_node("Model/Rig_Medium/Skeleton3D")
	var bone_r = skel.find_bone("handslot.r")
	var hand_r = skel.find_bone("hand.r")

	print("Holding_A:")
	anim_player.play("hot_bomb/Holding_A")
	for t in [0.0, 0.5]:
		anim_player.seek(t, true)
		var p_handslot = skel.get_bone_global_pose(bone_r).origin
		var p_hand = skel.get_bone_global_pose(hand_r).origin
		print("  t=%.1f handslot.r=%s hand.r=%s" % [t, p_handslot, p_hand])

	print("Running_HoldingRifle:")
	anim_player.play("hot_bomb/Running_HoldingRifle")
	for t in [0.0, 0.2, 0.4, 0.6]:
		anim_player.seek(t, true)
		var p_handslot = skel.get_bone_global_pose(bone_r).origin
		var p_hand = skel.get_bone_global_pose(hand_r).origin
		print("  t=%.1f handslot.r=%s hand.r=%s" % [t, p_handslot, p_hand])

	quit()
