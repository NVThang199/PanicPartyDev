extends CharacterBody3D

const SPEED = 5.0
const ROTATION_SPEED = 10.0
const PUSH_RANGE = 2.2
const PUSH_COOLDOWN_TIME = 0.0
var gravity = 9.8

@onready var model: Node3D = $Model
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var name_label: Label3D = $NameLabel

var current_anim: String = ""
var push_cooldown: float = 0.0
var is_pushing: bool = false
var is_knocked_down: bool = false
var knockback_velocity: Vector3 = Vector3.ZERO
var player_name: String = ""
var steam_id: int = 0
var ping_ms: int = 0
var character_path: String = ""

# Hot Bomb Minigame state
var is_holding_bomb: bool = false
var is_dead_in_minigame: bool = false
var held_bomb: Node = null

func set_player_name(p_name: String) -> void:
	player_name = p_name
	if not name_label:
		name_label = get_node_or_null("NameLabel")
	if name_label:
		name_label.text = p_name
		name_label.modulate = Color(1, 1, 1, 1)

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

func apply_knockback(push_dir: Vector3) -> void:
	knockback_velocity = push_dir.normalized() * 5.0
	if is_knocked_down:
		return
	is_knocked_down = true
	is_pushing = false
	velocity = Vector3.ZERO
	play_anim("simulation/Sit_Floor_Down")
	if anim_player:
		await anim_player.animation_finished
	play_anim("simulation/Sit_Floor_StandUp")
	if anim_player:
		await anim_player.animation_finished
	is_knocked_down = false
	play_anim("general/Idle_A")

func _find_push_target() -> Node:
	var main_node = get_parent()
	if not main_node or not ("players" in main_node):
		return null
	var forward = model.global_transform.basis.z if model else global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	
	var closest_target: Node = null
	var min_dist = PUSH_RANGE
	for pid in main_node.players:
		if pid == multiplayer.get_unique_id():
			continue
		var other = main_node.players[pid]
		if not is_instance_valid(other):
			continue
		var to_other = other.global_position - global_position
		to_other.y = 0.0
		var dist = to_other.length()
		if dist <= PUSH_RANGE and dist > 0.001:
			var dir = to_other.normalized()
			if forward.dot(dir) > 0.1 or dist < 0.8:
				if dist < min_dist:
					min_dist = dist
					closest_target = other
	return closest_target

func perform_push() -> void:
	if is_pushing or is_knocked_down or push_cooldown > 0.0:
		return
	is_pushing = true
	push_cooldown = PUSH_COOLDOWN_TIME
	play_anim("combat/Melee_Unarmed_Attack_Kick", true)
	
	var target = _find_push_target()
	if target:
		var push_dir = (target.global_position - global_position)
		push_dir.y = 0.0
		if push_dir.length_squared() < 0.001:
			push_dir = model.global_transform.basis.z if model else global_transform.basis.z
			push_dir.y = 0.0
		push_dir = push_dir.normalized()
		var target_id = int(str(target.name))
		print("[PUSH] perform_push found target %d (is_server=%s)" % [target_id, multiplayer.is_server()])
		var main_node = get_parent()
		if main_node and is_instance_valid(main_node) and main_node.is_inside_tree():
			if multiplayer.is_server():
				if target_id == multiplayer.get_unique_id():
					target.apply_knockback(push_dir)
				else:
					main_node.apply_knockback_rpc.rpc_id(target_id, push_dir)
			else:
				main_node.request_push.rpc_id(1, target_id, push_dir)
	else:
		print("[PUSH] perform_push: No target found in front")
			
	if anim_player:
		await anim_player.animation_finished
	else:
		await get_tree().create_timer(1.0).timeout
	is_pushing = false
	push_cooldown = 0.0
	if not is_knocked_down and current_anim == "combat/Melee_Unarmed_Attack_Kick":
		play_anim("general/Idle_A")

func _physics_process(delta):
	if not is_inside_tree():
		return
	_ensure_nodes()
	if multiplayer.multiplayer_peer == null:
		return

	var has_authority = is_multiplayer_authority()

	if has_authority:
		# Skip input handling if dead, but still sync state at the end
		if not is_dead_in_minigame:
			if push_cooldown > 0.0:
				push_cooldown -= delta

			if not is_on_floor():
				velocity.y -= gravity * delta

			if Input.is_key_pressed(KEY_E):
				perform_push()

			# Throw bomb with F key
			if (Input.is_action_just_pressed("throw_bomb") or Input.is_key_pressed(KEY_F)) and is_holding_bomb:
				throw_held_bomb()

			if is_knocked_down:
				velocity.x = knockback_velocity.x
				velocity.z = knockback_velocity.z
				knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, 15.0 * delta)
			elif is_pushing:
				velocity.x = move_toward(velocity.x, 0, SPEED)
				velocity.z = move_toward(velocity.z, 0, SPEED)
			else:
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
					if is_holding_bomb:
						play_anim("hot_bomb/Running_HoldingRifle")
					else:
						play_anim("movement/Walking_A")
				else:
					velocity.x = move_toward(velocity.x, 0, SPEED)
					velocity.z = move_toward(velocity.z, 0, SPEED)
					if is_holding_bomb:
						play_anim("hot_bomb/Holding_A")
					else:
						play_anim("general/Idle_A")

			move_and_slide()

		# Always sync state, even when dead (for death animation)
		if multiplayer.multiplayer_peer != null:
			var rot_y: float = model.rotation.y if model else 0.0
			var main_node = get_parent()
			if main_node and is_instance_valid(main_node) and main_node.is_inside_tree() and main_node.has_method("sync_player_state"):
				main_node.sync_player_state.rpc(multiplayer.get_unique_id(), position, rot_y, current_anim)

func _ready():
	_ensure_nodes()
	if not name_label:
		name_label = get_node_or_null("NameLabel")
	if name_label:
		if player_name != "":
			name_label.text = player_name
		name_label.modulate = Color(1, 1, 1, 1)
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
		if not anim_player.has_animation_library("combat"):
			var combat_lib = load("res://assets/animations/combat_animations.res")
			if combat_lib:
				anim_player.add_animation_library("combat", combat_lib)
		if not anim_player.has_animation_library("simulation"):
			var sim_lib = load("res://assets/animations/simulation_animations.res")
			if sim_lib:
				anim_player.add_animation_library("simulation", sim_lib)
		if not anim_player.has_animation_library("hot_bomb"):
			var hb_lib = load("res://assets/animations/hot_bomb_animations.res")
			if hb_lib:
				anim_player.add_animation_library("hot_bomb", hb_lib)
	_setup_hand_socket()
	play_anim("general/Idle_A")

func play_anim(anim_name: String, force_restart: bool = false):
	_ensure_nodes()
	if anim_player and anim_player.has_animation(anim_name):
		if current_anim != anim_name or force_restart:
			anim_player.stop()
			anim_player.play(anim_name)
			current_anim = anim_name

func switch_character(glb_path: String) -> void:
	print("[PLAYER %s] switch_character called with path: %s" % [name, glb_path])
	_ensure_nodes()
	character_path = glb_path
	if model:
		print("[PLAYER %s] Removing old model: %s" % [name, model.name])
		remove_child(model)
		model.queue_free()
	var new_scene = load(glb_path)
	if not new_scene:
		print("[PLAYER %s] ERROR: Failed to load scene from %s" % [name, glb_path])
		return
	print("[PLAYER %s] Scene loaded, instantiating..." % name)
	var new_model = new_scene.instantiate()
	new_model.name = "Model"
	add_child(new_model)
	model = new_model
	print("[PLAYER %s] New model added: %s" % [name, glb_path])
	if anim_player:
		anim_player.root_node = anim_player.get_path_to(model)
	current_anim = ""
	if is_inside_tree():
		await get_tree().process_frame
	_setup_hand_socket()
	play_anim("general/Idle_A")

func _setup_hand_socket() -> void:
	if not model:
		return
	var skel: Skeleton3D = model.get_node_or_null("Rig_Medium/Skeleton3D")
	if not skel:
		return
	var existing = skel.get_node_or_null("RightHandAttachment")
	if not existing:
		var ba = BoneAttachment3D.new()
		ba.name = "RightHandAttachment"
		ba.bone_name = "handslot.r"
		skel.add_child(ba)

func get_hand_socket() -> Node3D:
	if model:
		var ba = model.get_node_or_null("Rig_Medium/Skeleton3D/RightHandAttachment")
		if ba:
			return ba
	_setup_hand_socket()
	if model:
		return model.get_node_or_null("Rig_Medium/Skeleton3D/RightHandAttachment")
	return null

# Hot Bomb Minigame Methods
func pick_up_bomb(b: Node) -> void:
	is_holding_bomb = true
	held_bomb = b
	play_anim("hot_bomb/Holding_A", true)

func release_bomb() -> void:
	is_holding_bomb = false
	held_bomb = null
	play_anim("general/Idle_A", true)

func throw_held_bomb() -> void:
	if not is_holding_bomb:
		return

	var direction = model.global_transform.basis.z if model else global_transform.basis.z
	direction.y = 0.0
	direction = direction.normalized()

	play_anim("hot_bomb/Throw", true)

	var minigame = get_parent()
	if minigame and is_instance_valid(minigame) and minigame.is_inside_tree():
		if multiplayer.is_server():
			if minigame.has_method("throw_bomb"):
				minigame.throw_bomb(multiplayer.get_unique_id(), direction)
		else:
			if minigame.has_method("request_throw_bomb"):
				minigame.request_throw_bomb.rpc_id(1, direction)

	is_holding_bomb = false
	held_bomb = null

func die_in_minigame() -> void:
	is_dead_in_minigame = true
	is_holding_bomb = false
	held_bomb = null
	velocity = Vector3.ZERO

	# Disable collision
	var col = get_node_or_null("CollisionShape3D")
	if col:
		col.disabled = true

	play_anim("hot_bomb/Skeletons_Death", true)
	print("[PLAYER] %s died in minigame" % name)

	# Keep physics_process running briefly to sync death animation
	await get_tree().create_timer(0.5).timeout
	set_physics_process(false)
