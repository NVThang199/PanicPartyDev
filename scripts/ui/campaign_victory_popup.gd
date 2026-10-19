extends Control

signal play_again_requested
signal return_to_menu_requested

@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var winner_label: Label = $Panel/Margin/VBox/WinnerLabel
@onready var button_container: HBoxContainer = $Panel/Margin/VBox/ButtonsHBox
@onready var btn_play_again: Button = $Panel/Margin/VBox/ButtonsHBox/BtnPlayAgain
@onready var btn_return_menu: Button = $Panel/Margin/VBox/ButtonsHBox/BtnReturnMenu

func _ready() -> void:
	if btn_play_again:
		btn_play_again.pressed.connect(_on_play_again_pressed)
	if btn_return_menu:
		btn_return_menu.pressed.connect(_on_return_menu_pressed)
	visible = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if is_node_ready():
			title_label.text = tr("CAMPAIGN_VICTORY")
			if btn_play_again:
				btn_play_again.text = tr("PLAY_AGAIN")
			if btn_return_menu:
				btn_return_menu.text = tr("BACK_TO_MENU")

func show_victory(winner_name: String, wins_count: int, is_host: bool) -> void:
	title_label.text = tr("CAMPAIGN_VICTORY")
	winner_label.text = tr("CAMPAIGN_WINNER_TEXT") % [winner_name, wins_count]

	if btn_play_again:
		btn_play_again.text = tr("PLAY_AGAIN")
	if btn_return_menu:
		btn_return_menu.text = tr("BACK_TO_MENU")

	if button_container:
		button_container.visible = is_host

	visible = true

func _on_play_again_pressed() -> void:
	play_again_requested.emit()

func _on_return_menu_pressed() -> void:
	return_to_menu_requested.emit()
