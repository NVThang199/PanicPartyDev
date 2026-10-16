extends Node
# Quản lý settings đồ họa và display

signal settings_changed

const SAVE_PATH = "user://settings.cfg"

var settings = {
	"preset": "Medium",
	"display": {
		"fullscreen": false,
		"vsync": true,
		"max_fps": 60,
		"aspect_ratio": "16:9",
		"resolution": "1920x1080"
	},
	"graphics": {
		"fxaa": false,
		"taa": true,
		"msaa": 0,
		"scaling_mode": 0,
		"fsr_scale": 1.0,
		"shadow_quality": 1,
		"ssao": true,
		"ssil": false,
		"ssr": false,
		"glow": true
	}
}

func _ready():
	load_settings()
	apply_settings()

func load_settings():
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		settings["preset"] = config.get_value("general", "preset", "Medium")
		for key in settings["display"]:
			settings["display"][key] = config.get_value("display", key, settings["display"][key])
		for key in settings["graphics"]:
			settings["graphics"][key] = config.get_value("graphics", key, settings["graphics"][key])

func save_settings():
	var config = ConfigFile.new()
	config.set_value("general", "preset", settings["preset"])
	for key in settings["display"]:
		config.set_value("display", key, settings["display"][key])
	for key in settings["graphics"]:
		config.set_value("graphics", key, settings["graphics"][key])
	config.save(SAVE_PATH)

func apply_settings():
	# Display Mode & Resolution
	var res_str: String = settings["display"].get("resolution", "1920x1080")
	var parts = res_str.split("x")
	var res_w = int(parts[0]) if parts.size() > 0 else 1920
	var res_h = int(parts[1]) if parts.size() > 1 else 1080

	if settings["display"]["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(res_w, res_h))
		# Center window on primary screen
		var screen_rect = DisplayServer.screen_get_usable_rect()
		var center_pos = screen_rect.position + (screen_rect.size - Vector2i(res_w, res_h)) / 2
		DisplayServer.window_set_position(center_pos)

	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings["display"]["vsync"] else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = settings["display"]["max_fps"]

	# Graphics
	var viewport = get_viewport()
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if settings["graphics"]["fxaa"] else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.scaling_3d_mode = settings["graphics"]["scaling_mode"]
	viewport.scaling_3d_scale = settings["graphics"]["fsr_scale"]
	# FSR 2 has built-in temporal upscaler, cannot use standalone TAA
	if viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR2:
		viewport.use_taa = false
	else:
		viewport.use_taa = settings["graphics"]["taa"]
	viewport.msaa_3d = settings["graphics"]["msaa"]

	# Shadows
	var shadow_q = settings["graphics"].get("shadow_quality", 2)
	RenderingServer.directional_shadow_atlas_set_size(4096 if shadow_q >= 2 else (2048 if shadow_q == 1 else 1024), true)
	RenderingServer.directional_soft_shadow_filter_set_quality(shadow_q)

	var env = get_viewport().get_world_3d().environment
	if env:
		env.ssao_enabled = settings["graphics"]["ssao"]
		env.ssil_enabled = settings["graphics"]["ssil"]
		env.ssr_enabled = settings["graphics"]["ssr"]
		env.glow_enabled = settings["graphics"]["glow"]
		env.volumetric_fog_enabled = false

	settings_changed.emit()

func apply_preset(preset_name: String):
	settings["preset"] = preset_name
	match preset_name:
		"Low":
			settings["graphics"]["fxaa"] = false
			settings["graphics"]["taa"] = false
			settings["graphics"]["msaa"] = 0
			settings["graphics"]["scaling_mode"] = Viewport.SCALING_3D_MODE_FSR
			settings["graphics"]["fsr_scale"] = 0.75
			settings["graphics"]["shadow_quality"] = 0
			settings["graphics"]["ssao"] = false
			settings["graphics"]["ssil"] = false
			settings["graphics"]["ssr"] = false
			settings["graphics"]["glow"] = false
		"Medium":
			settings["graphics"]["fxaa"] = false
			settings["graphics"]["taa"] = true
			settings["graphics"]["msaa"] = 0
			settings["graphics"]["scaling_mode"] = Viewport.SCALING_3D_MODE_BILINEAR
			settings["graphics"]["fsr_scale"] = 1.0
			settings["graphics"]["shadow_quality"] = 1
			settings["graphics"]["ssao"] = true
			settings["graphics"]["ssil"] = false
			settings["graphics"]["ssr"] = false
			settings["graphics"]["glow"] = true
		"High":
			settings["graphics"]["fxaa"] = false
			settings["graphics"]["taa"] = false
			settings["graphics"]["msaa"] = 2
			settings["graphics"]["scaling_mode"] = Viewport.SCALING_3D_MODE_FSR2
			settings["graphics"]["fsr_scale"] = 1.0
			settings["graphics"]["shadow_quality"] = 2
			settings["graphics"]["ssao"] = true
			settings["graphics"]["ssil"] = true
			settings["graphics"]["ssr"] = true
			settings["graphics"]["glow"] = true
		"Ultra":
			settings["graphics"]["fxaa"] = false
			settings["graphics"]["taa"] = false
			settings["graphics"]["msaa"] = 4
			settings["graphics"]["scaling_mode"] = Viewport.SCALING_3D_MODE_FSR2
			settings["graphics"]["fsr_scale"] = 1.0
			settings["graphics"]["shadow_quality"] = 3
			settings["graphics"]["ssao"] = true
			settings["graphics"]["ssil"] = true
			settings["graphics"]["ssr"] = true
			settings["graphics"]["glow"] = true

func get_setting(category: String, key: String):
	return settings[category][key]

func set_setting(category: String, key: String, value):
	settings[category][key] = value
	if category != "preset":
		settings["preset"] = "Custom"
