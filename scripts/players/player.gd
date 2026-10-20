extends CharacterBody3D

const SPEED = 6.5
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
var character_path: String = "res://assets/characters/Blank_Character/Blank_Character.glb"
var character_color: Color = Color(0.95, 0.95, 0.95)
var character_face: String = "res://assets/characters/face/robloxmanface.png"
var character_hat: String = ""

# Hot Bomb Minigame state
var is_holding_bomb: bool = false
var is_dead_in_minigame: bool = false
var held_bomb: Node = null

# Network Interpolation
var target_pos: Vector3 = Vector3.ZERO
var target_rot_y: float = 0.0
var has_synced_pos: bool = false

func set_character_color(col: Color) -> void:
	character_color = col
	_apply_character_color()

func set_character_face(face_path: String) -> void:
	character_face = face_path if face_path != "" else "res://assets/characters/face/robloxmanface.png"
	_apply_character_color()

func set_character_hat(hat_path: String) -> void:
	character_hat = hat_path
	_apply_character_hat()

func set_character_customization(col: Color, face_path: String, hat_path: String = "") -> void:
	character_color = col
	character_face = face_path if face_path != "" else "res://assets/characters/face/robloxmanface.png"
	character_hat = hat_path
	_apply_character_color()
	_apply_character_hat()

@rpc("any_peer", "call_local", "reliable")
func sync_character_color(col: Color) -> void:
	character_color = col
	_apply_character_color()

@rpc("any_peer", "call_local", "reliable")
func sync_character_face(face_path: String) -> void:
	character_face = face_path if face_path != "" else "res://assets/characters/face/robloxmanface.png"
	_apply_character_color()

@rpc("any_peer", "call_local", "reliable")
func sync_character_hat(hat_path: String) -> void:
	character_hat = hat_path
	_apply_character_hat()

@rpc("any_peer", "call_local", "reliable")
func sync_character_customization(col: Color, face_path: String, hat_path: String = "") -> void:
	character_color = col
	character_face = face_path if face_path != "" else "res://assets/characters/face/robloxmanface.png"
	character_hat = hat_path
	_apply_character_color()
	_apply_character_hat()

func _apply_character_color() -> void:
	if not model:
		return
	_apply_color_recursive(model, character_color)
	_apply_face_recursive(model, character_face, character_color)

func _apply_face_recursive(node: Node, face_path: String, col: Color) -> void:
	if node.name == "HeadAttachment" or node.name == "Hat":
		return
	if face_path == "":
		face_path = "res://assets/characters/face/robloxmanface.png"
	if node is MeshInstance3D and node.name == "Blank_Head":
		var m: Mesh = node.mesh
		if m and m.get_surface_count() > 1:
			var mat: StandardMaterial3D = node.get_surface_override_material(1) as StandardMaterial3D
			if not mat:
				mat = StandardMaterial3D.new()
			if ResourceLoader.exists(face_path):
				var tex = load(face_path) as Texture2D
				if tex:
					mat.albedo_texture = tex
			mat.albedo_color = col
			mat.roughness = 0.5
			node.set_surface_override_material(1, mat)
			return
	for child in node.get_children():
		_apply_face_recursive(child, face_path, col)

func _apply_color_recursive(node: Node, col: Color) -> void:
	if node.name == "HeadAttachment" or node.name == "Hat":
		return
	if node is MeshInstance3D:
		var m: Mesh = node.mesh
		if m:
			for s in range(m.get_surface_count()):
				if node.name == "Blank_Head" and s == 1:
					continue
				var mat = node.get_surface_override_material(s)
				if mat is StandardMaterial3D:
					mat.albedo_color = col
					mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				else:
					var new_mat := StandardMaterial3D.new()
					new_mat.albedo_color = col
					new_mat.roughness = 0.5
					new_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
					node.set_surface_override_material(s, new_mat)
	for child in node.get_children():
		_apply_color_recursive(child, col)

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
	target_pos = new_pos
	target_rot_y = rot_y
	if not has_synced_pos or position.distance_squared_to(new_pos) > 16.0:
		position = new_pos
		has_synced_pos = true
		if model:
			model.rotation.y = rot_y
	if anim_name and anim_name != current_anim:
		play_anim(anim_name)

func _process(delta: float) -> void:
	if not is_inside_tree():
		return
	var has_peer = multiplayer and multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	var has_authority = is_multiplayer_authority() if has_peer else true
	if not has_authority and has_synced_pos:
		position = position.lerp(target_pos, 25.0 * delta)
		if model:
			model.rotation.y = lerp_angle(model.rotation.y, target_rot_y, 25.0 * delta)

func _safe_wait_animation(anim_name: String, fallback_duration: float = 0.5) -> void:
	if not is_inside_tree():
		return
	var duration: float = fallback_duration
	if anim_player and anim_player.has_animation(anim_name):
		var anim = anim_player.get_animation(anim_name)
		if anim and anim.length > 0.0:
			var speed_scale_val = max(0.1, abs(anim_player.speed_scale))
			duration = (anim.length / speed_scale_val) + 0.05

	var timer = get_tree().create_timer(duration)
	while is_inside_tree() and timer.time_left > 0.0:
		if not anim_player or not anim_player.is_playing() or anim_player.current_animation != anim_name:
			break
		await get_tree().process_frame

func apply_knockback(push_dir: Vector3) -> void:
	knockback_velocity = push_dir.normalized() * 5.0
	if is_knocked_down:
		return
	is_knocked_down = true
	is_pushing = false
	velocity = Vector3.ZERO
	if AudioManager:
		AudioManager.play_kick_hit(global_position)
		AudioManager.play_knockback_fall(global_position)
	play_anim("simulation/Sit_Floor_Down")
	await _safe_wait_animation("simulation/Sit_Floor_Down", 0.6)
	if not is_inside_tree() or is_dead_in_minigame:
		is_knocked_down = false
		return
	play_anim("simulation/Sit_Floor_StandUp")
	await _safe_wait_animation("simulation/Sit_Floor_StandUp", 0.6)
	is_knocked_down = false
	if is_inside_tree() and not is_dead_in_minigame:
		if is_holding_bomb:
			play_anim("hot_bomb/Holding_A")
		else:
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
	if AudioManager:
		AudioManager.play_kick_whoosh(global_position)
	
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
		await _safe_wait_animation("combat/Melee_Unarmed_Attack_Kick", 0.6)
	else:
		await get_tree().create_timer(1.0).timeout
	is_pushing = false
	push_cooldown = 0.0
	if not is_knocked_down and not is_dead_in_minigame and current_anim == "combat/Melee_Unarmed_Attack_Kick":
		if is_holding_bomb:
			play_anim("hot_bomb/Holding_A")
		else:
			play_anim("general/Idle_A")

func _physics_process(delta):
	if not is_inside_tree():
		return
	_ensure_nodes()
	var has_peer = multiplayer and multiplayer.multiplayer_peer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	var has_authority = is_multiplayer_authority() if has_peer else true

	if has_authority:
		# Skip input handling if dead, but still sync state at the end
		if not is_dead_in_minigame:
			if push_cooldown > 0.0:
				push_cooldown -= delta

			if not is_on_floor():
				velocity.y -= gravity * delta
			else:
				velocity.y = -0.1

			if Input.is_action_just_pressed("push") and not is_knocked_down:
				perform_push()

			# Throw bomb with throw_bomb action
			if Input.is_action_just_pressed("throw_bomb") and is_holding_bomb and not is_knocked_down:
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
						play_anim("movement/Running_B")

				else:
					velocity.x = move_toward(velocity.x, 0, SPEED)
					velocity.z = move_toward(velocity.z, 0, SPEED)
					if is_holding_bomb:
						play_anim("hot_bomb/Holding_A")
					else:
						play_anim("general/Idle_A")

			move_and_slide()

		# Always sync state, even when dead (for death animation)
		if has_peer:
			var rot_y: float = model.rotation.y if model else 0.0
			var main_node = get_parent()
			if main_node and is_instance_valid(main_node) and main_node.is_inside_tree() and main_node.has_method("sync_player_state"):
				if ("is_returning" in main_node and main_node.is_returning) or ("is_starting" in main_node and main_node.is_starting) or ("is_switching_round" in main_node and main_node.is_switching_round):
					pass
				else:
					var my_id = multiplayer.get_unique_id()
					var target_peers = main_node.synced_peers if ("synced_peers" in main_node) else (main_node.players if ("players" in main_node) else {})
					for pid in target_peers:
						if pid != my_id:
							main_node.sync_player_state.rpc_id(pid, my_id, position, rot_y, current_anim)

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
				if move_lib.has_animation("Running_B"):
					move_lib.get_animation("Running_B").loop_mode = Animation.LOOP_LINEAR
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
				if hb_lib.has_animation("Running_HoldingRifle"):
					hb_lib.get_animation("Running_HoldingRifle").loop_mode = Animation.LOOP_LINEAR
				if hb_lib.has_animation("Holding_A"):
					hb_lib.get_animation("Holding_A").loop_mode = Animation.LOOP_LINEAR
				anim_player.add_animation_library("hot_bomb", hb_lib)
	_setup_hand_socket()
	_setup_head_socket()
	if is_multiplayer_authority():
		character_color = GameSession.selected_color
		character_face = GameSession.selected_face
		character_hat = GameSession.selected_hat
		set_character_customization(GameSession.selected_color, GameSession.selected_face, GameSession.selected_hat)
	else:
		_apply_character_color()
		_apply_character_hat()
	play_anim("general/Idle_A")

func play_anim(anim_name: String, force_restart: bool = false):
	_ensure_nodes()
	if anim_player and anim_player.has_animation(anim_name):
		if current_anim != anim_name or force_restart:
			anim_player.stop()
			anim_player.play(anim_name)
			current_anim = anim_name

func _clear_materials_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var m: Mesh = node.mesh
		if m:
			for s in range(m.get_surface_count()):
				node.set_surface_override_material(s, null)
	for child in node.get_children():
		_clear_materials_recursive(child)

func switch_character(glb_path: String) -> void:
	_ensure_nodes()
	if glb_path == "":
		return
	if model and is_instance_valid(model) and character_path == glb_path:
		return
	print("[PLAYER %s] switch_character called with path: %s" % [name, glb_path])
	character_path = glb_path
	if model:
		print("[PLAYER %s] Removing old model: %s" % [name, model.name])
		_clear_materials_recursive(model)
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
	_setup_head_socket()
	_apply_character_color()
	_apply_character_hat()
	play_anim("general/Idle_A")

func _setup_head_socket() -> BoneAttachment3D:
	if not model:
		return null
	var skel: Skeleton3D = model.get_node_or_null("Rig_Medium/Skeleton3D")
	if not skel:
		return null
	var existing = skel.get_node_or_null("HeadAttachment")
	if not existing:
		var ba = BoneAttachment3D.new()
		ba.name = "HeadAttachment"
		ba.bone_name = "head"
		skel.add_child(ba)
		return ba
	return existing

func _apply_character_hat() -> void:
	var socket = _setup_head_socket()
	if not socket:
		return
	for child in socket.get_children():
		_clear_materials_recursive(child)
		socket.remove_child(child)
		child.queue_free()
	if character_hat != "" and ResourceLoader.exists(character_hat):
		var hat_scene = load(character_hat)
		if hat_scene:
			var hat_instance = hat_scene.instantiate()
			hat_instance.name = "Hat"
			socket.add_child(hat_instance)
			hat_instance.position = Vector3(0, 0.78, 0)

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
	if AudioManager:
		AudioManager.play_bomb_catch(global_position)

func release_bomb() -> void:
	is_holding_bomb = false
	held_bomb = null
	play_anim("general/Idle_A", true)

func throw_held_bomb() -> void:
	if not is_holding_bomb or is_knocked_down or is_dead_in_minigame:
		return

	var direction = model.global_transform.basis.z if model else global_transform.basis.z
	direction.y = 0.0
	direction = direction.normalized()

	play_anim("hot_bomb/Throw", true)
	if AudioManager:
		AudioManager.play_bomb_throw(global_position)

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
	is_knocked_down = false
	is_pushing = false
	is_holding_bomb = false
	held_bomb = null
	velocity = Vector3.ZERO

	# Disable collision
	var col = get_node_or_null("CollisionShape3D")
	if col:
		col.disabled = true

	play_anim("hot_bomb/Skeletons_Death", true)
	if AudioManager:
		AudioManager.play_player_death(global_position)
	print("[PLAYER] %s died in minigame" % name)

	# Keep physics_process running briefly to sync death animation
	await get_tree().create_timer(0.5).timeout
	set_physics_process(false)
