extends MainLoop

var tree: SceneTree

func _initialize():
	tree = Engine.get_main_loop() as SceneTree
	var scene = load("res://scenes/players/player.tscn")
	var p = scene.instantiate()
	tree.root.add_child(p)

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
	anim_player.seek(0.2, true)
	print("Holding_A bone_attach global_pos: ", bone_attach.global_position)
	print("Holding_A bone_attach position: ", bone_attach.position)

	anim_player.play("hot_bomb/Running_HoldingRifle")
	anim_player.seek(0.2, true)
	print("Running_HoldingRifle bone_attach global_pos: ", bone_attach.global_position)

	return true

func _process(_delta):
	return true
