@tool
extends SceneTree

func _init():
	var paths = [
		"res://assets/animations/KayKit_Character_Animations_1.1/Animations/fbx/Rig_Medium/Rig_Medium_Tools.fbx",
		"res://assets/animations/KayKit_Character_Animations_1.1/Animations/fbx/Rig_Medium/Rig_Medium_General.fbx",
		"res://assets/animations/KayKit_Character_Animations_1.1/Animations/fbx/Rig_Medium/Rig_Medium_MovementAdvanced.fbx",
		"res://assets/animations/KayKit_Character_Animations_1.1/Animations/fbx/Rig_Medium/Rig_Medium_Special.fbx"
	]

	for p in paths:
		var scene = load(p)
		if scene:
			var inst = scene.instantiate()
			var ap = inst.get_node_or_null("AnimationPlayer")
			if ap:
				print(p.get_file(), ":", ap.get_animation_list())
			inst.free()
		else:
			print("Could not load:", p)

	quit()
