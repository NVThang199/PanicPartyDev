extends CanvasLayer

signal settings_closed

@onready var preset_option = $Panel/Margin/VBox/Tabs/Display/DisplayContent/PresetOption
@onready var fullscreen_check = $Panel/Margin/VBox/Tabs/Display/DisplayContent/FullscreenCheck
@onready var aspect_option = $Panel/Margin/VBox/Tabs/Display/DisplayContent/AspectRatioHBox/AspectOption
@onready var res_option = $Panel/Margin/VBox/Tabs/Display/DisplayContent/ResolutionHBox/ResOption
@onready var vsync_check = $Panel/Margin/VBox/Tabs/Display/DisplayContent/VsyncCheck
@onready var max_fps_spin = $Panel/Margin/VBox/Tabs/Display/DisplayContent/MaxFpsHBox/MaxFpsSpin

@onready var fxaa_check = $Panel/Margin/VBox/Tabs/Graphics/GraphicsContent/FXAACheck
@onready var taa_check = $Panel/Margin/VBox/Tabs/Graphics/GraphicsContent/TAACheck
@onready var msaa_option = $Panel/Margin/VBox/Tabs/Graphics/GraphicsContent/MSAAHBox/MSAAOption
@onready var fsr_slider = $Panel/Margin/VBox/Tabs/Graphics/GraphicsContent/FSRHBox/FSRSlider
@onready var shadow_option = $Panel/Margin/VBox/Tabs/Graphics/GraphicsContent/ShadowHBox/ShadowOption
@onready var ssao_check = $Panel/Margin/VBox/Tabs/Graphics/GraphicsContent/SSAOCheck
@onready var ssil_check = $Panel/Margin/VBox/Tabs/Graphics/GraphicsContent/SSILCheck
@onready var ssr_check = $Panel/Margin/VBox/Tabs/Graphics/GraphicsContent/SSRCheck
@onready var glow_check = $Panel/Margin/VBox/Tabs/Graphics/GraphicsContent/GlowCheck

const RESOLUTIONS = {
	"16:9": ["1280x720", "1600x900", "1920x1080", "2560x1440", "3840x2160"],
	"16:10": ["1280x800", "1440x900", "1680x1050", "1920x1200", "2560x1600"],
	"4:3": ["1024x768", "1280x960", "1600x1200", "2048x1536"]
}

func _ready():
	load_current_settings()
	preset_option.item_selected.connect(_on_preset_selected)
	aspect_option.item_selected.connect(_on_aspect_changed)
	update_resolution_options()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close_pressed()
		get_viewport().set_input_as_handled()

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

	preset_option.select(["Low", "Medium", "High", "Ultra", "Custom"].find(sm.settings["preset"]))

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

	fxaa_check.button_pressed = sm.get_setting("graphics", "fxaa")
	taa_check.button_pressed = sm.get_setting("graphics", "taa")
	msaa_option.selected = sm.get_setting("graphics", "msaa")
	fsr_slider.value = sm.get_setting("graphics", "fsr_scale")
	shadow_option.selected = sm.get_setting("graphics", "shadow_quality")
	ssao_check.button_pressed = sm.get_setting("graphics", "ssao")
	ssil_check.button_pressed = sm.get_setting("graphics", "ssil")
	ssr_check.button_pressed = sm.get_setting("graphics", "ssr")
	glow_check.button_pressed = sm.get_setting("graphics", "glow")

func _on_preset_selected(index: int):
	var presets = ["Low", "Medium", "High", "Ultra", "Custom"]
	if index < 4:
		SettingsManager.apply_preset(presets[index])
		load_current_settings()

func _on_apply_pressed():
	var sm = SettingsManager

	sm.set_setting("display", "fullscreen", fullscreen_check.button_pressed)
	sm.set_setting("display", "vsync", vsync_check.button_pressed)
	sm.set_setting("display", "max_fps", int(max_fps_spin.value))
	var chosen_aspect = aspect_option.get_item_text(aspect_option.selected)
	sm.set_setting("display", "aspect_ratio", chosen_aspect)
	if res_option.selected >= 0:
		sm.set_setting("display", "resolution", res_option.get_item_text(res_option.selected))

	sm.set_setting("graphics", "fxaa", fxaa_check.button_pressed)
	sm.set_setting("graphics", "taa", taa_check.button_pressed)
	sm.set_setting("graphics", "msaa", msaa_option.selected)
	sm.set_setting("graphics", "fsr_scale", fsr_slider.value)
	sm.set_setting("graphics", "shadow_quality", shadow_option.selected)
	sm.set_setting("graphics", "ssao", ssao_check.button_pressed)
	sm.set_setting("graphics", "ssil", ssil_check.button_pressed)
	sm.set_setting("graphics", "ssr", ssr_check.button_pressed)
	sm.set_setting("graphics", "glow", glow_check.button_pressed)

	sm.apply_settings()
	sm.save_settings()

	preset_option.select(4)

func _on_close_pressed():
	settings_closed.emit()
	queue_free()
