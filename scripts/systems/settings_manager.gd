extends Node
# Quản lý settings đồ họa, display, audio và keybinds

signal settings_changed
signal keybinds_changed

const SAVE_PATH = "user://settings.cfg"

const REBINDABLE_ACTIONS = [
	"move_forward",
	"move_backward",
	"move_left",
	"move_right",
	"push",
	"throw_bomb"
]

const DEFAULT_KEYS = {
	"move_forward": KEY_W,
	"move_backward": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"push": KEY_E,
	"throw_bomb": KEY_F
}

var settings = {
	"preset": "Medium",
	"display": {
		"language": "en",
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
		"fsr_sharpness": 0.2,
		"shadow_quality": 1,
		"ssao": true,
		"ssil": false,
		"ssr": false,
		"glow": true
	},
	"audio": {
		"master_volume": 1.0,
		"music_volume": 0.8,
		"sfx_volume": 0.8,
		"output_device": "Default",
		"speaker_mode": "Stereo"
	},
	"keybinds": {}
}

func _ready():
	_ensure_audio_buses()
	_init_default_keybinds()
	load_settings()
	apply_settings()

func _ensure_audio_buses():
	if AudioServer.get_bus_index("Music") == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "Music")
		AudioServer.set_bus_send(idx, "Master")
	if AudioServer.get_bus_index("SFX") == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")

func _init_default_keybinds():
	for action in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		if not settings["keybinds"].has(action):
			settings["keybinds"][action] = DEFAULT_KEYS.get(action, KEY_NONE)

func load_settings():
	var config = ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		settings["preset"] = config.get_value("general", "preset", "Medium")
		for key in settings["display"]:
			settings["display"][key] = config.get_value("display", key, settings["display"][key])
		settings["display"]["language"] = config.get_value("display", "language", "en")
		for key in settings["graphics"]:
			settings["graphics"][key] = config.get_value("graphics", key, settings["graphics"][key])
		for key in settings["audio"]:
			settings["audio"][key] = config.get_value("audio", key, settings["audio"][key])
		for action in REBINDABLE_ACTIONS:
			if config.has_section_key("keybinds", action):
				settings["keybinds"][action] = config.get_value("keybinds", action)

func save_settings():
	var config = ConfigFile.new()
	config.set_value("general", "preset", settings["preset"])
	for key in settings["display"]:
		config.set_value("display", key, settings["display"][key])
	for key in settings["graphics"]:
		config.set_value("graphics", key, settings["graphics"][key])
	for key in settings["audio"]:
		config.set_value("audio", key, settings["audio"][key])
	for action in settings["keybinds"]:
		config.set_value("keybinds", action, settings["keybinds"][action])
	config.save(SAVE_PATH)

func apply_settings():
	# Language / Locale
	var lang = settings["display"].get("language", "en")
	TranslationServer.set_locale(lang)

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
	viewport.fsr_sharpness = settings["graphics"].get("fsr_sharpness", 0.2)
	viewport.use_taa = settings["graphics"]["taa"]
	viewport.msaa_3d = settings["graphics"]["msaa"]

	# Shadows: Cap atlas size to 2048 to prevent severe VRAM/compute drop on Ultra
	var shadow_q = settings["graphics"].get("shadow_quality", 1)
	var atlas_size = 2048 if shadow_q >= 2 else (1024 if shadow_q == 1 else 512)
	RenderingServer.directional_shadow_atlas_set_size(atlas_size, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(mini(shadow_q, 2))

	var world_3d = viewport.get_world_3d()
	if world_3d and world_3d.environment:
		var env = world_3d.environment
		env.ssao_enabled = settings["graphics"]["ssao"]
		env.ssil_enabled = settings["graphics"]["ssil"]
		env.ssr_enabled = settings["graphics"]["ssr"]
		env.glow_enabled = settings["graphics"]["glow"]
		env.volumetric_fog_enabled = false

	# Audio Settings
	apply_audio_settings()

	# Keybind Settings
	apply_keybind_settings()

	settings_changed.emit()

func apply_audio_settings():
	_ensure_audio_buses()
	_set_bus_vol("Master", settings["audio"]["master_volume"])
	_set_bus_vol("Music", settings["audio"]["music_volume"])
	_set_bus_vol("SFX", settings["audio"]["sfx_volume"])

	# Output device
	var dev = settings["audio"].get("output_device", "Default")
	if dev != "" and dev in AudioServer.get_output_device_list():
		AudioServer.set_output_device(dev)

	# Speaker mode: Stereo vs Mono (Master Bus StereoEnhance Effect)
	var master_idx = AudioServer.get_bus_index("Master")
	if master_idx != -1:
		var is_mono = settings["audio"].get("speaker_mode", "Stereo") == "Mono"
		var effect_found = false
		for i in range(AudioServer.get_bus_effect_count(master_idx)):
			var effect = AudioServer.get_bus_effect(master_idx, i)
			if effect is AudioEffectStereoEnhance:
				effect.pan_pullout = 0.0 if is_mono else 1.0
				AudioServer.set_bus_effect_enabled(master_idx, i, is_mono)
				effect_found = true
				break
		if not effect_found and is_mono:
			var mono_effect = AudioEffectStereoEnhance.new()
			mono_effect.pan_pullout = 0.0
			AudioServer.add_bus_effect(master_idx, mono_effect)

func _set_bus_vol(bus_name: String, vol_linear: float):
	var idx = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	if vol_linear <= 0.001:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(vol_linear))

func apply_keybind_settings():
	for action in settings["keybinds"]:
		var keycode: int = settings["keybinds"][action]
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		# Clear ALL existing events for this action so old WASD/Arrow bindings are removed completely
		InputMap.action_erase_events(action)
		if keycode != KEY_NONE and keycode != 0:
			var new_ev = InputEventKey.new()
			new_ev.physical_keycode = keycode as Key
			new_ev.keycode = keycode as Key
			InputMap.action_add_event(action, new_ev)
	keybinds_changed.emit()

func remap_action_key(action: String, new_keycode: int):
	settings["keybinds"][action] = new_keycode
	apply_keybind_settings()

func apply_preset(preset_name: String):
	settings["preset"] = preset_name
	match preset_name:
		"Low":
			settings["graphics"]["fxaa"] = false
			settings["graphics"]["taa"] = false
			settings["graphics"]["msaa"] = 0
			settings["graphics"]["scaling_mode"] = Viewport.SCALING_3D_MODE_BILINEAR
			settings["graphics"]["fsr_scale"] = 1.0
			settings["graphics"]["fsr_sharpness"] = 0.2
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
			settings["graphics"]["fsr_sharpness"] = 0.2
			settings["graphics"]["shadow_quality"] = 1
			settings["graphics"]["ssao"] = true
			settings["graphics"]["ssil"] = false
			settings["graphics"]["ssr"] = false
			settings["graphics"]["glow"] = true
		"High":
			settings["graphics"]["fxaa"] = false
			settings["graphics"]["taa"] = true
			settings["graphics"]["msaa"] = 1
			settings["graphics"]["scaling_mode"] = Viewport.SCALING_3D_MODE_BILINEAR
			settings["graphics"]["fsr_scale"] = 1.0
			settings["graphics"]["fsr_sharpness"] = 0.2
			settings["graphics"]["shadow_quality"] = 2
			settings["graphics"]["ssao"] = true
			settings["graphics"]["ssil"] = false
			settings["graphics"]["ssr"] = true
			settings["graphics"]["glow"] = true
		"Ultra":
			# Native rendering (FSR Disabled by default to prevent blur/ghosting), TAA enabled, shadow quality 2
			settings["graphics"]["fxaa"] = false
			settings["graphics"]["taa"] = true
			settings["graphics"]["msaa"] = 2
			settings["graphics"]["scaling_mode"] = Viewport.SCALING_3D_MODE_BILINEAR
			settings["graphics"]["fsr_scale"] = 1.0
			settings["graphics"]["fsr_sharpness"] = 0.2
			settings["graphics"]["shadow_quality"] = 2
			settings["graphics"]["ssao"] = true
			settings["graphics"]["ssil"] = false
			settings["graphics"]["ssr"] = true
			settings["graphics"]["glow"] = true

func get_setting(category: String, key: String):
	return settings[category][key]

func set_setting(category: String, key: String, value):
	settings[category][key] = value
	if category != "preset" and category != "audio" and category != "keybinds":
		settings["preset"] = "Custom"
