extends StaticBody3D

enum TileColor { GREEN, RED }

var tile_color: TileColor = TileColor.GREEN
var is_dropping: bool = false
var original_position: Vector3 = Vector3.ZERO

@onready var green_model: Node3D = get_node_or_null("GreenModel")
@onready var red_model: Node3D = get_node_or_null("RedModel")
@onready var collision: CollisionShape3D = get_node_or_null("CollisionShape3D")

func _ready() -> void:
	original_position = global_position
	set_color(tile_color)

func set_color(color: TileColor) -> void:
	tile_color = color
	if green_model:
		green_model.visible = color == TileColor.GREEN
	if red_model:
		red_model.visible = color == TileColor.RED

func drop() -> void:
	if is_dropping:
		return

	is_dropping = true
	if AudioManager:
		AudioManager.play_tile_fall(global_position)
	if collision:
		collision.set_deferred("disabled", true)

	var tween = create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(self, "global_position", original_position + Vector3(0, -2, 0), 0.5)
	await tween.finished

func reset() -> void:
	is_dropping = false
	global_position = original_position
	if collision:
		collision.disabled = false
	set_color(tile_color)
