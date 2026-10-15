extends CharacterBody3D

const SPEED = 5.0
const ROTATION_SPEED = 10.0
var gravity = 9.8

@onready var model: Node3D = $Model
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var current_anim: String = ""

func _ensure_nodes():
	if not model:
		model = get_node_or_null("Model")
	if not anim_player:
		anim_player = get_node_or_null("AnimationPlayer")

func _apply_state(new_pos: Vector3, rot_y: float, anim_name: String) -> void:
	position = new_pos
	if model:
		model.rotation.y = rot_y
	if anim_name and anim_name != current_anim:
		play_anim(anim_name)

@rpc("any_peer", "unreliable")
func sync_state_to_peer(new_pos: Vector3, rot_y: float, anim_name: String) -> void:
	if is_multiplayer_authority():
		return
	_apply_state(new_pos, rot_y, anim_name)

func _physics_process(delta):
	_ensure_nodes()
	if multiplayer.multiplayer_peer == null:
		return
	
	var has_authority = is_multiplayer_authority()
	
	if has_authority:
		if not is_on_floor():
			velocity.y -= gravity * delta

		var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if input_dir == Vector2.ZERO:
			if Input.is_key_pressed(KEY_W):
				input_dir.y -= 1
			if Input.is_key_pressed(KEY_S):
				input_dir.y += 1
			if Input.is_key_pressed(KEY_A):
				input_dir.x -= 1
			if Input.is_key_pressed(KEY_D):
				input_dir.x += 1
			input_dir = input_dir.normalized()

		var direction = Vector3(input_dir.x, 0, input_dir.y)

		if direction != Vector3.ZERO:
			velocity.x = direction.x * SPEED
			velocity.z = direction.z * SPEED
			if model:
				var target_rotation = atan2(direction.x, direction.z)
				model.rotation.y = lerp_angle(model.rotation.y, target_rotation, ROTATION_SPEED * delta)
			play_anim("movement/Walking_A")
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			velocity.z = move_toward(velocity.z, 0, SPEED)
			play_anim("general/Idle_A")

		move_and_slide()
		if multiplayer.multiplayer_peer != null:
			var rot_y: float = model.rotation.y if model else 0.0
			sync_state_to_peer.rpc(position, rot_y, current_anim)

func _ready():
	_ensure_nodes()
	# Camera is managed by main.tscn, not here
	if anim_player:
		if not anim_player.has_animation_library("movement"):
			var move_lib = load("res://assets/animations/movement_animations.res")
			if move_lib:
				anim_player.add_animation_library("movement", move_lib)
		if not anim_player.has_animation_library("general"):
			var gen_lib = load("res://assets/animations/general_animations.res")
			if gen_lib:
				anim_player.add_animation_library("general", gen_lib)
	play_anim("general/Idle_A")

func play_anim(anim_name: String):
	_ensure_nodes()
	if anim_player and current_anim != anim_name and anim_player.has_animation(anim_name):
		anim_player.play(anim_name)
		current_anim = anim_name

func switch_character(glb_path: String):
	_ensure_nodes()
	if model:
		model.queue_free()
	var new_scene = load(glb_path)
	if not new_scene:
		return
	var new_model = new_scene.instantiate()
	new_model.name = "Model"
	add_child(new_model)
	model = new_model
	if anim_player:
		anim_player.root_node = anim_player.get_path_to(model)
	current_anim = ""
	await get_tree().process_frame
	play_anim("general/Idle_A")
