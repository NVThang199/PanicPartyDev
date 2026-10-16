extends SceneTree

func _init():
	var scene = load("res://scenes/players/player.tscn")
	var p = scene.instantiate()
	root.add_child(p)

	var anim_player = p.get_node("AnimationPlayer")
	var hb_lib = load("res://assets/animations/hot_bomb_animations.res")
	if hb_lib:
		anim_player.add_animation_library("hot_bomb", hb_lib)

	var skel: Skeleton3D = p.get_node("Model/Rig_Medium/Skeleton3D")
	var bone_attach = BoneAttachment3D.new()
	bone_attach.bone_name = "handslot.r"
	skel.add_child(bone_attach)

	# Test Holding_A
	anim_player.play("hot_bomb/Holding_A")
	for t in [0.0, 0.2, 0.5, 0.8]:
		anim_player.seek(t, true)
		print("Holding_A t=%.2f bone_attach global_pos=%s" % [t, bone_attach.global_position])

	# Test Running_HoldingRifle
	anim_player.play("hot_bomb/Running_HoldingRifle")
	for t in [0.0, 0.2, 0.4, 0.6]:
		anim_player.seek(t, true)
		print("Running_HoldingRifle t=%.2f bone_attach global_pos=%s" % [t, bone_attach.global_position])

	quit()
