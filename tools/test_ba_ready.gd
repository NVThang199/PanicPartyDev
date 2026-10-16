extends Node

func _ready():
	var p_scene = load("res://scenes/players/player.tscn")
	var p = p_scene.instantiate()
	add_child(p)

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

	await get_tree().process_frame

	print("p.global_position: ", p.global_position)
	print("ba.global_position: ", ba.global_position)
	print("ba.position: ", ba.position)

	get_tree().quit()
