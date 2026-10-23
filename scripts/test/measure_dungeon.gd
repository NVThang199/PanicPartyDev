@tool
extends SceneTree

func _init() -> void:
	var f = FileAccess.open("res://dungeon_asset_sizes.txt", FileAccess.WRITE)
	if not f: quit(1)

	var list = [
		"res://assets/terrains/dungeon/torch_mounted.fbx",
		"res://assets/terrains/dungeon/torch_lit.fbx",
		"res://assets/terrains/dungeon/wall.fbx",
		"res://assets/terrains/dungeon/wall_cracked.fbx",
		"res://assets/terrains/dungeon/column.fbx",
		"res://assets/terrains/dungeon/pillar.fbx",
		"res://assets/terrains/dungeon/barrel_large.fbx",
		"res://assets/terrains/dungeon/crates_stacked.fbx",
		"res://assets/terrains/dungeon/rubble_large.fbx"
	]

	for p in list:
		var scn = load(p) as PackedScene
		if not scn:
			f.store_line(p + ": FAILED")
			continue
		var inst = scn.instantiate() as Node3D
		f.store_line(p + ":")
		_dump(inst, 1, f)
		inst.free()
	f.close()
	quit(0)

func _dump(node: Node, depth: int, f: FileAccess) -> void:
	var pref = ""
	for i in range(depth): pref += "  "
	var extra = ""
	if node is Node3D:
		extra += " scale=" + str((node as Node3D).scale)
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		extra += " aabb=" + str((node as MeshInstance3D).mesh.get_aabb())
	f.store_line(pref + node.name + extra)
	for c in node.get_children():
		_dump(c, depth + 1, f)
