class_name GoldMinerItem
extends Area3D

enum Type {
	GOLD_LARGE,
	GOLD_MEDIUM,
	GOLD_SMALL,
	DIAMOND,
	ROCK_LARGE,
	ROCK_SMALL,
	OBSTACLE
}

const CONFIGS: Dictionary = {
	Type.GOLD_LARGE: {
		"value": 500,
		"weight": 4.0,
		"radius": 0.95,
		"color": Color(1.0, 0.8, 0.1),
		"grabbable": true
	},
	Type.GOLD_MEDIUM: {
		"value": 250,
		"weight": 2.5,
		"radius": 0.65,
		"color": Color(0.95, 0.75, 0.1),
		"grabbable": true
	},
	Type.GOLD_SMALL: {
		"value": 100,
		"weight": 1.2,
		"radius": 0.4,
		"color": Color(0.9, 0.7, 0.1),
		"grabbable": true
	},
	Type.DIAMOND: {
		"value": 800,
		"weight": 0.5,
		"radius": 0.35,
		"color": Color(0.2, 0.9, 1.0),
		"grabbable": true
	},
	Type.ROCK_LARGE: {
		"value": 50,
		"weight": 5.0,
		"radius": 0.95,
		"color": Color(0.45, 0.45, 0.45),
		"grabbable": true
	},
	Type.ROCK_SMALL: {
		"value": 25,
		"weight": 2.5,
		"radius": 0.5,
		"color": Color(0.35, 0.35, 0.35),
		"grabbable": true
	},
	Type.OBSTACLE: {
		"value": 0,
		"weight": 1.0,
		"radius": 0.8,
		"color": Color(0.3, 0.15, 0.1),
		"grabbable": false
	}
}

const MODEL_PATHS: Dictionary = {
	Type.GOLD_LARGE: "res://assets/terrains/dungeon/chest_gold.fbx",
	Type.GOLD_MEDIUM: "res://assets/terrains/dungeon/chest_gold.fbx",
	Type.GOLD_SMALL: "res://assets/terrains/floor/coin_1_gold.fbx",
	Type.DIAMOND: "res://assets/terrains/fbx/diamond_teamBlue.fbx",
	Type.ROCK_LARGE: "res://assets/terrains/nature/Rock_3_A_Color1.fbx",
	Type.ROCK_SMALL: "res://assets/terrains/nature/Rock_3_A_Color1.fbx",
	Type.OBSTACLE: "res://assets/terrains/fbx/spikeRoller.fbx"
}

const MODEL_TRANSFORMS: Dictionary = {
	Type.GOLD_LARGE: {
		"scale": Vector3(1.2, 1.2, 1.2),
		"offset": Vector3(0.0, -0.6, 0.0),
		"rotation_deg": Vector3(0.0, 0.0, 0.0)
	},
	Type.GOLD_MEDIUM: {
		"scale": Vector3(0.8, 0.8, 0.8),
		"offset": Vector3(0.0, -0.4, 0.0),
		"rotation_deg": Vector3(0.0, 0.0, 0.0)
	},
	Type.GOLD_SMALL: {
		"scale": Vector3(0.7, 0.7, 0.7),
		"offset": Vector3(0.0, 0.0, 0.0),
		"rotation_deg": Vector3(90.0, 0.0, 0.0)
	},
	Type.DIAMOND: {
		"scale": Vector3(0.6, 0.6, 0.6),
		"offset": Vector3(0.0, 0.0, 0.0),
		"rotation_deg": Vector3(0.0, 25.0, 0.0)
	},
	Type.ROCK_LARGE: {
		"scale": Vector3(2.0, 2.0, 2.0),
		"offset": Vector3(0.0, 0.0, 0.0),
		"rotation_deg": Vector3(15.0, 45.0, 0.0)
	},
	Type.ROCK_SMALL: {
		"scale": Vector3(1.0, 1.0, 1.0),
		"offset": Vector3(0.0, 0.0, 0.0),
		"rotation_deg": Vector3(-20.0, 70.0, 10.0)
	},
	Type.OBSTACLE: {
		"scale": Vector3(0.8, 0.8, 0.8),
		"offset": Vector3(0.0, -0.8, 0.0),
		"rotation_deg": Vector3(0.0, 0.0, 0.0)
	}
}

var item_id: int = 0
var item_type: Type = Type.GOLD_LARGE
var value: int = 500
var weight: float = 4.0
var radius: float = 1.0
var grabbable: bool = true
var is_hooked: bool = false
var is_collected: bool = false
var model_node: Node3D = null

func _ready() -> void:
	_update_visuals_and_collision()

func setup_item(p_id: int, p_type: int, p_pos: Vector3) -> void:
	item_id = p_id
	item_type = p_type as Type
	position = p_pos

	var cfg = CONFIGS.get(item_type, CONFIGS[Type.GOLD_LARGE])
	value = cfg.get("value", 0)
	weight = cfg.get("weight", 1.0)
	radius = cfg.get("radius", 1.0)
	grabbable = cfg.get("grabbable", true)

	_update_visuals_and_collision()

func _update_visuals_and_collision() -> void:
	var col = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col:
		var shape = col.shape
		if not shape or not (shape is SphereShape3D):
			shape = SphereShape3D.new()
			col.shape = shape
		else:
			shape = shape.duplicate()
			col.shape = shape
		(shape as SphereShape3D).radius = radius

	var mesh_inst = get_node_or_null("MeshInstance3D") as MeshInstance3D

	var model_path = MODEL_PATHS.get(item_type, "")
	var loaded_model_scene: PackedScene = null
	if model_path != "" and ResourceLoader.exists(model_path):
		loaded_model_scene = load(model_path) as PackedScene

	if loaded_model_scene != null:
		if mesh_inst:
			mesh_inst.visible = false
		if model_node and is_instance_valid(model_node):
			_clear_materials_recursive(model_node)
			remove_child(model_node)
			model_node.queue_free()
			model_node = null

		model_node = loaded_model_scene.instantiate() as Node3D
		if model_node:
			var xform = MODEL_TRANSFORMS.get(item_type, {})
			model_node.scale = xform.get("scale", Vector3.ONE)
			model_node.position = xform.get("offset", Vector3.ZERO)
			var rot_deg: Vector3 = xform.get("rotation_deg", Vector3.ZERO)
			model_node.rotation_degrees = rot_deg
			add_child(model_node)
	else:
		if mesh_inst:
			mesh_inst.visible = true
			var sphere_mesh = SphereMesh.new()
			sphere_mesh.radius = radius
			sphere_mesh.height = radius * 2.0
			mesh_inst.mesh = sphere_mesh

			var cfg = CONFIGS.get(item_type, CONFIGS[Type.GOLD_LARGE])
			var mat = StandardMaterial3D.new()
			mat.albedo_color = cfg.get("color", Color.WHITE)
			mat.roughness = 0.3 if item_type == Type.DIAMOND else 0.6
			mat.metallic = 0.8 if (item_type in [Type.GOLD_LARGE, Type.GOLD_MEDIUM, Type.GOLD_SMALL]) else 0.1
			mesh_inst.material_override = mat

func get_item_value() -> int:
	return value

func get_item_weight() -> float:
	return weight

func is_grabbable() -> bool:
	return grabbable

func _clear_materials_recursive(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node is MeshInstance3D:
		var mi = node as MeshInstance3D
		mi.material_override = null
		for i in range(mi.get_surface_override_material_count()):
			mi.set_surface_override_material(i, null)
	for child in node.get_children():
		_clear_materials_recursive(child)

func _exit_tree() -> void:
	_clear_materials_recursive(self)
