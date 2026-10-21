@tool
extends SceneTree

func _init() -> void:
	var doc_hook = GLTFDocument.new()
	var state_hook = GLTFState.new()
	if doc_hook.append_from_file("res://assets/terrains/gold_miner/miner_hook.glb", state_hook) == OK:
		var hook_node = doc_hook.generate_scene(state_hook)
		var hook_packed = PackedScene.new()
		hook_packed.pack(hook_node)
		ResourceSaver.save(hook_packed, "res://scenes/minigames/gold_miner/miner_hook.tscn")
		print("Saved miner_hook.tscn")
		hook_node.queue_free()

	var doc_winch = GLTFDocument.new()
	var state_winch = GLTFState.new()
	if doc_winch.append_from_file("res://assets/terrains/gold_miner/miner_winch.glb", state_winch) == OK:
		var winch_node = doc_winch.generate_scene(state_winch)
		var winch_packed = PackedScene.new()
		winch_packed.pack(winch_node)
		ResourceSaver.save(winch_packed, "res://scenes/minigames/gold_miner/miner_winch.tscn")
		print("Saved miner_winch.tscn")
		winch_node.queue_free()

	quit(0)
