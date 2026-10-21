extends Node

func _ready() -> void:
	var scn = load("res://scenes/minigames/gold_miner/gold_miner.tscn") as PackedScene
	if not scn:
		get_tree().quit(1)
		return
	var inst = scn.instantiate()
	add_child(inst)

	if inst.has_method("_spawn_default_minerals"):
		inst._spawn_default_minerals()

	# Chờ 8 frame để GPU render hoàn tất
	for i in range(8):
		await get_tree().process_frame

	var vp = get_viewport()
	if vp:
		var tex = vp.get_texture()
		if tex:
			var img = tex.get_image()
			if img:
				img.save_png("res://screenshot_gold_miner.png")

	inst.queue_free()
	get_tree().quit(0)
