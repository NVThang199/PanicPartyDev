extends SceneTree

func _init():
	call_deferred("_start")

func _start():
	var scene = load("res://scenes/minigames/hot_bomb.tscn").instantiate()
	root.add_child(scene)
	for i in range(5):
		await process_frame

	var nav_region: NavigationRegion3D = scene.get_node("NavigationRegion3D")
	var nav_mesh: NavigationMesh = nav_region.navigation_mesh
	print("Baking NavigationMesh...")
	nav_region.bake_navigation_mesh(false)

	for i in range(10):
		await process_frame

	var err = ResourceSaver.save(nav_mesh, "res://scenes/minigames/hot_bomb_navmesh.tres")
	print("ResourceSaver.save result: ", err)
	print("Navmesh polygons count: ", nav_mesh.get_polygon_count())
	print("Navmesh vertices count: ", nav_mesh.get_vertices().size())

	if nav_mesh.get_polygon_count() > 0:
		print("SUCCESS: Navmesh baked and saved!")
	else:
		push_error("FAILED: Navmesh has 0 polygons")

	quit(0)
