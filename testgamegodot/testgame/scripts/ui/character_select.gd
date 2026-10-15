extends Control

signal character_confirmed(character_path: String)
signal selection_cancelled()

const GAME_SCENE := "res://scenes/core/main.tscn"
const CHARACTERS := {
	"Knight": "res://assets/characters/KayKit_Adventurers_2.0_FREE/Characters/gltf/Knight.glb",
	"Barbarian": "res://assets/characters/KayKit_Adventurers_2.0_FREE/Characters/gltf/Barbarian.glb",
	"Mage": "res://assets/characters/KayKit_Adventurers_2.0_FREE/Characters/gltf/Mage.glb",
	"Ranger": "res://assets/characters/KayKit_Adventurers_2.0_FREE/Characters/gltf/Ranger.glb",
	"Rogue": "res://assets/characters/KayKit_Adventurers_2.0_FREE/Characters/gltf/Rogue.glb"
}

@onready var preview: SubViewport = $Margin/Content/Body/PreviewPanel/PreviewViewportContainer/PreviewViewport
@onready var selected_label: Label = $Margin/Content/Footer/SelectedLabel
var model: Node3D
var anim_player: AnimationPlayer

func _ready() -> void:
	for character_name in CHARACTERS:
		var button := Button.new()
		button.text = character_name
		button.pressed.connect(_select_character.bind(character_name))
		$Margin/Content/Body/LeftPanel/CharacterButtons.add_child(button)
	_select_character("Knight")

func _select_character(character_name: String) -> void:
	GameSession.selected_character = CHARACTERS[character_name]
	selected_label.text = character_name
	if model:
		model.queue_free()
	model = load(GameSession.selected_character).instantiate()
	preview.add_child(model)
	model.position = Vector3(0, -3.0, 0)
	model.scale = Vector3.ONE * 3.0
	
	# Thêm AnimationPlayer và attach vào GLB model
	var ap = AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	preview.add_child(ap)
	ap.root_node = ap.get_path_to(model)
	
	# Gắn library
	var move_lib = load("res://assets/animations/movement_animations.res")
	var gen_lib = load("res://assets/animations/general_animations.res")
	if move_lib: ap.add_animation_library("movement", move_lib)
	if gen_lib: ap.add_animation_library("general", gen_lib)
	
	await get_tree().process_frame
	if ap.has_animation("general/Idle_A"):
		ap.play("general/Idle_A")

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var result := _find_animation_player(child)
		if result:
			return result
	return null

func _on_confirm_pressed() -> void:
	character_confirmed.emit(GameSession.selected_character)
	var tree := get_tree()
	if tree and tree.current_scene == self:
		tree.change_scene_to_file(GAME_SCENE)

func _on_back_pressed() -> void:
	selection_cancelled.emit()
	var tree := get_tree()
	if tree and tree.current_scene == self:
		tree.change_scene_to_file("res://scenes/menus/main_menu.tscn")
