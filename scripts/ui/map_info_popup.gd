extends Control

signal popup_closed

@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var controls_vbox: VBoxContainer = $Panel/Margin/VBox/ControlsList
@onready var btn_close: Button = $Panel/Margin/VBox/BtnClose

func _ready() -> void:
	if btn_close:
		btn_close.pressed.connect(_on_close_pressed)
	visible = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if is_node_ready() and btn_close:
			btn_close.text = tr("CLOSE")

func show_map_info(map_type: String) -> void:
	if not is_inside_tree():
		return

	for child in controls_vbox.get_children():
		child.queue_free()

	var map_display_name := ""
	var controls: Array = []

	if map_type == "HotBomb":
		map_display_name = tr("MAP_HOT_BOMB")
		controls = [
			{"action": tr("MOVE"), "key": tr("MOVE_KEYS")},
			{"action": tr("THROW_BOMB"), "key": tr("KEY_E")},
			{"action": tr("PUSH"), "key": tr("KEY_SPACE")}
		]
	elif map_type == "StableFooting":
		map_display_name = tr("MAP_STABLE_FOOTING")
		controls = [
			{"action": tr("MOVE"), "key": tr("MOVE_KEYS")},
			{"action": tr("PUSH"), "key": tr("KEY_SPACE")}
		]
	elif map_type == "Mimic":
		map_display_name = tr("MAP_MIMIC")
		controls = [
			{"action": tr("LISTEN_SAMPLE"), "key": tr("BTN_LISTEN")},
			{"action": tr("RECORD_VOICE"), "key": tr("BTN_RECORD")},
			{"action": tr("REPLAY_RECORDING"), "key": tr("BTN_REPLAY")}
		]
	elif map_type == "Random":
		map_display_name = tr("MAP_RANDOM")
		controls = [
			{"action": tr("MOVE"), "key": tr("MOVE_KEYS")},
			{"action": tr("PUSH"), "key": tr("KEY_SPACE")},
			{"action": tr("THROW_BOMB"), "key": "%s (%s)" % [tr("KEY_E"), tr("MAP_HOT_BOMB")]}
		]

	title_label.text = map_display_name

	for item in controls:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)

		var action_lbl := Label.new()
		action_lbl.text = item["action"]
		action_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_lbl.add_theme_font_size_override("font_size", 16)
		row.add_child(action_lbl)

		var key_lbl := Label.new()
		key_lbl.text = item["key"]
		key_lbl.add_theme_font_size_override("font_size", 16)
		key_lbl.modulate = Color(1.0, 0.85, 0.3)
		row.add_child(key_lbl)

		controls_vbox.add_child(row)

	visible = true

func _on_close_pressed() -> void:
	visible = false
	popup_closed.emit()
