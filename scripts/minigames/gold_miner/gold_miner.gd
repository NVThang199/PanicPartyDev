class_name GoldMiner
extends BaseMinigame

## GoldMiner - Minigame Đào Vàng 3D Server-Authoritative
## Kế thừa BaseMinigame quản lý kết nối, tutorial, handshake và camera thượng đế.

enum HookState {
	SWINGING,
	EXTENDING,
	RETRACTING
}

const MATCH_DURATION: float = 60.0
const SWING_SPEED: float = 3.0
const MAX_SWING_ANGLE: float = 70.0
const BASE_SWING_LENGTH: float = 2.5
const BASE_EXTEND_SPEED: float = 14.0
const BASE_RETRACT_SPEED: float = 12.0
const MAX_HOOK_LENGTH: float = 28.0

const GOLD_MINER_ITEM_SCENE = preload("res://scenes/minigames/gold_miner/gold_miner_item.tscn")
const HOOK_SCENE = preload("res://scenes/minigames/gold_miner/miner_hook.tscn")

# Server & Client State
var hooks: Dictionary = {}  # peer_id -> Dictionary {state, angle, swing_dir, length, target_item_id, origin, direction}
var minerals: Dictionary = {}  # item_id -> GoldMinerItem or Area3D or Dict
var gold_scores: Dictionary = {}  # peer_id -> int

# Visual Hook Nodes (Client / Host visualizer)
var hook_visuals: Dictionary = {}  # peer_id -> Dictionary {cable: MeshInstance3D, head: MeshInstance3D}

# UI references
var player_scores_panel: VBoxContainer = null
var minerals_container: Node3D = null
var hooks_container: Node3D = null


func _get_tutorial_data() -> Dictionary:
	return {
		"title": tr("MINIGAME_GOLD_MINER"),
		"rules": tr("GOLD_MINER_RULES"),
		"controls": tr("GOLD_MINER_CONTROLS_HINT"),
		"image": "res://assets/ui/tutorial/gold_miner.png"
	}


func _get_spawn_positions() -> Array[Vector3]:
	var rig_nodes = get_node_or_null("RigPositions")
	if rig_nodes:
		var pos_arr: Array[Vector3] = []
		for child in rig_nodes.get_children():
			if child is Node3D:
				var p = child.global_position if child.is_inside_tree() else child.position
				pos_arr.append(p)
		if not pos_arr.is_empty():
			return pos_arr
	return [
		Vector3(-9, 10, -1.0),
		Vector3(-3, 10, -1.0),
		Vector3(3, 10, -1.0),
		Vector3(9, 10, -1.0)
	]


func _on_pre_initialize() -> bool:
	# Fallback cho F6 testing hoặc khi chạy độc lập
	var gs = Engine.get_main_loop().root.get_node_or_null("GameSession")
	if gs and gs.minigame_players.is_empty():
		gs.minigame_players[1] = {
			"name": "Host",
			"character": "res://assets/characters/Blank_Character/Blank_Character.glb",
			"steam_id": 0,
			"color": Color.WHITE,
			"face": "res://assets/characters/face/robloxmanface.png",
			"hat": ""
		}
	return true


func _on_minigame_ready() -> void:
	match_timer = MATCH_DURATION
	player_scores_panel = get_node_or_null("UI/PlayerScoresPanel")
	minerals_container = get_node_or_null("MineralsContainer")
	hooks_container = get_node_or_null("HooksContainer")

	# Khóa di chuyển tất cả nhân vật trong minigame Đào Vàng
	_freeze_all_players(true)


func _freeze_all_players(_frozen: bool) -> void:
	# Trong Gold Miner, nhân vật luôn luôn đứng yên tại bệ cẩu, không di chuyển WASD
	for pid in players:
		var p = players[pid]
		if is_instance_valid(p):
			p.velocity = Vector3.ZERO
			p.set_physics_process(false)


func spawn_player(peer_id: int, character_path: String, player_name: String, steam_id: int, pos: Vector3, color: Color = Color.WHITE, face: String = "res://assets/characters/face/robloxmanface.png", hat: String = "") -> void:
	super.spawn_player(peer_id, character_path, player_name, steam_id, pos, color, face, hat)
	var p = players.get(peer_id)
	if is_instance_valid(p):
		p.velocity = Vector3.ZERO
		p.set_physics_process(false)
	var hook_origin = Vector3(pos.x, 9.9, 0.0)
	if peer_id not in hooks:
		hooks[peer_id] = create_default_hook_data(hook_origin)
	else:
		hooks[peer_id]["origin"] = hook_origin


func _on_tutorial_finished() -> void:
	super._on_tutorial_finished()
	# Giữ nhân vật đứng cố định sau khi hết tutorial
	_freeze_all_players(true)


func _on_post_initialize() -> void:
	if not multiplayer.is_server():
		return

	_spawn_default_minerals()
	_init_hooks_for_all_players()


func _spawn_default_minerals() -> void:
	if minerals_container == null:
		minerals_container = get_node_or_null("MineralsContainer")

	# Bảng sinh khoáng sản theo chiều dọc vực mỏ (X từ -10 đến 10, Y từ 6.5 đến -11.0, Z = 0)
	var spawn_table = [
		# Tầng cạn (Y: 4 đến 7)
		{"type": GoldMinerItem.Type.GOLD_SMALL, "pos": Vector3(-8.0, 6.0, 0.0)},
		{"type": GoldMinerItem.Type.GOLD_SMALL, "pos": Vector3(-2.5, 6.5, 0.0)},
		{"type": GoldMinerItem.Type.GOLD_SMALL, "pos": Vector3(3.0, 6.5, 0.0)},
		{"type": GoldMinerItem.Type.GOLD_SMALL, "pos": Vector3(8.5, 6.0, 0.0)},
		{"type": GoldMinerItem.Type.ROCK_SMALL, "pos": Vector3(-5.0, 5.0, 0.0)},
		{"type": GoldMinerItem.Type.ROCK_SMALL, "pos": Vector3(5.5, 5.0, 0.0)},

		# Tầng trung (Y: 0 đến 3)
		{"type": GoldMinerItem.Type.GOLD_MEDIUM, "pos": Vector3(-9.0, 2.0, 0.0)},
		{"type": GoldMinerItem.Type.GOLD_LARGE, "pos": Vector3(-4.0, 1.5, 0.0)},
		{"type": GoldMinerItem.Type.OBSTACLE, "pos": Vector3(0.0, 2.5, 0.0)},
		{"type": GoldMinerItem.Type.GOLD_LARGE, "pos": Vector3(4.5, 1.5, 0.0)},
		{"type": GoldMinerItem.Type.GOLD_MEDIUM, "pos": Vector3(9.0, 2.0, 0.0)},

		# Tầng sâu (Y: -5 đến -1)
		{"type": GoldMinerItem.Type.ROCK_LARGE, "pos": Vector3(-7.5, -2.0, 0.0)},
		{"type": GoldMinerItem.Type.DIAMOND, "pos": Vector3(-2.0, -3.0, 0.0)},
		{"type": GoldMinerItem.Type.DIAMOND, "pos": Vector3(2.5, -3.0, 0.0)},
		{"type": GoldMinerItem.Type.ROCK_LARGE, "pos": Vector3(7.5, -2.0, 0.0)},
		{"type": GoldMinerItem.Type.GOLD_MEDIUM, "pos": Vector3(0.0, -4.5, 0.0)},

		# Tầng đáy (Y: -11 đến -6)
		{"type": GoldMinerItem.Type.GOLD_LARGE, "pos": Vector3(-8.5, -8.0, 0.0)},
		{"type": GoldMinerItem.Type.DIAMOND, "pos": Vector3(-4.0, -10.5, 0.0)},
		{"type": GoldMinerItem.Type.GOLD_LARGE, "pos": Vector3(0.0, -9.0, 0.0)},
		{"type": GoldMinerItem.Type.DIAMOND, "pos": Vector3(4.0, -10.5, 0.0)},
		{"type": GoldMinerItem.Type.GOLD_LARGE, "pos": Vector3(8.5, -8.0, 0.0)}
	]

	var id = 1
	for entry in spawn_table:
		var item = GOLD_MINER_ITEM_SCENE.instantiate()
		item.name = "Mineral_%d" % id
		if minerals_container:
			minerals_container.add_child(item)
		else:
			add_child(item)
		item.setup_item(id, entry["type"], entry["pos"])
		minerals[id] = item

		# Broadcast tới các client đã handshake
		for pid in synced_peers:
			if pid != 1:
				spawn_mineral_rpc.rpc_id(pid, id, entry["type"], entry["pos"])
		id += 1


func _init_hooks_for_all_players() -> void:
	var spawns = _get_spawn_positions()
	var idx = 0
	for pid in player_states:
		var spawn_pos = spawns[idx % spawns.size()]
		# Điểm xuất phát của móc nhô ra phía trước ròng rọc ở mép vực (Z = 0.0, Y = 9.9)
		var hook_origin = Vector3(spawn_pos.x, 9.9, 0.0)
		hooks[pid] = create_default_hook_data(hook_origin)
		gold_scores[pid] = 0
		idx += 1


func _on_sync_custom_entities(caller_id: int) -> void:
	if not multiplayer.is_server():
		return

	# Gửi danh sách mineral hiện còn
	for item_id in minerals:
		var item = minerals[item_id]
		if item and is_instance_valid(item):
			var itype = item.item_type if "item_type" in item else 0
			var ipos = item.global_position if item is Node3D else Vector3.ZERO
			spawn_mineral_rpc.rpc_id(caller_id, item_id, itype, ipos)

	# Gửi trạng thái móc và điểm số
	for pid in hooks:
		var h = hooks[pid]
		sync_hook_full_state.rpc_id(caller_id, pid, h.get("state", HookState.SWINGING), h.get("angle", 0.0), h.get("length", 0.0), h.get("origin", Vector3.ZERO), gold_scores.get(pid, 0), h.get("target_item_id", -1))


@rpc("authority", "call_local", "reliable")
func spawn_mineral_rpc(item_id: int, item_type: int, pos: Vector3) -> void:
	if not is_inside_tree():
		return
	if item_id in minerals and is_instance_valid(minerals[item_id]):
		return

	if minerals_container == null:
		minerals_container = get_node_or_null("MineralsContainer")

	var item = GOLD_MINER_ITEM_SCENE.instantiate()
	item.name = "Mineral_%d" % item_id
	if minerals_container:
		minerals_container.add_child(item)
	else:
		add_child(item)
	item.setup_item(item_id, item_type, pos)
	minerals[item_id] = item


@rpc("authority", "call_local", "reliable")
func sync_hook_full_state(peer_id: int, state_val: int, angle: float, length: float, origin: Vector3, score: int, target_item_id: int = -1) -> void:
	if not is_inside_tree():
		return
	if peer_id not in hooks:
		hooks[peer_id] = create_default_hook_data(origin)
	var h = hooks[peer_id]
	h["state"] = state_val
	h["angle"] = angle
	h["length"] = length
	h["origin"] = origin
	h["target_item_id"] = target_item_id
	gold_scores[peer_id] = score
	_update_player_animation(peer_id, state_val)


func _unhandled_input(event: InputEvent) -> void:
	if state != GameState.PLAYING:
		return

	var is_trigger: bool = false
	if event.is_action_pressed("jump") or event.is_action_pressed("push") or event.is_action_pressed("ui_accept"):
		is_trigger = true
	elif event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			is_trigger = true

	if is_trigger:
		if multiplayer.is_server():
			request_drop_hook()
		else:
			request_drop_hook.rpc_id(1)


func _process(delta: float) -> void:
	super._process(delta)
	# Đảm bảo visual của móc luôn cập nhật liên tục kể cả trong giai đoạn tutorial đếm ngược
	if state == GameState.TUTORIAL:
		if multiplayer.is_server():
			for pid in hooks.keys():
				var h = hooks[pid]
				if h.get("state", HookState.SWINGING) == HookState.SWINGING:
					var max_rad: float = deg_to_rad(MAX_SWING_ANGLE)
					var angle: float = h.get("angle", 0.0)
					var s_dir: float = h.get("swing_dir", 1.0)
					angle += s_dir * SWING_SPEED * delta
					if abs(angle) >= max_rad:
						angle = clamp(angle, -max_rad, max_rad)
						s_dir = -s_dir
					h["angle"] = angle
					h["swing_dir"] = s_dir
					h["length"] = BASE_SWING_LENGTH
					h["direction"] = Vector3(sin(angle), -cos(angle), 0.0).normalized()
			for pid in hooks:
				var h = hooks[pid]
				for target_pid in synced_peers:
					if target_pid != 1:
						sync_hook_tick.rpc_id(target_pid, pid, h.get("state", HookState.SWINGING), h.get("angle", 0.0), h.get("length", BASE_SWING_LENGTH), h.get("target_item_id", -1))
		_update_hook_visuals(delta)


func _on_minigame_tick(delta: float) -> void:
	if multiplayer.is_server():
		# Cập nhật tất cả các móc
		for pid in hooks.keys():
			_tick_hook_server(pid, delta)

		# Broadcast vị trí và góc móc cho client
		for pid in hooks:
			var h = hooks[pid]
			for target_pid in synced_peers:
				if target_pid != 1:
					sync_hook_tick.rpc_id(target_pid, pid, h.get("state", HookState.SWINGING), h.get("angle", 0.0), h.get("length", BASE_SWING_LENGTH), h.get("target_item_id", -1))

		# Kiểm tra hết giờ
		if match_timer <= 0.0:
			_process_gold_miner_end()
			return

	_update_hook_visuals(delta)
	_update_scores_ui()


func calculate_round_scores() -> Dictionary:
	var scores: Dictionary = {}
	var total_n = player_states.size()
	if total_n <= 1:
		for pid in player_states:
			scores[pid] = 1000
		return scores

	for rank_idx in range(elimination_order.size()):
		var pid = elimination_order[rank_idx]
		var k = rank_idx + 1
		var pts = int(round(float(k - 1) / float(total_n - 1) * 1000.0))
		scores[pid] = pts

	for pid in player_states:
		if pid not in scores:
			scores[pid] = 1000
	return scores

func get_next_minigame_scene() -> String:
	return "res://scenes/minigames/mimic/mimic.tscn"

func end_game_timeout() -> void:
	if state == GameState.ENDED:
		return
	_process_gold_miner_end()


func _process_gold_miner_end() -> void:
	if state == GameState.ENDED:
		return
	if multiplayer and multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	state = GameState.ENDED
	for pid in players:
		_update_player_animation(pid, HookState.SWINGING)

	# Sắp xếp elimination_order theo điểm vàng tăng dần (người nhiều điểm nhất ở cuối cùng nhận 1000 điểm)
	var sorted_pids = []
	for p in gold_scores.keys():
		sorted_pids.append(int(p))
	sorted_pids.sort_custom(func(a, b):
		return gold_scores[a] < gold_scores[b]
	)
	var new_order: Array[int] = []
	for pid in sorted_pids:
		new_order.append(int(pid))
	for pid in player_states:
		var ipid = int(pid)
		if ipid not in new_order:
			new_order.push_front(ipid)
	elimination_order = new_order

	var winner_id: int = -1
	if not elimination_order.is_empty():
		winner_id = elimination_order.back()

	if multiplayer and multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_process_round_end(winner_id)


@rpc("authority", "unreliable")
func sync_hook_tick(peer_id: int, p_state: int, p_angle: float, p_length: float, p_target_item_id: int = -1) -> void:
	if not is_inside_tree() or multiplayer.is_server():
		return
	if peer_id not in hooks:
		var spawns = _get_spawn_positions()
		var p = players.get(peer_id)
		var origin = Vector3(p.position.x, 9.9, 0.0) if is_instance_valid(p) else spawns[0]
		hooks[peer_id] = create_default_hook_data(origin)
	var h = hooks[peer_id]
	h["state"] = p_state
	h["angle"] = p_angle
	h["length"] = p_length
	h["target_item_id"] = p_target_item_id


func _update_hook_visuals(delta: float = 0.0) -> void:
	if hooks_container == null:
		hooks_container = get_node_or_null("HooksContainer")
	if hooks_container == null:
		return

	# Cập nhật client local prediction cho swing nếu đang ở client
	if not multiplayer.is_server():
		for pid in hooks:
			var h = hooks[pid]
			if h.get("state", HookState.SWINGING) == HookState.SWINGING:
				var max_rad = deg_to_rad(MAX_SWING_ANGLE)
				var angle = h.get("angle", 0.0)
				var s_dir = h.get("swing_dir", 1.0)
				angle += s_dir * SWING_SPEED * delta
				if abs(angle) >= max_rad:
					angle = clamp(angle, -max_rad, max_rad)
					s_dir = -s_dir
				h["angle"] = angle
				h["swing_dir"] = s_dir
				h["length"] = BASE_SWING_LENGTH
				h["direction"] = Vector3(sin(angle), -cos(angle), 0.0).normalized()

	for pid in hooks:
		var h = hooks[pid]
		var origin = h.get("origin", Vector3.ZERO)
		var angle = h.get("angle", 0.0)
		var length = h.get("length", BASE_SWING_LENGTH)
		var dir = Vector3(sin(angle), -cos(angle), 0.0).normalized()
		var tip = origin + dir * length

		var vis = _get_or_create_hook_visual(pid)
		var cable = vis["cable"] as MeshInstance3D
		var head = vis["head"] as Node3D

		# Đầu móc vung lắc theo hình cánh cung và xoay theo chiều dây cáp
		head.global_position = tip
		head.rotation.z = angle

		# Cập nhật vị trí đồ vật bị kéo theo đầu móc (đồng bộ cả Host và Client)
		var target_id: int = h.get("target_item_id", -1)
		if target_id != -1 and target_id in minerals:
			var item = minerals[target_id]
			if item is Node3D and is_instance_valid(item):
				(item as Node3D).global_position = tip + dir * 0.95

		# Dây cáp (nối từ origin tới tip, hướng theo dir, chiều dài length)
		if length > 0.05:
			cable.visible = true
			cable.global_position = origin + dir * (length * 0.5)
			var cyl = cable.mesh as CylinderMesh
			if cyl:
				cyl.height = length
			if dir.length_squared() > 0.001:
				cable.look_at(tip, Vector3.FORWARD)
				cable.rotate_object_local(Vector3.RIGHT, deg_to_rad(90))
		else:
			cable.visible = false


func _get_or_create_hook_visual(peer_id: int) -> Dictionary:
	if peer_id in hook_visuals and is_instance_valid(hook_visuals[peer_id].get("head")):
		return hook_visuals[peer_id]

	if hooks_container == null:
		hooks_container = get_node_or_null("HooksContainer")

	# Đầu móc: instantiate model 3D miner_hook.tscn
	var head: Node3D = null
	if HOOK_SCENE:
		head = HOOK_SCENE.instantiate() as Node3D

	if head == null:
		# Fallback nếu không nạp được scene
		var sphere_inst = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.35
		sphere.height = 0.7
		sphere_inst.mesh = sphere
		var head_mat = StandardMaterial3D.new()
		head_mat.albedo_color = Color(0.95, 0.25, 0.15)
		head_mat.metallic = 0.85
		head_mat.roughness = 0.25
		sphere_inst.material_override = head_mat
		head = sphere_inst

	# Dây cáp cẩu: hình trụ xám kim loại
	var cable = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.04
	cyl.height = BASE_SWING_LENGTH
	cable.mesh = cyl
	var cable_mat = StandardMaterial3D.new()
	cable_mat.albedo_color = Color(0.18, 0.18, 0.18)
	cable_mat.metallic = 0.7
	cable_mat.roughness = 0.5
	cable.material_override = cable_mat
	cable.visible = true

	if hooks_container:
		hooks_container.add_child(cable)
		hooks_container.add_child(head)
	else:
		add_child(cable)
		add_child(head)

	hook_visuals[peer_id] = {"cable": cable, "head": head}
	return hook_visuals[peer_id]


func _update_scores_ui() -> void:
	if player_scores_panel == null:
		player_scores_panel = get_node_or_null("UI/PlayerScoresPanel")
	if player_scores_panel == null:
		return

	# Đảm bảo mỗi player có một label hiển thị
	for pid in gold_scores:
		var node_name = "Score_%d" % pid
		var lbl = player_scores_panel.get_node_or_null(node_name) as Label
		if lbl == null:
			lbl = Label.new()
			lbl.name = node_name
			lbl.add_theme_font_size_override("font_size", 16)
			player_scores_panel.add_child(lbl)

		var p_name = player_states.get(pid, {}).get("name", "Player %d" % pid)
		if p_name == ("Player %d" % pid) and is_instance_valid(Engine.get_main_loop()):
			var gs = Engine.get_main_loop().root.get_node_or_null("GameSession")
			if gs and "minigame_players" in gs:
				p_name = gs.minigame_players.get(pid, {}).get("name", p_name)
		lbl.text = "%s: %d" % [p_name, gold_scores.get(pid, 0)]
		if pid == multiplayer.get_unique_id():
			lbl.modulate = Color(1.0, 0.85, 0.2)
		else:
			lbl.modulate = Color.WHITE


func create_default_hook_data(p_origin: Vector3) -> Dictionary:
	return {
		"state": HookState.SWINGING,
		"angle": 0.0,
		"swing_dir": 1.0,
		"length": BASE_SWING_LENGTH,
		"target_item_id": -1,
		"origin": p_origin,
		"direction": Vector3(0, -1.0, 0)
	}


func calculate_retract_speed(weight: float) -> float:
	return BASE_RETRACT_SPEED / max(0.1, weight)


## Tìm vật thể va chạm đầu tiên dọc theo tia móc (first hit)
func find_first_hit(hook_origin: Vector3, hook_dir: Vector3, current_length: float, items_dict: Dictionary) -> int:
	var closest_id: int = -1
	var min_proj: float = INF
	var dir_norm: Vector3 = hook_dir.normalized()

	for item_id in items_dict:
		var item = items_dict[item_id]
		if item == null:
			continue

		var item_pos: Vector3 = Vector3.ZERO
		var item_radius: float = 0.5
		var is_active: bool = true

		if item is Dictionary:
			if not item.get("active", true):
				continue
			item_pos = item.get("pos", Vector3.ZERO)
			item_radius = item.get("radius", 0.5)
			is_active = item.get("active", true)
		elif item is Object:
			if not is_instance_valid(item):
				continue
			if "active" in item and not item.active:
				continue
			if "is_hooked" in item and item.is_hooked:
				continue
			if "is_collected" in item and item.is_collected:
				continue

			if item is Node3D:
				if (item as Node3D).is_inside_tree():
					item_pos = (item as Node3D).global_position
				else:
					item_pos = (item as Node3D).position
			elif "position" in item:
				item_pos = item.position

			if "radius" in item:
				item_radius = item.radius

		if not is_active:
			continue

		# Vector từ origin tới tâm item
		var vec: Vector3 = item_pos - hook_origin
		# Khi móc di chuyển theo mặt phẳng đứng X-Y, bỏ qua sai số trục chiều sâu Z
		if abs(dir_norm.z) < 0.2:
			vec.z = 0.0

		var proj: float = vec.dot(dir_norm)

		# Điều kiện dọc tia: phải nằm phía trước và trong tầm với (cộng thêm bán kính)
		if proj <= 0.0 or proj > (current_length + item_radius):
			continue

		# Khoảng cách vuông góc tới tia móc
		var perp_dist: float = (vec - dir_norm * proj).length()
		if perp_dist <= (item_radius + 0.25):
			if proj < min_proj:
				min_proj = proj
				closest_id = item_id

	return closest_id


func _get_item_pos(item) -> Vector3:
	if item is Node3D:
		if (item as Node3D).is_inside_tree():
			return (item as Node3D).global_position
		return (item as Node3D).position
	elif item is Dictionary:
		if "pos" in item:
			return item["pos"]
		elif "position" in item:
			return item["position"]
	return Vector3.ZERO


func _check_environment_hit_distance(origin: Vector3, dir: Vector3, length: float) -> float:
	var tip = origin + dir * length
	var min_hit_dist: float = -1.0

	# 1. Va chạm sàn mỏ MineFloor (bề mặt tại y = -13.0)
	if dir.y < -0.001:
		var floor_y: float = -13.0
		if origin.y > floor_y:
			var t_floor: float = (floor_y - origin.y) / dir.y
			if t_floor > 0.0 and t_floor <= length:
				min_hit_dist = t_floor

	# 2. Physics raycast kiểm tra StaticBody3D (Rubble2_Body, Rubble3_Body, MineFloor, tường)
	if is_inside_tree():
		var world_3d = get_world_3d()
		if world_3d:
			var space_state = world_3d.direct_space_state
			if space_state:
				var query = PhysicsRayQueryParameters3D.create(origin, tip)
				query.collide_with_areas = false
				query.collide_with_bodies = true
				var result = space_state.intersect_ray(query)
				if not result.is_empty():
					var hit_pos: Vector3 = result.get("position", tip)
					var dist: float = (hit_pos - origin).length()
					if min_hit_dist < 0.0 or dist < min_hit_dist:
						min_hit_dist = dist

	return min_hit_dist


## Xử lý logic di chuyển hook trên Server
func _tick_hook_server(peer_id: int, delta: float) -> void:
	if peer_id not in hooks:
		return
	var h: Dictionary = hooks[peer_id]
	var cur_state: int = h.get("state", HookState.SWINGING)

	match cur_state:
		HookState.SWINGING:
			var max_rad: float = deg_to_rad(MAX_SWING_ANGLE)
			var angle: float = h.get("angle", 0.0)
			var s_dir: float = h.get("swing_dir", 1.0)
			angle += s_dir * SWING_SPEED * delta
			if abs(angle) >= max_rad:
				angle = clamp(angle, -max_rad, max_rad)
				s_dir = -s_dir
			h["angle"] = angle
			h["swing_dir"] = s_dir
			h["length"] = BASE_SWING_LENGTH
			h["target_item_id"] = -1
			var dir = Vector3(sin(angle), -cos(angle), 0.0).normalized()
			h["direction"] = dir

		HookState.EXTENDING:
			var length: float = h.get("length", BASE_SWING_LENGTH)
			length += BASE_EXTEND_SPEED * delta
			h["length"] = length
			var dir: Vector3 = h.get("direction", Vector3(0, -1.0, 0))
			var origin: Vector3 = h.get("origin", Vector3.ZERO)

			# Kiểm tra va chạm vật cản môi trường (Sàn mỏ, Rubble2, Rubble3, Tường)
			var env_dist: float = _check_environment_hit_distance(origin, dir, length)

			# Kiểm tra va chạm với các khoáng sản
			var hit_id: int = find_first_hit(origin, dir, length, minerals)

			# Nếu mineral ở xa hơn điểm va chạm vật cản tĩnh, thì bị vật cản che chắn
			if hit_id != -1 and env_dist > 0.0:
				var item_pos: Vector3 = _get_item_pos(minerals[hit_id])
				var min_dist: float = (item_pos - origin).length()
				if env_dist < min_dist:
					hit_id = -1

			if hit_id != -1:
				var target_item = minerals.get(hit_id)
				var can_grab: bool = true
				if target_item is Dictionary:
					can_grab = target_item.get("grabbable", true)
				elif target_item is Object and is_instance_valid(target_item):
					if target_item.has_method("is_grabbable"):
						can_grab = target_item.is_grabbable()
					elif "grabbable" in target_item:
						can_grab = target_item.grabbable

				if can_grab:
					h["target_item_id"] = hit_id
					h["state"] = HookState.RETRACTING
					if target_item and is_instance_valid(target_item) and "is_hooked" in target_item:
						target_item.is_hooked = true
				else:
					# Đụng phải vật cản (OBSTACLE): dội ngược về ngay, không gắp gì
					h["target_item_id"] = -1
					h["state"] = HookState.RETRACTING

				_notify_hook_event(peer_id, HookState.RETRACTING, h.get("angle", 0.0), h.get("target_item_id", -1))
			elif env_dist > 0.0:
				# Chạm sàn hoặc chạm đá Rubble2/Rubble3: bật dội ngược lại ngay
				h["length"] = env_dist
				h["target_item_id"] = -1
				h["state"] = HookState.RETRACTING
				_notify_hook_event(peer_id, HookState.RETRACTING, h.get("angle", 0.0), -1)
			elif length >= MAX_HOOK_LENGTH:
				h["state"] = HookState.RETRACTING
				h["target_item_id"] = -1
				_notify_hook_event(peer_id, HookState.RETRACTING, h.get("angle", 0.0), -1)

		HookState.RETRACTING:
			var length: float = h.get("length", BASE_SWING_LENGTH)
			var target_id: int = h.get("target_item_id", -1)
			var weight: float = 1.0

			if target_id != -1 and target_id in minerals:
				var item = minerals[target_id]
				if item is Dictionary:
					weight = item.get("weight", 1.0)
				elif item is Object and is_instance_valid(item):
					if item.has_method("get_item_weight"):
						weight = item.get_item_weight()
					elif "weight" in item:
						weight = item.weight

			var r_speed: float = calculate_retract_speed(weight)
			length -= r_speed * delta

			if length <= BASE_SWING_LENGTH:
				length = BASE_SWING_LENGTH
				h["length"] = BASE_SWING_LENGTH
				h["state"] = HookState.SWINGING

				# Thu thập vật thể thành công
				if target_id != -1 and target_id in minerals:
					var item = minerals[target_id]
					var pts: int = 0
					if item is Dictionary:
						pts = item.get("value", 0)
					elif item is Object and is_instance_valid(item):
						if item.has_method("get_item_value"):
							pts = item.get_item_value()
						elif "value" in item:
							pts = item.value
						if "is_collected" in item:
							item.is_collected = true
						if item is Node:
							item.queue_free()
					minerals.erase(target_id)
					gold_scores[peer_id] = gold_scores.get(peer_id, 0) + pts
					_notify_item_collected(peer_id, target_id, gold_scores[peer_id])

				h["target_item_id"] = -1
				_notify_hook_event(peer_id, HookState.SWINGING, h.get("angle", 0.0), -1)
			else:
				h["length"] = length
				# Cập nhật vị trí item theo đầu móc nếu có
				if target_id != -1 and target_id in minerals:
					var item = minerals[target_id]
					var hook_dir_n: Vector3 = h.get("direction", Vector3(0, -1.0, 0)).normalized()
					var hook_tip: Vector3 = h.get("origin", Vector3.ZERO) + hook_dir_n * length
					if item is Node3D and is_instance_valid(item):
						(item as Node3D).global_position = hook_tip + hook_dir_n * 0.95


func _notify_hook_event(peer_id: int, new_state: int, angle: float, target_item_id: int = -1) -> void:
	if not multiplayer or not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	for pid in synced_peers:
		if pid == 1:
			sync_hook_event(peer_id, new_state, angle, target_item_id)
		else:
			sync_hook_event.rpc_id(pid, peer_id, new_state, angle, target_item_id)


func _notify_item_collected(peer_id: int, item_id: int, new_score: int) -> void:
	if not multiplayer or not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	for pid in synced_peers:
		if pid == 1:
			sync_item_collected(peer_id, item_id, new_score)
		else:
			sync_item_collected.rpc_id(pid, peer_id, item_id, new_score)


# ==============================================================================
# RPC CONTRACT (Server-Authoritative)
# ==============================================================================

@rpc("any_peer", "call_local", "reliable")
func request_drop_hook() -> void:
	if not multiplayer.is_server():
		return
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id == 0:
		sender_id = multiplayer.get_unique_id()

	if state != GameState.PLAYING:
		return

	if sender_id not in hooks:
		return

	var h: Dictionary = hooks[sender_id]
	if h.get("state", HookState.SWINGING) != HookState.SWINGING:
		return

	# Khóa góc và chuyển sang EXTENDING
	var angle: float = h.get("angle", 0.0)
	h["angle"] = angle
	h["direction"] = Vector3(sin(angle), -cos(angle), 0.0).normalized()
	h["state"] = HookState.EXTENDING
	h["target_item_id"] = -1
	_notify_hook_event(sender_id, HookState.EXTENDING, angle, -1)


@rpc("authority", "call_local", "reliable")
func sync_hook_event(peer_id: int, new_state: int, angle: float, target_item_id: int = -1) -> void:
	if not is_inside_tree():
		return
	if peer_id not in hooks:
		var spawns = _get_spawn_positions()
		var p = players.get(peer_id)
		var origin = Vector3(p.position.x, 9.9, 0.0) if is_instance_valid(p) else spawns[0]
		hooks[peer_id] = create_default_hook_data(origin)
	var h: Dictionary = hooks[peer_id]
	h["state"] = new_state
	h["angle"] = angle
	h["direction"] = Vector3(sin(angle), -cos(angle), 0.0).normalized()
	h["target_item_id"] = target_item_id
	if target_item_id != -1 and target_item_id in minerals:
		var target_item = minerals[target_item_id]
		if target_item and is_instance_valid(target_item) and "is_hooked" in target_item:
			target_item.is_hooked = true
	_update_player_animation(peer_id, new_state)


func _update_player_animation(peer_id: int, hook_state: int) -> void:
	if peer_id in players:
		var p = players[peer_id]
		if p and is_instance_valid(p) and p.has_method("play_anim"):
			if hook_state == HookState.RETRACTING:
				p.play_anim("tools/Working_C")
			elif hook_state == HookState.SWINGING:
				p.play_anim("general/Idle_A")


@rpc("authority", "call_local", "reliable")
func sync_item_collected(peer_id: int, item_id: int, new_score: int) -> void:
	if not is_inside_tree():
		return
	gold_scores[peer_id] = new_score
	if item_id in minerals:
		var item = minerals[item_id]
		if item is Node and is_instance_valid(item):
			item.queue_free()
		minerals.erase(item_id)


func _clear_materials_recursive(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node is MeshInstance3D:
		var mi = node as MeshInstance3D
		mi.material_override = null
		for i in range(mi.get_surface_override_material_count()):
			mi.set_surface_override_material(i, null)
	for child in node.get_children():
		_clear_materials_recursive(child)


func _exit_tree() -> void:
	super._exit_tree()
	for pid in hook_visuals:
		var vis = hook_visuals[pid]
		if vis.get("cable") and is_instance_valid(vis["cable"]):
			var c = vis["cable"] as MeshInstance3D
			c.material_override = null
		if vis.get("head") and is_instance_valid(vis["head"]):
			var h = vis["head"]
			_clear_materials_recursive(h)
	hook_visuals.clear()
