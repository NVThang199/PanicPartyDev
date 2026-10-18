@tool
extends EditorScript

const GRID_ROWS = 9
const GRID_COLS = 7
const TILE_SPACING = 1.8
const TILE_GREEN_SCENE = "res://assets/terrains/floor/tile_green.fbx"
const TILE_RED_SCENE = "res://assets/terrains/floor/tile_red.fbx"

func _run() -> void:
	var scene = get_scene()
	var tile_grid = scene.get_node_or_null("TileGrid")

	if not tile_grid:
		push_error("TileGrid node not found")
		return

	# Clear existing tiles
	for child in tile_grid.get_children():
		child.queue_free()

	# Generate 7x9 grid
	for i in range(GRID_ROWS):
		for j in range(GRID_COLS):
			var tile_node = Node3D.new()
			tile_node.name = "Tile_%d_%d" % [i, j]

			var x = i * TILE_SPACING - (GRID_ROWS / 2.0) * TILE_SPACING + TILE_SPACING / 2.0
			var z = j * TILE_SPACING - (GRID_COLS / 2.0) * TILE_SPACING + TILE_SPACING / 2.0
			tile_node.position = Vector3(x, 0, z)

			tile_grid.add_child(tile_node)
			tile_node.owner = scene

			# Add FBX (random color for preview)
			var fbx_path = TILE_GREEN_SCENE if randf() > 0.5 else TILE_RED_SCENE
			var fbx_scene = load(fbx_path)
			if fbx_scene:
				var fbx = fbx_scene.instantiate()
				tile_node.add_child(fbx)
				fbx.owner = scene

			# Add collision
			var static_body = StaticBody3D.new()
			static_body.name = "StaticBody"
			tile_node.add_child(static_body)
			static_body.owner = scene

			var collision_shape = CollisionShape3D.new()
			var box = BoxShape3D.new()
			box.size = Vector3(TILE_SPACING, 0.2, TILE_SPACING)
			collision_shape.shape = box
			static_body.add_child(collision_shape)
			collision_shape.owner = scene

	print("Generated 8x8 tile grid")
