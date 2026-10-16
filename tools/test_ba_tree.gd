extends SceneTree

var p: Node
var ba: BoneAttachment3D
var frame_count: int = 0

func _initialize():
	var p_scene = load("res://scenes/players/player.tscn")
	p = p_scene.instantiate()
	root.add_child(p)

	var skel: Skeleton3D = p.get_node("Model/Rig_Medium/Skeleton3D")
	ba = BoneAttachment3D.new()
	ba.name = "RightHandAttachment"
	ba.bone_name = "handslot.r"
	skel.add_child(ba)

	var anim = p.get_node("AnimationPlayer")
	var hb_lib = load("res://assets/animations/hot_bomb_animations.res")
	if hb_lib:
		anim.add_animation_library("hot_bomb", hb_lib)

	anim.play("hot_bomb/Holding_A")

func _process(delta: float) -> bool:
	frame_count += 1
	if frame_count == 3:
		print("ba global_position: ", ba.global_position)
		print("ba global_transform: ", ba.global_transform)
		print("ba position in skel: ", ba.position)
		quit()
		return true
	return false
