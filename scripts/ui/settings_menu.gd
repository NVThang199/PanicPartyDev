extends CanvasLayer

signal settings_closed

# Display Nodes
@onready var language_option = $Panel/Margin/VBox/Tabs/Display/DisplayContent/LanguageHBox/LanguageOption
@onready var fullscreen_check = $Panel/Margin/VBox/Tabs/Display/DisplayContent/FullscreenCheck
@onready var aspect_option = $Panel/Margin/VBox/Tabs/Display/DisplayContent/AspectRatioHBox/AspectOption
@onready var res_option = $Panel/Margin/VBox/Tabs/Display/DisplayContent/ResolutionHBox/ResOption
@onready var vsync_check = $Panel/Margin/VBox/Tabs/Display/DisplayContent/VsyncCheck
@onready var max_fps_spin = $Panel/Margin/VBox/Tabs/Display/DisplayContent/MaxFpsHBox/MaxFpsSpin

# Advanced Graphics Nodes
@onready var preset_option = $"Panel/Margin/VBox/Tabs/Advanced Graphic/ScrollContainer/GraphicsContent/PresetHBox/PresetOption"
@onready var fxaa_check = $"Panel/Margin/VBox/Tabs/Advanced Graphic/ScrollContainer/GraphicsContent/FXAACheck"
@onready var taa_check = $"Panel/Margin/VBox/Tabs/Advanced Graphic/ScrollContainer/GraphicsContent/TAACheck"
@onready var msaa_option = $"Panel/Margin/VBox/Tabs/Advanced Graphic/ScrollContainer/GraphicsContent/MSAAHBox/MSAAOption"
@onready var fsr_mode_option = $"Panel/Margin/VBox/Tabs/Advanced Graphic/ScrollContainer/GraphicsContent/FSRModeHBox/FSRModeOption"
@onready var fsr_slider = $"Panel/Margin/VBox/Tabs/Advanced Graphic/ScrollContainer/GraphicsContent/FSRHBox/FSRSlider"
@onready var fsr_sharpness_slider = $"Panel/Margin/VBox/Tabs/Advanced Graphic/ScrollContainer/GraphicsContent/FSRSharpnessHBox/FSRSharpnessSlider"
@onready var shadow_option = $"Panel/Margin/VBox/Tabs/Advanced Graphic/ScrollContainer/GraphicsContent/ShadowHBox/ShadowOption"
@onready var ssao_check = $"Panel/Margin/VBox/Tabs/Advanced Graphic/ScrollContainer/GraphicsContent/SSAOCheck"
@onready var ssil_check = $"Panel/Margin/VBox/Tabs/Advanced Graphic/ScrollContainer/GraphicsContent/SSILCheck"
@onready var ssr_check = $"Panel/Margin/VBox/Tabs/Advanced Graphic/ScrollContainer/GraphicsContent/SSRCheck"
@onready var glow_check = $"Panel/Margin/VBox/Tabs/Advanced Graphic/ScrollContainer/GraphicsContent/GlowCheck"
@onready var note_label = $"Panel/Margin/VBox/Tabs/Advanced Graphic/ScrollContainer/GraphicsContent/NotePanel/NoteMargin/NoteLabel"

# Audio Nodes
@onready var master_slider = $Panel/Margin/VBox/Tabs/Audio/AudioContent/MasterVolHBox/MasterSlider
@onready var music_slider = $Panel/Margin/VBox/Tabs/Audio/AudioContent/MusicVolHBox/MusicSlider
@onready var sfx_slider = $Panel/Margin/VBox/Tabs/Audio/AudioContent/SFXVolHBox/SFXSlider
@onready var device_option = $Panel/Margin/VBox/Tabs/Audio/AudioContent/DeviceHBox/DeviceOption
@onready var mode_option = $Panel/Margin/VBox/Tabs/Audio/AudioContent/ModeHBox/ModeOption

# Keybind Nodes
@onready var keybind_list = $Panel/Margin/VBox/Tabs/Keybind/ScrollContainer/KeybindList

const LANGUAGES = [
	{"code": "en", "name": "English"},
	{"code": "vi", "name": "Tiếng Việt"},
	{"code": "es", "name": "Español"},
	{"code": "fr", "name": "Français"},
	{"code": "de", "name": "Deutsch"},
	{"code": "pt_BR", "name": "Português (Brasil)"},
	{"code": "ru", "name": "Русский"},
	{"code": "ja", "name": "日本語"},
	{"code": "ko", "name": "한국어"},
	{"code": "zh_CN", "name": "简体中文"},
	{"code": "it", "name": "Italiano"}
]

const RESOLUTIONS = {
	"16:9": ["1280x720", "1600x900", "1920x1080", "2560x1440", "3840x2160"],
	"16:10": ["1280x800", "1440x900", "1680x1050", "1920x1200", "2560x1600"],
	"4:3": ["1024x768", "1280x960", "1600x1200", "2048x1536"]
}

const ACTION_LABELS = {
	"move_forward": "Move Forward",
	"move_backward": "Move Backward",
	"move_left": "Move Left",
	"move_right": "Move Right",
	"push": "Push / Kick",
	"throw_bomb": "Throw Bomb"
}

var listening_action: String = ""
var listening_button: Button = null

func _ready():
	populate_languages()
	language_option.item_selected.connect(_on_language_selected)
	load_current_settings()
	preset_option.item_selected.connect(_on_preset_selected)
	aspect_option.item_selected.connect(_on_aspect_changed)
	update_resolution_options()
	populate_audio_devices()
	populate_keybinds()
	sfx_slider.drag_ended.connect(func(_val): if AudioManager: AudioManager.play_ui_click())
	_setup_graphic_tooltips()

func _notification(what: int):
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not is_node_ready():
			return
		_update_localized_texts()

func populate_languages():
	language_option.clear()
	for lang in LANGUAGES:
		language_option.add_item(lang["name"])

func _on_language_selected(index: int):
	if index >= 0 and index < LANGUAGES.size():
		var code = LANGUAGES[index]["code"]
		SettingsManager.settings["display"]["language"] = code
		SettingsManager.apply_settings()
		SettingsManager.save_settings()
		_update_localized_texts()

func _update_localized_texts():
	populate_keybinds()
	if note_label:
		note_label.text = tr("Hover over any setting above to view its English explanation.")

func _setup_graphic_tooltips():
	var controls_with_tips = [
		preset_option, fxaa_check, taa_check, msaa_option,
		fsr_mode_option, fsr_slider, fsr_sharpness_slider,
		shadow_option, ssao_check, ssil_check, ssr_check, glow_check
	]
	for ctrl in controls_with_tips:
		if ctrl:
			ctrl.mouse_entered.connect(func():
				if note_label and ctrl.tooltip_text != "":
					note_label.text = ctrl.tooltip_text
			)
			ctrl.focus_entered.connect(func():
				if note_label and ctrl.tooltip_text != "":
					note_label.text = ctrl.tooltip_text
			)

func _input(event: InputEvent) -> void:
	if listening_action != "":
		if event is InputEventKey and event.pressed and not event.is_echo():
			var code = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			if code != KEY_ESCAPE:
				SettingsManager.remap_action_key(listening_action, code)
			_cancel_key_listening()
			populate_keybinds()
			get_viewport().set_input_as_handled()
			return
		elif event.is_action_pressed("ui_cancel"):
			_cancel_key_listening()
			populate_keybinds()
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

func _cancel_key_listening():
	listening_action = ""
	listening_button = null

func populate_audio_devices():
	device_option.clear()
	var devices = AudioServer.get_output_device_list()
	var cur_device = SettingsManager.get_setting("audio", "output_device")
	var selected_idx = 0
	for i in range(devices.size()):
		var dev_name = devices[i]
		device_option.add_item(dev_name)
		if dev_name == cur_device:
			selected_idx = i
	if device_option.item_count > 0:
		device_option.select(selected_idx)

func populate_keybinds():
	if not keybind_list:
		return
	for child in keybind_list.get_children():
		child.queue_free()

	for action in SettingsManager.REBINDABLE_ACTIONS:
		var hbox = HBoxContainer.new()
		hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var label = Label.new()
		label.text = tr(ACTION_LABELS.get(action, action.capitalize()))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(label)

		var btn = Button.new()
		btn.custom_minimum_size = Vector2(140, 30)
		var keycode: int = SettingsManager.settings["keybinds"].get(action, 0)
		btn.text = OS.get_keycode_string(keycode as Key) if keycode != 0 else tr("None")
		btn.pressed.connect(_on_keybind_button_pressed.bind(action, btn))
		hbox.add_child(btn)

		keybind_list.add_child(hbox)

func _on_keybind_button_pressed(action: String, button: Button):
	if AudioManager:
		AudioManager.play_ui_click()
	if listening_button:
		populate_keybinds()
	listening_action = action
	listening_button = button
	button.text = tr("Press any key...")

func update_resolution_options():
	var cur_aspect = aspect_option.get_item_text(aspect_option.selected)
	var res_list = RESOLUTIONS.get(cur_aspect, RESOLUTIONS["16:9"])
	res_option.clear()
	for r in res_list:
		res_option.add_item(r)

func _on_aspect_changed(_index: int):
	update_resolution_options()
	if res_option.item_count > 0:
		res_option.select(0)

func load_current_settings():
	var sm = SettingsManager

	# Display
	var cur_lang = sm.settings["display"].get("language", "en")
	var lang_idx = 0
	for i in range(LANGUAGES.size()):
		if LANGUAGES[i]["code"] == cur_lang:
			lang_idx = i
			break
	if language_option.item_count > 0:
		language_option.select(lang_idx)

	fullscreen_check.button_pressed = sm.get_setting("display", "fullscreen")
	vsync_check.button_pressed = sm.get_setting("display", "vsync")
	max_fps_spin.value = sm.get_setting("display", "max_fps")

	var cur_aspect = sm.settings["display"].get("aspect_ratio", "16:9")
	var aspect_idx = ["16:9", "16:10", "4:3"].find(cur_aspect)
	aspect_option.select(aspect_idx if aspect_idx != -1 else 0)
	update_resolution_options()

	var cur_res = sm.settings["display"].get("resolution", "1920x1080")
	var res_list = RESOLUTIONS.get(cur_aspect, RESOLUTIONS["16:9"])
	var res_idx = res_list.find(cur_res)
	res_option.select(res_idx if res_idx != -1 else 0)

	# Advanced Graphics
	preset_option.select(["Low", "Medium", "High", "Ultra", "Custom"].find(sm.settings["preset"]))
	fxaa_check.button_pressed = sm.get_setting("graphics", "fxaa")
	taa_check.button_pressed = sm.get_setting("graphics", "taa")
	msaa_option.selected = sm.get_setting("graphics", "msaa")
	var scaling_mode = sm.get_setting("graphics", "scaling_mode")
	fsr_mode_option.selected = mini(scaling_mode, 2)
	fsr_slider.value = sm.get_setting("graphics", "fsr_scale")
	fsr_sharpness_slider.value = sm.settings["graphics"].get("fsr_sharpness", 0.2)
	shadow_option.selected = sm.get_setting("graphics", "shadow_quality")
	ssao_check.button_pressed = sm.get_setting("graphics", "ssao")
	ssil_check.button_pressed = sm.get_setting("graphics", "ssil")
	ssr_check.button_pressed = sm.get_setting("graphics", "ssr")
	glow_check.button_pressed = sm.get_setting("graphics", "glow")

	# Audio
	master_slider.value = sm.get_setting("audio", "master_volume")
	music_slider.value = sm.get_setting("audio", "music_volume")
	sfx_slider.value = sm.get_setting("audio", "sfx_volume")
	var cur_mode = sm.get_setting("audio", "speaker_mode")
	mode_option.select(1 if cur_mode == "Mono" else 0)

func _on_preset_selected(index: int):
	var presets = ["Low", "Medium", "High", "Ultra", "Custom"]
	if index < 4:
		SettingsManager.apply_preset(presets[index])
		load_current_settings()

func _on_apply_pressed():
	var sm = SettingsManager

	# Display
	if language_option.selected >= 0 and language_option.selected < LANGUAGES.size():
		sm.set_setting("display", "language", LANGUAGES[language_option.selected]["code"])
	sm.set_setting("display", "fullscreen", fullscreen_check.button_pressed)
	sm.set_setting("display", "vsync", vsync_check.button_pressed)
	sm.set_setting("display", "max_fps", int(max_fps_spin.value))
	var chosen_aspect = aspect_option.get_item_text(aspect_option.selected)
	sm.set_setting("display", "aspect_ratio", chosen_aspect)
	if res_option.selected >= 0:
		sm.set_setting("display", "resolution", res_option.get_item_text(res_option.selected))

	# Advanced Graphics
	sm.set_setting("graphics", "fxaa", fxaa_check.button_pressed)
	sm.set_setting("graphics", "taa", taa_check.button_pressed)
	sm.set_setting("graphics", "msaa", msaa_option.selected)
	sm.set_setting("graphics", "scaling_mode", fsr_mode_option.selected)
	sm.set_setting("graphics", "fsr_scale", fsr_slider.value)
	sm.set_setting("graphics", "fsr_sharpness", fsr_sharpness_slider.value)
	sm.set_setting("graphics", "shadow_quality", shadow_option.selected)
	sm.set_setting("graphics", "ssao", ssao_check.button_pressed)
	sm.set_setting("graphics", "ssil", ssil_check.button_pressed)
	sm.set_setting("graphics", "ssr", ssr_check.button_pressed)
	sm.set_setting("graphics", "glow", glow_check.button_pressed)

	# Audio
	sm.set_setting("audio", "master_volume", master_slider.value)
	sm.set_setting("audio", "music_volume", music_slider.value)
	sm.set_setting("audio", "sfx_volume", sfx_slider.value)
	if device_option.selected >= 0 and device_option.item_count > 0:
		sm.set_setting("audio", "output_device", device_option.get_item_text(device_option.selected))
	sm.set_setting("audio", "speaker_mode", mode_option.get_item_text(mode_option.selected))

	sm.apply_settings()
	sm.save_settings()
	if AudioManager:
		AudioManager.play_ui_click()

	preset_option.select(4) # Custom

func _on_close_pressed():
	if AudioManager:
		AudioManager.play_ui_click()
	settings_closed.emit()
	queue_free()
