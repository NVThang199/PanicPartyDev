extends CanvasLayer

const CHARACTER_SELECT_SCENE := "res://scenes/menus/character_select.tscn"

@onready var credits: AcceptDialog = $Credits

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE)

func _on_credits_pressed() -> void:
	credits.popup_centered()

func _on_exit_pressed() -> void:
	get_tree().quit()
