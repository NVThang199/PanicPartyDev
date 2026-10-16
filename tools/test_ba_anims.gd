extends SceneTree

var p: Node
var ba: BoneAttachment3D
var anim: AnimationPlayer
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

	anim = p.get_node("AnimationPlayer")
	var hb_lib = load("res://assets/animations/hot_bomb_animations.res")
	if hb_lib:
		anim.add_animation_library("hot_bomb", hb_lib)

func _process(delta: float) -> bool:
	frame_count += 1
	if frame_count == 2:
		anim.play("hot_bomb/Holding_A")
	elif frame_count == 4:
		print("Holding_A ba global_pos: ", ba.global_position)
		anim.play("hot_bomb/Running_HoldingRifle")
	elif frame_count == 6:
		print("Running_HoldingRifle ba global_pos: ", ba.global_position)
		anim.play("general/Idle_A")
	elif frame_count == 8:
		print("Idle_A ba global_pos: ", ba.global_position)
		quit()
		return true
	return false
