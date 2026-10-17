@tool
extends EditorScript

func _run() -> void:
	var scene = get_scene()
	var tile_grid = scene.get_node_or_null("TileGrid")

	if not tile_grid:
		push_error("TileGrid not found")
		return

	var tile_count = 0
	for tile_node in tile_grid.get_children():
		# Skip if model already exists
		if tile_node.get_node_or_null("Model"):
			continue

		# Add green model by default
		var fbx_path = "res://assets/terrains/floor/tile_green.fbx"
		var fbx_scene = load(fbx_path)
		if fbx_scene:
			var model = fbx_scene.instantiate()
			model.name = "Model"
			tile_node.add_child(model)
			model.owner = scene
			tile_count += 1

	print("Added FBX models to %d tiles. Save scene to persist." % tile_count)
