@tool
extends SceneTree

func _init():
	var lib = AnimationLibrary.new()

	var targets = {
		"Holding_A": "res://assets/animations/KayKit_Character_Animations_1.1/Animations/fbx/Rig_Medium/Rig_Medium_Tools.fbx",
		"Throw": "res://assets/animations/KayKit_Character_Animations_1.1/Animations/fbx/Rig_Medium/Rig_Medium_General.fbx",
		"Running_HoldingRifle": "res://assets/animations/KayKit_Character_Animations_1.1/Animations/fbx/Rig_Medium/Rig_Medium_MovementAdvanced.fbx",
		"Skeletons_Death": "res://assets/animations/KayKit_Character_Animations_1.1/Animations/fbx/Rig_Medium/Rig_Medium_Special.fbx"
	}

	var looping_anims = ["Running_HoldingRifle", "Holding_A"]

	for anim_name in targets:
		var scene_path = targets[anim_name]
		var scene = load(scene_path)
		if scene:
			var inst = scene.instantiate()
			var ap: AnimationPlayer = inst.get_node_or_null("AnimationPlayer")
			if ap and ap.has_animation(anim_name):
				var anim: Animation = ap.get_animation(anim_name).duplicate()
				if anim_name in looping_anims:
					anim.loop_mode = Animation.LOOP_LINEAR
				lib.add_animation(anim_name, anim)
				print("Extracted:", anim_name, " (loop_mode=", anim.loop_mode, ")")
			inst.free()

	var err = ResourceSaver.save(lib, "res://assets/animations/hot_bomb_animations.res")
	if err == OK:
		print("Successfully saved hot_bomb_animations.res")
	else:
		print("Failed to save:", err)

	quit()
