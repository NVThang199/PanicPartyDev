extends CanvasLayer

const CHARACTERS := {
	"Knight": "res://assets/characters/KayKit_Adventurers_2.0_FREE/Characters/gltf/Knight.glb",
	"Barbarian": "res://assets/characters/KayKit_Adventurers_2.0_FREE/Characters/gltf/Barbarian.glb",
	"Mage": "res://assets/characters/KayKit_Adventurers_2.0_FREE/Characters/gltf/Mage.glb",
	"Ranger": "res://assets/characters/KayKit_Adventurers_2.0_FREE/Characters/gltf/Ranger.glb",
	"Rogue": "res://assets/characters/KayKit_Adventurers_2.0_FREE/Characters/gltf/Rogue.glb"
}

@onready var option_button: OptionButton = $Control/OptionButton

func _ready() -> void:
	if not option_button:
		return

	_populate_options()

	# Connect signal
	option_button.item_selected.connect(_on_character_selected)

	# Khởi tạo theo lựa chọn từ màn character select, không ép về Knight
	var initial_index := 0
	if GameSession.selected_character:
		var paths := CHARACTERS.values()
		var found := paths.find(GameSession.selected_character)
		if found >= 0:
			initial_index = found
	option_button.selected = initial_index
	if initial_index != 0:
		_on_character_selected(initial_index)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not is_node_ready():
			return
		_populate_options()

func _populate_options() -> void:
	if not option_button:
		return
	var selected_idx = option_button.selected
	option_button.clear()
	for char_name in CHARACTERS.keys():
		option_button.add_item(tr(char_name))
	if selected_idx >= 0 and selected_idx < option_button.item_count:
		option_button.selected = selected_idx

func _on_character_selected(index: int) -> void:
	if index < 0 or index >= CHARACTERS.size():
		return
	
	var character_array = CHARACTERS.keys()
	var char_name: String = character_array[index]
	var glb_path: String = CHARACTERS[char_name]
	
	# Get the current Player node
	var player = get_tree().current_scene.get_node_or_null("Player")
	if not player or not player.has_method("switch_character"):
		return
	
	# Switch character
	player.switch_character(glb_path)
