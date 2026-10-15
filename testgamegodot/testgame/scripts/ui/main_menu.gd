extends CanvasLayer

const GAME_SCENE := "res://scenes/core/main.tscn"

@onready var credits: AcceptDialog = $Credits

func _on_host_pressed() -> void:
	GameSession.is_hosting = true
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_join_pressed() -> void:
	Steam.activateGameOverlay("Friends")

func _on_credits_pressed() -> void:
	credits.popup_centered()

func _on_exit_pressed() -> void:
	get_tree().quit()
