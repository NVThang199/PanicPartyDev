@tool
extends Node3D

func _ready() -> void:
	if Engine.is_editor_hint():
		_add_models_to_tiles()

func _add_models_to_tiles() -> void:
	var tile_grid = get_node_or_null("TileGrid")
	if not tile_grid:
		return

	for child in tile_grid.get_children():
		var model = child.get_node_or_null("Model")
		if model:
			continue

		# Add default green model to each tile
		var fbx_scene = load("res://assets/terrains/floor/tile_green.fbx")
		if fbx_scene:
			var model_instance = fbx_scene.instantiate()
			model_instance.name = "Model"
			child.add_child(model_instance)
			model_instance.owner = get_tree().edited_scene_root
