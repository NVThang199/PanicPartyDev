extends CanvasLayer

const GAME_SCENE := "res://scenes/core/main.tscn"
const SETTINGS_SCENE := preload("res://scenes/menus/settings_menu.tscn")

@onready var credits: AcceptDialog = $Credits
@onready var code_input: LineEdit = $JoinCodePanel/Margin/HBox/CodeInput
@onready var btn_join_code: Button = $JoinCodePanel/Margin/HBox/BtnJoinCode

var steam_warning_dialog: ConfirmationDialog = null

func _ready() -> void:
	if btn_join_code:
		btn_join_code.pressed.connect(_on_join_code_pressed)
	if code_input:
		code_input.text_submitted.connect(func(_text): _on_join_code_pressed())

	_update_ui_text()

	if not Steam.isSteamRunning():
		_show_steam_warning()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not is_node_ready():
			return
		_update_ui_text()

func _update_ui_text() -> void:
	if code_input:
		code_input.placeholder_text = tr("ENTER_ROOM_CODE")
	if btn_join_code:
		btn_join_code.text = tr("JOIN_ROOM")
	if credits:
		credits.title = tr("CREDITS_DIALOG_TITLE")
		credits.dialog_text = tr("CREDITS_DIALOG_TEXT")
	if steam_warning_dialog and is_instance_valid(steam_warning_dialog):
		steam_warning_dialog.title = tr("STEAM_REQUIRED_TITLE")
		steam_warning_dialog.dialog_text = tr("STEAM_REQUIRED_MSG")
		steam_warning_dialog.ok_button_text = tr("RETRY")
		steam_warning_dialog.cancel_button_text = tr("QUIT_GAME")

func _show_steam_warning() -> void:
	if steam_warning_dialog and is_instance_valid(steam_warning_dialog):
		steam_warning_dialog.popup_centered()
		return

	steam_warning_dialog = ConfirmationDialog.new()
	steam_warning_dialog.title = tr("STEAM_REQUIRED_TITLE")
	steam_warning_dialog.dialog_text = tr("STEAM_REQUIRED_MSG")
	steam_warning_dialog.ok_button_text = tr("RETRY")
	steam_warning_dialog.cancel_button_text = tr("QUIT_GAME")
	steam_warning_dialog.confirmed.connect(_on_steam_retry)
	steam_warning_dialog.canceled.connect(_on_steam_quit)
	add_child(steam_warning_dialog)
	steam_warning_dialog.popup_centered()

func _on_steam_retry() -> void:
	if Steam.isSteamRunning():
		if steam_warning_dialog and is_instance_valid(steam_warning_dialog):
			steam_warning_dialog.queue_free()
			steam_warning_dialog = null
		Networking._ready()
	else:
		_show_steam_warning()

func _on_steam_quit() -> void:
	get_tree().quit()

func _on_join_code_pressed() -> void:
	if not code_input:
		return
	var code_text := code_input.text.strip_edges()
	if code_text == "":
		return
	var lobby_id := int(code_text)
	if lobby_id <= 0:
		push_warning("[MAIN_MENU] Mã phòng không hợp lệ: %s" % code_text)
		return
	Networking.join_lobby_by_id(lobby_id)

func _on_host_pressed() -> void:
	if not Steam.isSteamRunning():
		_show_steam_warning()
		return
	GameSession.is_hosting = true
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_join_pressed() -> void:
	if not Steam.isSteamRunning():
		_show_steam_warning()
		return
	Steam.activateGameOverlay("Friends")

func _on_credits_pressed() -> void:
	if credits:
		credits.title = tr("CREDITS_DIALOG_TITLE")
		credits.dialog_text = tr("CREDITS_DIALOG_TEXT")
		credits.popup_centered()

func _on_settings_pressed() -> void:
	var settings = SETTINGS_SCENE.instantiate()
	add_child(settings)
	settings.settings_closed.connect(func(): pass)

func _on_exit_pressed() -> void:
	get_tree().quit()

