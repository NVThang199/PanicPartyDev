@tool
extends SceneTree

func _init() -> void:
	print("--- Extracting Tools Animations ---")
	var fbx_path = "res://assets/animations/KayKit_Character_Animations_1.1/Animations/fbx/Rig_Medium/Rig_Medium_Tools.fbx"
	var scn = load(fbx_path) as PackedScene
	if not scn:
		print("ERROR: Cannot load FBX: ", fbx_path)
		quit(1)
		return

	var inst = scn.instantiate()
	var ap: AnimationPlayer = inst.get_node_or_null("AnimationPlayer")
	if not ap:
		print("ERROR: No AnimationPlayer found in FBX")
		inst.free()
		quit(1)
		return

	var tools_lib = AnimationLibrary.new()
	var anim_list = ap.get_animation_list()
	print("Found animations count: ", anim_list.size())

	for anim_name in anim_list:
		var orig_anim: Animation = ap.get_animation(anim_name)
		if orig_anim:
			var dup_anim: Animation = orig_anim.duplicate()
			if anim_name.begins_with("Work") or anim_name.begins_with("Dig") or anim_name.begins_with("Fish") or anim_name.begins_with("Pick"):
				dup_anim.loop_mode = Animation.LOOP_LINEAR
			tools_lib.add_animation(anim_name, dup_anim)

	var save_path = "res://assets/animations/tools_animations.res"
	var err = ResourceSaver.save(tools_lib, save_path)
	if err == OK:
		print("SUCCESS: Saved tools_animations.res with %d anims" % tools_lib.get_animation_list().size())
	else:
		print("ERROR saving tools_animations.res: ", err)

	inst.free()
	quit(0)
