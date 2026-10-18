extends Control

signal character_confirmed(character_path: String)
signal selection_cancelled()

const GAME_SCENE := "res://scenes/core/main.tscn"
const CHARACTERS := {
	"Blank": "res://assets/characters/Blank_Character/Blank_Character.glb"
}

const POPULAR_COLORS: Array[Color] = [
	Color(0.95, 0.95, 0.95), # Trắng (White / Cream)
	Color(0.92, 0.25, 0.20), # Đỏ (Red)
	Color(0.95, 0.55, 0.15), # Cam (Orange)
	Color(0.95, 0.85, 0.20), # Vàng (Yellow)
	Color(0.20, 0.80, 0.35), # Xanh lá (Green)
	Color(0.20, 0.75, 0.85), # Xanh lam (Cyan)
	Color(0.20, 0.45, 0.90), # Xanh dương (Blue)
	Color(0.60, 0.30, 0.85), # Tím (Purple)
	Color(0.95, 0.45, 0.65), # Hồng (Pink)
	Color(0.55, 0.35, 0.25), # Nâu (Brown)
	Color(0.20, 0.22, 0.25), # Đen (Charcoal)
	Color(0.65, 0.68, 0.72)  # Xám (Gray)
]

const FACES: Array[Dictionary] = [
	{"name": "Roblox Man", "path": "res://assets/characters/face/robloxmanface.png"},
	{"name": "Roblox Woman", "path": "res://assets/characters/face/robloxwomanface.png"},
	{"name": "Crazy", "path": "res://assets/characters/face/crazyface.png"},
	{"name": "Confused", "path": "res://assets/characters/face/confuseface.png"},
	{"name": "Scared", "path": "res://assets/characters/face/scareface.png"},
	{"name": "Smug", "path": "res://assets/characters/face/smoughface.png"},
	{"name": "Stunt", "path": "res://assets/characters/face/stuntface.png"},
	{"name": "Tired", "path": "res://assets/characters/face/tiredface.png"},
	{"name": "Prize", "path": "res://assets/characters/face/prizeface.png"}
]

const HATS: Array[Dictionary] = [
	{"key": "HAT_NONE", "path": "", "icon": "res://assets/characters/accessories/none_icon.png"},
	{"key": "HAT_CROWN", "path": "res://assets/characters/accessories/crown.glb", "icon": "res://assets/characters/accessories/crown_icon.png"},
	{"key": "HAT_PIRATE", "path": "res://assets/characters/accessories/pirate_hat.glb", "icon": "res://assets/characters/accessories/pirate_icon.png"},
	{"key": "HAT_PAPER", "path": "res://assets/characters/accessories/paper_hat.glb", "icon": "res://assets/characters/accessories/paper_icon.png"},
	{"key": "HAT_SUBMARINE", "path": "res://assets/characters/accessories/submarine_hat.glb", "icon": "res://assets/characters/accessories/submarine_icon.png"}
]

@onready var title_label: Label = $Margin/Content/Title
@onready var preview: SubViewport = $Margin/Content/Body/PreviewPanel/PreviewViewportContainer/PreviewViewport
@onready var selected_label: Label = $Margin/Content/Footer/SelectedLabel
@onready var color_section: VBoxContainer = $Margin/Content/Body/LeftPanel/ColorSection
@onready var color_title: Label = $Margin/Content/Body/LeftPanel/ColorSection/ColorTitle
@onready var color_grid: GridContainer = $Margin/Content/Body/LeftPanel/ColorSection/ColorGrid
@onready var face_section: VBoxContainer = $Margin/Content/Body/LeftPanel/FaceSection
@onready var face_title: Label = $Margin/Content/Body/LeftPanel/FaceSection/FaceTitle
@onready var face_grid: GridContainer = $Margin/Content/Body/LeftPanel/FaceSection/FaceGrid
@onready var hat_section: VBoxContainer = $Margin/Content/Body/LeftPanel/HatSection
@onready var hat_title: Label = $Margin/Content/Body/LeftPanel/HatSection/HatTitle
@onready var hat_grid: GridContainer = $Margin/Content/Body/LeftPanel/HatSection/HatGrid

var model: Node3D
var anim_player: AnimationPlayer
var current_character_name: String = "Blank"
var color_buttons: Array[Button] = []
var face_buttons: Array[Button] = []
var hat_buttons: Array[Button] = []
var current_color: Color = Color(0.95, 0.95, 0.95)
var current_face: String = "res://assets/characters/face/robloxmanface.png"
var current_hat: String = ""

func _ready() -> void:
	_setup_color_buttons()
	_setup_face_buttons()
	_setup_hat_buttons()
	_update_ui_text()
	_select_character("Blank")

func _setup_face_buttons() -> void:
	if not face_grid:
		return
	for face_data in FACES:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(36, 36)
		btn.focus_mode = Control.FOCUS_NONE
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var tex = load(face_data["path"]) as Texture2D
		if tex:
			btn.icon = tex
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.92, 0.92, 0.95, 1.0)
		sb.set_corner_radius_all(6)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0, 0, 0, 0.4)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.pressed.connect(_select_face.bind(face_data["path"], btn))
		face_grid.add_child(btn)
		face_buttons.append(btn)

	_select_face(GameSession.selected_face)

func _select_face(face_path: String, active_btn: Button = null) -> void:
	current_face = face_path
	GameSession.selected_face = face_path
	for i in range(face_buttons.size()):
		var btn = face_buttons[i]
		var f_path = FACES[i]["path"]
		var sb: StyleBoxFlat = btn.get_theme_stylebox("normal")
		if sb:
			var new_sb = sb.duplicate()
			if btn == active_btn or (active_btn == null and f_path == face_path):
				new_sb.border_width_left = 3
				new_sb.border_width_top = 3
				new_sb.border_width_right = 3
				new_sb.border_width_bottom = 3
				new_sb.border_color = Color(0.2, 0.6, 1.0, 1.0)
			else:
				new_sb.border_width_left = 1
				new_sb.border_width_top = 1
				new_sb.border_width_right = 1
				new_sb.border_width_bottom = 1
				new_sb.border_color = Color(0, 0, 0, 0.4)
			btn.add_theme_stylebox_override("normal", new_sb)
			btn.add_theme_stylebox_override("hover", new_sb)
			btn.add_theme_stylebox_override("pressed", new_sb)
	_apply_face_to_preview()

func _apply_face_to_preview() -> void:
	if not model or not is_instance_valid(model):
		return
	_apply_face_recursive(model, current_face, current_color)

func _apply_face_recursive(node: Node, face_path: String, col: Color) -> void:
	if node is MeshInstance3D and node.name == "Blank_Head":
		var m: Mesh = node.mesh
		if m and m.get_surface_count() > 1:
			var tex = load(face_path) as Texture2D
			if tex:
				var mat: StandardMaterial3D = node.get_surface_override_material(1) as StandardMaterial3D
				if not mat:
					mat = StandardMaterial3D.new()
				mat.albedo_texture = tex
				mat.albedo_color = col
				mat.roughness = 0.5
				node.set_surface_override_material(1, mat)
				return
	for child in node.get_children():
		_apply_face_recursive(child, face_path, col)

func _setup_color_buttons() -> void:
	if not color_grid:
		return
	for col in POPULAR_COLORS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(32, 32)
		btn.focus_mode = Control.FOCUS_NONE
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(6)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0, 0, 0, 0.4)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.pressed.connect(_select_color.bind(col, btn))
		color_grid.add_child(btn)
		color_buttons.append(btn)

	_select_color(GameSession.selected_color)

func _select_color(col: Color, active_btn: Button = null) -> void:
	current_color = col
	GameSession.selected_color = col
	for btn in color_buttons:
		var sb: StyleBoxFlat = btn.get_theme_stylebox("normal")
		if sb:
			var new_sb = sb.duplicate()
			if btn == active_btn or (active_btn == null and new_sb.bg_color.is_equal_approx(col)):
				new_sb.border_width_left = 3
				new_sb.border_width_top = 3
				new_sb.border_width_right = 3
				new_sb.border_width_bottom = 3
				new_sb.border_color = Color(1, 1, 1, 1)
			else:
				new_sb.border_width_left = 1
				new_sb.border_width_top = 1
				new_sb.border_width_right = 1
				new_sb.border_width_bottom = 1
				new_sb.border_color = Color(0, 0, 0, 0.4)
			btn.add_theme_stylebox_override("normal", new_sb)
			btn.add_theme_stylebox_override("hover", new_sb)
			btn.add_theme_stylebox_override("pressed", new_sb)
	_apply_color_to_preview()

func _apply_color_to_preview() -> void:
	if not model or not is_instance_valid(model):
		return
	_apply_color_recursive(model, current_color)
	_apply_face_to_preview()

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
				else:
					var new_mat := StandardMaterial3D.new()
					new_mat.albedo_color = col
					new_mat.roughness = 0.5
					node.set_surface_override_material(s, new_mat)
	for child in node.get_children():
		_apply_color_recursive(child, col)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		if not is_node_ready():
			return
		_update_ui_text()

func _update_ui_text() -> void:
	if title_label:
		title_label.text = tr("CUSTOMIZE_YOUR_CHARACTER")
	if selected_label:
		selected_label.text = tr("CHAR_BLANK")
	if color_title:
		color_title.text = tr("COLOR_SELECT")
	if face_title:
		face_title.text = tr("FACE_SELECT")
	if hat_title:
		hat_title.text = tr("HAT_SELECT")

func _setup_hat_buttons() -> void:
	if not hat_grid:
		return
	for hat_data in HATS:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(36, 36)
		btn.focus_mode = Control.FOCUS_NONE
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var tex = load(hat_data["icon"]) as Texture2D
		if tex:
			btn.icon = tex
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.92, 0.92, 0.95, 1.0)
		sb.set_corner_radius_all(6)
		sb.border_width_left = 1
		sb.border_width_top = 1
		sb.border_width_right = 1
		sb.border_width_bottom = 1
		sb.border_color = Color(0, 0, 0, 0.4)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		btn.pressed.connect(_select_hat.bind(hat_data["path"], btn))
		hat_grid.add_child(btn)
		hat_buttons.append(btn)

	_select_hat(GameSession.selected_hat)

func _select_hat(hat_path: String, active_btn: Button = null) -> void:
	current_hat = hat_path
	GameSession.selected_hat = hat_path
	for i in range(hat_buttons.size()):
		var btn = hat_buttons[i]
		var h_path = HATS[i]["path"]
		var sb: StyleBoxFlat = btn.get_theme_stylebox("normal")
		if sb:
			var new_sb = sb.duplicate()
			if btn == active_btn or (active_btn == null and h_path == hat_path):
				new_sb.border_width_left = 3
				new_sb.border_width_top = 3
				new_sb.border_width_right = 3
				new_sb.border_width_bottom = 3
				new_sb.border_color = Color(0.2, 0.6, 1.0, 1.0)
			else:
				new_sb.border_width_left = 1
				new_sb.border_width_top = 1
				new_sb.border_width_right = 1
				new_sb.border_width_bottom = 1
				new_sb.border_color = Color(0, 0, 0, 0.4)
			btn.add_theme_stylebox_override("normal", new_sb)
			btn.add_theme_stylebox_override("hover", new_sb)
			btn.add_theme_stylebox_override("pressed", new_sb)
	_apply_hat_to_preview()

func _apply_hat_to_preview() -> void:
	if not model or not is_instance_valid(model):
		return
	var skel: Skeleton3D = model.get_node_or_null("Rig_Medium/Skeleton3D")
	if not skel:
		return
	var attachment: BoneAttachment3D = skel.get_node_or_null("HeadAttachment")
	if not attachment:
		attachment = BoneAttachment3D.new()
		attachment.name = "HeadAttachment"
		attachment.bone_name = "head"
		skel.add_child(attachment)

	for child in attachment.get_children():
		attachment.remove_child(child)
		child.queue_free()

	if current_hat != "":
		var hat_scene = load(current_hat)
		if hat_scene:
			var hat_instance = hat_scene.instantiate()
			hat_instance.name = "Hat"
			attachment.add_child(hat_instance)
			hat_instance.position = Vector3(0, 0.78, 0)

func _select_character(_character_name: String = "Blank") -> void:
	current_character_name = "Blank"
	GameSession.selected_character = CHARACTERS["Blank"]
	if selected_label:
		selected_label.text = tr("CHAR_BLANK")
	if model:
		model.queue_free()
	if anim_player:
		anim_player.queue_free()
	model = load(GameSession.selected_character).instantiate()
	preview.add_child(model)
	model.position = Vector3(0, -3.0, 0)
	model.scale = Vector3.ONE * 3.0
	_apply_color_to_preview()
	_apply_face_to_preview()
	_apply_hat_to_preview()

	# Thêm AnimationPlayer và attach vào GLB model
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	preview.add_child(anim_player)
	anim_player.root_node = anim_player.get_path_to(model)

	# Gắn library
	var move_lib = load("res://assets/animations/movement_animations.res")
	var gen_lib = load("res://assets/animations/general_animations.res")
	if move_lib: anim_player.add_animation_library("movement", move_lib)
	if gen_lib: anim_player.add_animation_library("general", gen_lib)

	await get_tree().process_frame
	if anim_player.has_animation("general/Idle_A"):
		anim_player.play("general/Idle_A")

func _on_confirm_pressed() -> void:
	character_confirmed.emit(GameSession.selected_character)
	if is_inside_tree() and get_tree().current_scene == self:
		get_tree().change_scene_to_file(GAME_SCENE)

func _on_back_pressed() -> void:
	selection_cancelled.emit()
	if is_inside_tree() and get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
