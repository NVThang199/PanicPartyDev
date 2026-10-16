extends SceneTree

func _init():
	var lib = load("res://assets/animations/hot_bomb_animations.res")
	print("Anims in hot_bomb: ", lib.get_animation_list())
	for a in lib.get_animation_list():
		var anim: Animation = lib.get_animation(a)
		print("Anim %s: length=%.2f, tracks=%d" % [a, anim.length, anim.get_track_count()])
		for t in range(anim.get_track_count()):
			var p = anim.track_get_path(t)
			if "hand" in str(p).to_lower():
				print("  track %d: %s" % [t, p])
	quit()
