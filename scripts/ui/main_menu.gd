extends CanvasLayer

const GAME_SCENE := "res://scenes/core/main.tscn"
const SETTINGS_SCENE := preload("res://scenes/menus/settings_menu.tscn")

@onready var credits: AcceptDialog = $Credits

func _on_host_pressed() -> void:
	GameSession.is_hosting = true
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_join_pressed() -> void:
	Steam.activateGameOverlay("Friends")

func _on_credits_pressed() -> void:
	credits.popup_centered()

func _on_settings_pressed() -> void:
	var settings = SETTINGS_SCENE.instantiate()
	add_child(settings)
	settings.settings_closed.connect(func(): pass)

func _on_exit_pressed() -> void:
	get_tree().quit()
