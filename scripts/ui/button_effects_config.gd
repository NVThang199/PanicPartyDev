extends Node
class_name ButtonEffectsModule
@export_category("🔠 Font")
@export var custom_font: Font
@export var font_size: int = 16
@export var font_color: Color = Color.WHITE
@export_category("🎬 Animation")
@export var ease_type: Tween.EaseType
@export var trans_type: Tween.TransitionType
@export var anim_duration: float = 0.1
@export var scale_amount: Vector2 = Vector2(1.2,1.2)
@export var rotation_amount: float = 5.0
@export var pulse_on_idle: bool = false
@export var pulse_scale: Vector2 = Vector2(1.05, 1.05)
@export var pulse_duration: float = 0.5
@export_category("🔊 Sound")
@export var sound_pressed_button: AudioStream
@export var sound_hovered_button: AudioStream
@export_category("🎨 Color")
@export var hover_modulate: Color = Color(1.2, 1.2, 1.2, 1.0) 


@onready var button: Button = get_parent()

var tween: Tween
var sound_player: AudioStreamPlayer
var idle_tween: Tween
var normal_modulate: Color = Color.WHITE
func _ready() -> void:
	_apply_font_settings()
	sound_player = AudioStreamPlayer.new()
	add_child(sound_player)
	
	button.mouse_entered.connect(_on_mouse_hovered.bind(true))
	button.mouse_exited.connect(_on_mouse_hovered.bind(false))
	button.pressed.connect(_on_button_pressed)
	button.pivot_offset_ratio = Vector2(0.5,0.5)
	
	if pulse_on_idle and not button.mouse_entered.is_connected(_stop_pulse):
		button.mouse_entered.connect(_stop_pulse)
		button.mouse_exited.connect(_start_pulse)
		_start_pulse()

func _on_button_pressed() -> void:
	reset_tween()
	tween.tween_property(button, "scale", scale_amount, anim_duration).from(Vector2(0.8,0.8))
	tween.tween_property(button, "rotation_degrees", rotation_amount * [-1, 1].pick_random(), anim_duration).from(0)
	if sound_pressed_button:
		sound_player.stream = sound_pressed_button
		sound_player.play()


func _on_mouse_hovered(hovered: bool) -> void:
	reset_tween()
	tween.tween_property(button, "scale", scale_amount if hovered else Vector2.ONE, anim_duration)
	tween.tween_property(button, "rotation_degrees", rotation_amount * [-1, 1].pick_random() if hovered else 0.0, anim_duration)
	if sound_hovered_button:
		if hovered == true:
			sound_player.stream = sound_hovered_button
			sound_player.play()
	button.modulate = hover_modulate if hovered else normal_modulate

func reset_tween() -> void:
	if tween:
		tween.kill()
	tween = create_tween().set_ease(ease_type).set_trans(trans_type).set_parallel(true)


func _start_pulse():
	if idle_tween:
		idle_tween.kill()
	idle_tween = create_tween().set_loops()
	idle_tween.tween_property(button, "scale", pulse_scale, pulse_duration).from(Vector2.ONE)
	idle_tween.tween_property(button, "scale", Vector2.ONE, pulse_duration)

func _stop_pulse():
	if idle_tween:
		idle_tween.kill()
	button.scale = Vector2.ONE

func _apply_font_settings() -> void:
	if custom_font:
		var theme = Theme.new()
		theme.set_font("font", "Button", custom_font)
		button.add_theme_font_override("font", custom_font)
	
	if font_size > 0:
		button.add_theme_font_size_override("font_size", font_size)
	
	if font_color != Color.WHITE:
		button.add_theme_color_override("font_color", font_color)
