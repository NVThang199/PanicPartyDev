@tool
extends SceneTree

func _init() -> void:
	var fa = FileAccess.open("res://tools_check.txt", FileAccess.WRITE)
	var lib = load("res://assets/animations/tools_animations.res") as AnimationLibrary
	if not lib:
		fa.store_line("FAILED to load tools_animations.res")
	else:
		fa.store_line("Has Working_C: " + str(lib.has_animation("Working_C")))
		var anim = lib.get_animation("Working_C")
		fa.store_line("Loop mode: " + str(anim.loop_mode))
		fa.store_line("Length: " + str(anim.length))
	fa.close()
	quit(0)
