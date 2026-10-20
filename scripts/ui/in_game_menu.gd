extends CanvasLayer

const SETTINGS_SCENE = preload("res://scenes/menus/settings_menu.tscn")

@onready var pause_menu: PanelContainer = $PauseMenu
@onready var tab_overlay: PanelContainer = $TabOverlay
@onready var btn_settings: Button = $PauseMenu/Margin/VBox/BtnSettings
@onready var btn_invite: Button = $PauseMenu/Margin/VBox/BtnInvite
@onready var btn_menu: Button = $PauseMenu/Margin/VBox/BtnMenu

func _ready() -> void:
	layer = 5
	if pause_menu:
		pause_menu.visible = false

	if btn_settings:
		btn_settings.pressed.connect(_on_pause_settings_pressed)
	if btn_invite:
		btn_invite.pressed.connect(_on_pause_invite_pressed)
	if btn_menu:
		btn_menu.pressed.connect(_on_pause_menu_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if not is_inside_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		if pause_menu:
			pause_menu.visible = not pause_menu.visible
			get_viewport().set_input_as_handled()

func _on_pause_settings_pressed() -> void:
	var settings = SETTINGS_SCENE.instantiate()
	add_child(settings)
	settings.settings_closed.connect(func(): pass)

func _on_pause_invite_pressed() -> void:
	Networking.open_invite_overlay()
	if pause_menu:
		pause_menu.visible = false

func _on_pause_menu_pressed() -> void:
	var root = owner if owner != null else get_parent()
	if root:
		root.set_process(false)
		root.set_physics_process(false)
	Networking.leave_current_session()
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")

func update_tab_overlay() -> void:
	if tab_overlay and tab_overlay.has_method("refresh"):
		tab_overlay.refresh()
