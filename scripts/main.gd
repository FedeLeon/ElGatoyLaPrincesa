extends Node3D
## First playable: a compact forest trail, a three-sigil riddle, a spirit guide,
## and one optional short encounter on the way to the sanctuary.

const WALK_SPEED := 5.2
const DODGE_SPEED := 10.5
const MOUSE_SENSITIVITY := 0.0025
@export_range(0.0005, 0.008, 0.0005) var mouse_sensitivity := MOUSE_SENSITIVITY

var player: CharacterBody3D
var camera_pivot: Node3D
var camera: Camera3D
var cat: Node3D
var cat_visual: Node3D
var cat_legs: Array[Node3D] = []
var cat_walk_target := Vector3.ZERO
var cat_walk_phase := 0.0
var terrain_builder
var enemy: Node3D
var enemy_animator: AnimationPlayer
var enemy_hp := 2
var player_hp := 3
var attack_cooldown := 0.0
var bow_equipped := false
var bow_aiming := false
var bow_fire_requested := false
var bow_cooldown := 0.0
var bow_shoot_timer := 0.0
var arrows_remaining := 8
var bow_socket: Node3D
var aim_reticle: Label
var ammo_label: Label
var arrow_pickups: Array[Node3D] = []
var pause_overlay: Control
var pause_menu_content: Control
var pause_options_panel: Control
var dodge_timer := 0.0
var dodge_direction := Vector3.FORWARD
var last_move_direction := Vector3.FORWARD
var enemy_windup := 0.0
var enemy_recovery := 0.0
var enemy_hit_timer := 0.0
var enemy_warning: MeshInstance3D
var guard_effect: MeshInstance3D
var cat_stage := 0
var using_gamepad := false
var invulnerability := 0.0
var sigils: Array[Node3D] = []
var sigil_order: Array[int] = [1, 2, 0]
var next_sigil := 0
var shrine_open := false
var near_interactable: Node3D
var message_timer := 0.0
var message_text := ""
var cat_hint_index := 0
var game_won := false
var game_over := false
var paused := false
var hud: CanvasLayer
var message_label: Label
var dialogue_panel: ColorRect
var interact_label: Label
var hp_label: Label
var quest_label: Label
var status_label: Label
var fps_label: Label
var waterfall_pools: Array[Vector3] = []
var water_effects: Node3D
var last_safe_position := Vector3(0, 0.15, 72)

var mats: Dictionary = {}


func _ready() -> void:
	mouse_sensitivity = GameSettings.mouse_sensitivity
	var render_scale := OS.get_environment("GATO_3D_SCALE")
	if render_scale.is_valid_float():
		get_viewport().scaling_3d_scale = clampf(render_scale.to_float(), 0.5, 1.0)
	_setup_materials()
	_build_world()
	_build_player()
	water_effects = Node3D.new()
	water_effects.name = "EfectosDeAgua"
	water_effects.set_script(preload("res://scripts/water_effects.gd"))
	add_child(water_effects)
	water_effects.configure(player, self, waterfall_pools)
	_build_cat()
	_build_encounter()
	_build_arrow_pickups()
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_show_message("El sendero termina en un santuario cubierto de musgo. El espíritu te espera adelante.", 6.0)


func _setup_materials() -> void:
	mats = {
		"grass": _mat(Color("435742"), 1.0),
		"grass_light": _mat(Color("66764a"), 1.0),
		"bark": _mat(Color("51483a"), 1.0),
		"bark_light": _mat(Color("78664a"), 1.0),
		"leaf": _mat(Color("3b5943"), 1.0),
		"leaf_light": _mat(Color("708747"), 1.0),
		"stone": _mat(Color("646a5b"), 1.0),
		"stone_light": _mat(Color("85846a"), 1.0),
		"water": _mat(Color("5b9488", 0.75), 0.18, true),
		"gold": _mat(Color("e9c778"), 0.35, true),
		"cloth": _mat(Color("bd5d4d"), 1.0),
		"dress": _mat(Color("d4bc86"), 1.0),
		"skin": _mat(Color("e7bd92"), 1.0),
		"hair": _mat(Color("44352f"), 1.0),
		"dark": _mat(Color("292f30"), 1.0),
		"spirit": _mat(Color("8ae4c2"), 0.25, true),
		"spirit_dim": _mat(Color("469a83", 0.72), 0.35, true),
		"cat_body": _mat(Color("69edcc"), 0.42, true),
		"cat_light": _mat(Color("b9ffe8"), 0.3, true),
		"cat_eye": _mat(Color("ffe58a"), 0.22, true),
		"bandit_cloth": _mat(Color("353c38"), 0.92),
		"bandit_leather": _mat(Color("70513a"), 0.9),
		"bandit_mask": _mat(Color("8e493b"), 0.95),
		"bandit_metal": _mat(Color("9c9277"), 0.52),
		"enemy": _mat(Color("765b43"), 1.0),
		"enemy_glow": _mat(Color("e3a65d"), 0.35, true),
		"forest_hair": _mat(Color("3f302a"), 0.95),
		"forest_cloak": _mat(Color("9c5d48"), 0.95),
		"forest_gown": _mat(Color("b5ad83"), 0.95),
		"crown": _mat(Color("dcc185"), 0.7),
	}
	var cat_body_material := mats["cat_body"] as StandardMaterial3D
	var cat_light_material := mats["cat_light"] as StandardMaterial3D
	var cat_eye_material := mats["cat_eye"] as StandardMaterial3D
	cat_body_material.emission_energy_multiplier = 1.45
	cat_light_material.emission_energy_multiplier = 1.8
	cat_eye_material.emission_energy_multiplier = 1.5


func _mat(color: Color, roughness: float = 0.9, emission: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emission:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.6
	return material


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://assets/shaders/forest_sky.gdshader")
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("bec8af")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 0.9
	environment.adjustment_saturation = 0.9
	environment.fog_enabled = true
	environment.fog_light_color = Color("a7b6a2")
	environment.fog_density = 0.0045
	environment.fog_sky_affect = 0.0
	env.environment = environment
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("ffe3ac")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 30.0
	sun.shadow_blur = 1.5
	add_child(sun)

	terrain_builder = preload("res://scripts/forest_world.gd").new()
	var world_data: Dictionary = terrain_builder.build(self)
	sigils = world_data.sigils
	waterfall_pools = world_data.water_pools


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Princesa"
	player.position = Vector3(0, 0.08, 72)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.9
	collision.shape = capsule
	collision.position.y = 0.95
	player.add_child(collision)
	add_child(player)
	_build_princess_visual()
	guard_effect = _add_torus(player, Vector3(0, 1.0, -0.55), 0.65, 0.56, "spirit")
	guard_effect.rotation.x = PI * 0.5
	guard_effect.visible = false

	camera_pivot = Node3D.new()
	camera_pivot.position = Vector3(0, 1.55, 0)
	add_child(camera_pivot)
	camera_pivot.global_position = player.global_position + Vector3(0, 1.55, 0)
	var spring := SpringArm3D.new()
	spring.spring_length = 4.2
	spring.margin = 0.25
	spring.add_excluded_object(player.get_rid())
	camera_pivot.add_child(spring)
	camera = Camera3D.new()
	camera_pivot.rotation.x = -0.20
	camera.fov = 62
	camera.current = true
	spring.add_child(camera)


func _build_princess_visual() -> void:
	if not _build_detailed_princess():
		_build_princess_visual_legacy()


func _build_detailed_princess() -> bool:
	var outfit_scene := load("res://assets/quaternius/princess/Female_Ranger.gltf") as PackedScene
	var body_scene := load("res://assets/quaternius/princess/Superhero_Female_FullBody.gltf") as PackedScene
	var hair_scene := load("res://assets/quaternius/princess/Hair_Long.gltf") as PackedScene
	var animation_scene := load("res://assets/quaternius/princess/UAL1_Standard.glb") as PackedScene
	if not outfit_scene or not body_scene or not hair_scene or not animation_scene:
		return false
	var visual := Node3D.new()
	visual.name = "PrincesaDelBosque"
	visual.rotation.y = PI
	player.add_child(visual)
	var outfit := outfit_scene.instantiate() as Node3D
	visual.add_child(outfit)
	var skeleton := outfit.find_child("Skeleton3D", true, false) as Skeleton3D
	if not skeleton:
		visual.queue_free()
		return false
	var body := body_scene.instantiate() as Node3D
	var body_skeleton := body.find_child("Skeleton3D", true, false) as Skeleton3D
	if not body_skeleton:
		body.free()
		visual.queue_free()
		return false
	for part_name in ["Superhero_Female", "Eyebrows", "Eyes"]:
		var part := body_skeleton.find_child(part_name, false, false) as MeshInstance3D
		if part:
			if part_name == "Superhero_Female":
				part.mesh = _head_only_mesh(part.mesh as ArrayMesh)
			part.owner = null
			body_skeleton.remove_child(part)
			skeleton.add_child(part)
			part.skeleton = NodePath("..")
	body.free()
	var hood := skeleton.find_child("Female_Ranger_Head_Hood", false, false) as MeshInstance3D
	if hood:
		hood.visible = false
	var head_index := skeleton.find_bone("Head")
	if head_index >= 0:
		var head := BoneAttachment3D.new()
		head.name = "CabelloYDiadema"
		head.bone_name = "Head"
		skeleton.add_child(head)
		var hair := hair_scene.instantiate() as Node3D
		head.add_child(hair)
		hair.transform = skeleton.get_bone_global_rest(head_index).affine_inverse()
		for hair_mesh in hair.find_children("*", "MeshInstance3D", true, false):
			var hair_material := hair_mesh.get_active_material(0) as StandardMaterial3D
			if hair_material:
				var dyed := hair_material.duplicate() as StandardMaterial3D
				dyed.albedo_color = Color("594137")
				hair_mesh.set_surface_override_material(0, dyed)
		_add_torus(head, Vector3(0, 0.215, -0.012), 0.13, 0.115, "crown")
		for side in [-1.0, 1.0]:
			var leaf := _add_sphere(head, Vector3(side * 0.10, 0.23, 0.03), Vector3(0.027, 0.045, 0.013), "leaf_light")
			leaf.rotation.z = -side * 0.5
	var source := animation_scene.instantiate()
	add_child(source)
	var source_player := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var animator := AnimationPlayer.new()
	animator.name = "MovimientoPrincesa"
	animator.root_node = NodePath("..")
	outfit.add_child(animator)
	var library := AnimationLibrary.new()
	if source_player:
		for pair in [["Idle_A", "Idle"], ["Walking_A", "Jog_Fwd"], ["Jump_Full_Short", "Roll"], ["Interact", "Sword_Attack"], ["Hit_A", "Hit_Chest"], ["Bow_Aim", "Pistol_Aim_Neutral"], ["Bow_Shoot", "Pistol_Shoot"]]:
			if source_player.has_animation(pair[1]):
				var clip := source_player.get_animation(pair[1]).duplicate(true) as Animation
				if pair[0] in ["Idle_A", "Walking_A"]:
					clip.loop_mode = Animation.LOOP_LINEAR
				library.add_animation(pair[0], clip)
	animator.add_animation_library("", library)
	source.free()
	visual.set_meta("animator", animator)
	if animator.has_animation("Idle_A"):
		animator.play("Idle_A")
	var staff := Node3D.new()
	staff.name = "Baston"
	var hand_index := skeleton.find_bone("hand_r")
	if hand_index >= 0:
		var hand := BoneAttachment3D.new()
		hand.name = "ManoBaston"
		hand.bone_name = "hand_r"
		skeleton.add_child(hand)
		var grip := Node3D.new()
		grip.name = "Empunadura"
		hand.add_child(grip)
		var hand_rest := skeleton.get_bone_global_rest(hand_index)
		grip.transform = hand_rest.affine_inverse() * Transform3D(Basis.IDENTITY, hand_rest.origin)
		grip.add_child(staff)
		player.set_meta("staff_grip", grip)
	else:
		visual.add_child(staff)
		staff.position = Vector3(-0.4, 1.0, 0)
	_add_cylinder(staff, Vector3.ZERO, 0.026, 1.55, "bark_light")
	_add_sphere(staff, Vector3(0, 0.80, 0), Vector3(0.065, 0.10, 0.065), "spirit")
	var staff_leaf := _add_sphere(staff, Vector3(0.08, 0.66, 0), Vector3(0.095, 0.16, 0.035), "leaf_light")
	staff_leaf.rotation.z = -0.7
	player.set_meta("staff", staff)
	var bow_hand_index := skeleton.find_bone("hand_l")
	if bow_hand_index >= 0:
		var bow_hand := BoneAttachment3D.new()
		bow_hand.name = "ManoArco"
		bow_hand.bone_name = "hand_l"
		skeleton.add_child(bow_hand)
		bow_socket = Node3D.new()
		bow_socket.name = "SoporteArco"
		bow_hand.add_child(bow_socket)
		bow_socket.transform = skeleton.get_bone_global_rest(bow_hand_index).affine_inverse() * Transform3D(Basis.IDENTITY, skeleton.get_bone_global_rest(bow_hand_index).origin)
		var bow_scene := load("res://assets/kaykit/weapons/Assets/gltf/bow_A_withString.gltf") as PackedScene
		if bow_scene:
			var bow_model := bow_scene.instantiate() as Node3D
			bow_model.name = "ArcoKayKit"
			bow_model.scale = Vector3.ONE * 0.62
			bow_model.rotation.z = PI * 0.5
			bow_socket.add_child(bow_model)
		bow_socket.visible = false
	player.set_meta("visual", visual)
	return true


func _head_only_mesh(source: ArrayMesh) -> ArrayMesh:
	# The outfit supplies clothing and limbs. Keep only the matching skinned
	# head and neck from the full-body mesh to avoid skin clipping through it.
	if source == null:
		return source
	var result := ArrayMesh.new()
	for surface_index in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface_index)
		# The imported mesh includes optional custom channels that are not used
		# by its material; drop them when rebuilding the indexed head surface.
		for channel in range(Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM3 + 1):
			arrays[channel] = null
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var old_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if old_indices.is_empty():
			for i in vertices.size():
				old_indices.append(i)
		var kept := PackedInt32Array()
		for triangle in range(0, old_indices.size() - 2, 3):
			var a := old_indices[triangle]
			var b := old_indices[triangle + 1]
			var c := old_indices[triangle + 2]
			if vertices[a].y >= 1.45 and vertices[b].y >= 1.45 and vertices[c].y >= 1.45:
				kept.append_array(PackedInt32Array([a, b, c]))
		if not kept.is_empty():
			arrays[Mesh.ARRAY_INDEX] = kept
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			result.surface_set_material(result.get_surface_count() - 1, source.surface_get_material(surface_index))
	return result


func _build_princess_visual_legacy() -> void:
	var visual := Node3D.new()
	visual.name = "PrincesaDelBosque"
	visual.rotation.y = PI
	player.add_child(visual)
	var packed := load("res://assets/kaykit/adventurers/Characters/gltf/Ranger.glb") as PackedScene
	if packed:
		var model := packed.instantiate() as Node3D
		visual.add_child(model)
		_attach_movement_animation(model)
		_customize_princess(model)
		visual.set_meta("animator", model.get_meta("animator"))
	else:
		_add_capsule(visual, Vector3(0, 0.95, 0), 0.3, 1.7, "cloth")
	var staff_packed := load("res://assets/kaykit/weapons/Assets/gltf/staff_A.gltf") as PackedScene
	var staff: Node3D
	if staff_packed:
		staff = staff_packed.instantiate() as Node3D
		staff.position = Vector3(0.55, 1.0, -0.15)
		staff.scale = Vector3.ONE * 0.72
		visual.add_child(staff)
	else:
		staff = _add_cylinder(visual, Vector3(0.55, 0.78, -0.12), 0.045, 1.55, "bark_light")
	staff.name = "Baston"
	staff.rotation.x = -0.12
	player.set_meta("staff", staff)
	player.set_meta("visual", visual)


func _customize_princess(model: Node3D) -> void:
	# The CC0 rig remains animated; original garments and crown follow its bones.
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return
	var quiver := model.find_child("Ranger_Quiver", true, false) as MeshInstance3D
	if quiver:
		quiver.visible = false
	var cape := model.find_child("Ranger_Cape", true, false) as MeshInstance3D
	if cape:
		cape.material_override = mats["forest_cloak"]
	var body := model.find_child("Ranger_Body", true, false) as MeshInstance3D
	if body:
		body.material_override = mats["forest_gown"]
	var original_head := model.find_child("Ranger_Head", true, false) as MeshInstance3D
	if original_head:
		original_head.visible = false
	var head := BoneAttachment3D.new()
	head.name = "CoronaDelBosque"
	head.bone_name = "head"
	skeleton.add_child(head)
	# A new original face and hair replace the ranger's bearded head.
	_add_sphere(head, Vector3(0, 0.48, -0.24), Vector3(0.42, 0.62, 0.19), "forest_hair")
	_add_sphere(head, Vector3(0, 0.52, 0), Vector3(0.39, 0.43, 0.34), "skin")
	_add_sphere(head, Vector3(0, 0.84, -0.04), Vector3(0.42, 0.22, 0.34), "forest_hair")
	for side in [-1.0, 1.0]:
		_add_sphere(head, Vector3(side * 0.34, 0.59, -0.05), Vector3(0.13, 0.30, 0.30), "forest_hair")
		_add_sphere(head, Vector3(side * 0.145, 0.57, 0.318), Vector3(0.045, 0.063, 0.028), "dark")
		_add_sphere(head, Vector3(side * 0.135, 0.593, 0.342), Vector3(0.014, 0.017, 0.01), "dress")
	_add_sphere(head, Vector3(0, 0.46, 0.339), Vector3(0.038, 0.045, 0.035), "skin")
	_add_sphere(head, Vector3(0, 0.36, 0.317), Vector3(0.075, 0.018, 0.018), "cloth")
	_add_torus(head, Vector3(0, 1.0, 0), 0.40, 0.35, "crown")
	for side in [-1.0, 1.0]:
		var leaf := _add_sphere(head, Vector3(side * 0.32, 1.03, -0.04), Vector3(0.09, 0.14, 0.05), "leaf_light")
		leaf.rotation.z = -side * 0.5
		_add_sphere(head, Vector3(side * 0.23, 1.0, 0.30), Vector3(0.045, 0.05, 0.04), "gold")
	_add_sphere(head, Vector3(0, 1.06, 0.32), Vector3(0.08, 0.13, 0.04), "leaf_light")
	var hip := BoneAttachment3D.new()
	hip.name = "FaldaDelBosque"
	hip.bone_name = "hips"
	skeleton.add_child(hip)
	var skirt_mesh := CylinderMesh.new()
	skirt_mesh.top_radius = 0.35
	skirt_mesh.bottom_radius = 0.47
	skirt_mesh.height = 0.46
	_mesh_node(hip, skirt_mesh, "forest_gown", Vector3(0, -0.16, 0))


func _attach_movement_animation(actor: Node3D) -> void:
	var animator := AnimationPlayer.new()
	animator.name = "AnimationPlayer"
	animator.root_node = NodePath("..")
	actor.add_child(animator)
	var library := AnimationLibrary.new()
	var sources := [
		["res://assets/kaykit/adventurers/Animations/gltf/Rig_Medium/Rig_Medium_General.glb", ["Idle_A", "Interact", "Hit_A"]],
		["res://assets/kaykit/adventurers/Animations/gltf/Rig_Medium/Rig_Medium_MovementBasic.glb", ["Walking_A", "Jump_Full_Short"]],
	]
	for source_info in sources:
		var source := load(source_info[0]) as PackedScene
		if source == null:
			continue
		var animation_scene := source.instantiate()
		add_child(animation_scene)
		var source_player := animation_scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if source_player:
			for animation_name in source_info[1]:
				if source_player.has_animation(animation_name):
					library.add_animation(animation_name, source_player.get_animation(animation_name).duplicate(true))
		animation_scene.free()
	animator.add_animation_library("", library)
	if animator.has_animation("Idle_A"):
		animator.play("Idle_A")
	actor.set_meta("animator", animator)


func _build_cat() -> void:
	cat = Node3D.new()
	cat.name = "EspirituGato"
	cat.position = Vector3(-2.0, terrain_builder.terrain_height_at(-2.0, 59.0), 59.0)
	add_child(cat)
	cat_visual = Node3D.new()
	cat_visual.name = "NimboCuadrupedo"
	cat.add_child(cat_visual)
	_add_sphere(cat_visual, Vector3(0, 0.4, 0.03), Vector3(0.37, 0.31, 0.67), "cat_body")
	_add_sphere(cat_visual, Vector3(0, 0.6, -0.42), Vector3(0.29, 0.27, 0.3), "cat_body")
	_add_sphere(cat_visual, Vector3(0, 0.5, -0.65), Vector3(0.17, 0.12, 0.12), "cat_light")
	_add_sphere(cat_visual, Vector3(0, 0.57, -0.755), Vector3(0.035, 0.027, 0.025), "cat_eye")
	for side in [-1.0, 1.0]:
		var ear := _add_cone(cat_visual, Vector3(side * 0.17, 0.83, -0.43), 0.105, 0.3, "cat_body")
		ear.rotation.z = -side * 0.18
		var inner_ear := _add_cone(cat_visual, Vector3(side * 0.17, 0.83, -0.48), 0.05, 0.17, "cat_light")
		inner_ear.rotation.z = -side * 0.18
		_add_sphere(cat_visual, Vector3(side * 0.12, 0.63, -0.665), Vector3(0.043, 0.074, 0.028), "cat_eye")
		_add_sphere(cat_visual, Vector3(side * 0.12, 0.63, -0.692), Vector3(0.014, 0.052, 0.012), "dark")
		_add_sphere(cat_visual, Vector3(side * 0.075, 0.51, -0.75), Vector3(0.075, 0.052, 0.07), "cat_light")
		for whisker in range(3):
			var whisker_mesh := _add_cylinder(cat_visual, Vector3(side * (0.19 + whisker * 0.018), 0.51 - whisker * 0.045, -0.7), 0.006, 0.3, "cat_light")
			whisker_mesh.rotation.z = PI * 0.5 + side * 0.12
			whisker_mesh.rotation.y = side * 0.25
	for is_front in [true, false]:
		for side in [-1.0, 1.0]:
			var leg_pivot := Node3D.new()
			leg_pivot.name = ("PataDelantera" if is_front else "PataTrasera") + ("Izquierda" if side < 0.0 else "Derecha")
			leg_pivot.position = Vector3(side * 0.25, 0.33, -0.39 if is_front else 0.42)
			cat_visual.add_child(leg_pivot)
			_add_capsule(leg_pivot, Vector3(0, -0.13, 0), 0.075, 0.3, "cat_body")
			_add_sphere(leg_pivot, Vector3(0, -0.275, -0.035), Vector3(0.095, 0.055, 0.14), "cat_light")
			cat_legs.append(leg_pivot)
	var tail := Node3D.new()
	tail.name = "Cola"
	tail.position = Vector3(0, 0.44, 0.55)
	cat_visual.add_child(tail)
	var tail_lower := _add_capsule(tail, Vector3(0, 0.1, 0.15), 0.065, 0.42, "cat_body")
	tail_lower.rotation.x = PI * 0.5
	var tail_upper := _add_capsule(tail, Vector3(0, 0.31, 0.34), 0.055, 0.34, "cat_light")
	tail_upper.rotation.x = 1.12
	var tail_tip := _add_sphere(tail, Vector3(0, 0.45, 0.39), Vector3(0.07, 0.07, 0.075), "cat_light")
	tail_tip.name = "Punta"
	var spirit_light := OmniLight3D.new()
	spirit_light.name = "LuzDeEspiritu"
	spirit_light.light_color = Color("79f8d1")
	spirit_light.light_energy = 0.45
	spirit_light.omni_range = 2.8
	spirit_light.shadow_enabled = false
	spirit_light.position = Vector3(0, 0.45, 0)
	cat_visual.add_child(spirit_light)
	cat_walk_target = cat.position


func _build_encounter() -> void:
	enemy = Node3D.new()
	enemy.name = "BandidoDelBosque"
	enemy.position = Vector3(8, 0.0, -44)
	add_child(enemy)
	var bandit := _build_bandit_visual()
	if bandit:
		enemy.add_child(bandit)
		enemy_animator = bandit.get_meta("animator", null) as AnimationPlayer
	else:
		_add_capsule(enemy, Vector3(0, 0.7, 0), 0.46, 1.35, "enemy")
	var arrow_hitbox := Area3D.new()
	arrow_hitbox.name = "ZonaDeImpactoDeFlecha"
	arrow_hitbox.collision_layer = 2
	arrow_hitbox.collision_mask = 0
	var arrow_shape := CollisionShape3D.new()
	var arrow_capsule := CapsuleShape3D.new()
	arrow_capsule.radius = 0.58
	arrow_capsule.height = 2.5
	arrow_shape.shape = arrow_capsule
	arrow_shape.position.y = 1.25
	arrow_hitbox.add_child(arrow_shape)
	enemy.add_child(arrow_hitbox)
	enemy.set_meta("arrow_hitbox", arrow_hitbox)
	enemy.set_meta("base_position", enemy.position)
	enemy_warning = _add_torus(enemy, Vector3(0, 0.08, 0), 1.45, 1.25, "enemy_glow")
	enemy_warning.visible = false


func _build_bandit_visual() -> Node3D:
	var outfit_scene := load("res://assets/quaternius/princess/Female_Ranger.gltf") as PackedScene
	var body_scene := load("res://assets/quaternius/princess/Superhero_Female_FullBody.gltf") as PackedScene
	var animation_scene := load("res://assets/quaternius/princess/UAL1_Standard.glb") as PackedScene
	if not outfit_scene or not body_scene or not animation_scene:
		return null
	var visual := Node3D.new()
	visual.name = "BandidoArticulado"
	visual.rotation.y = PI
	var outfit := outfit_scene.instantiate() as Node3D
	outfit.name = "RopaDeBandido"
	visual.add_child(outfit)
	var skeleton := outfit.find_child("Skeleton3D", true, false) as Skeleton3D
	if not skeleton:
		visual.queue_free()
		return null
	_tint_bandit_outfit(outfit)
	var body := body_scene.instantiate() as Node3D
	var body_skeleton := body.find_child("Skeleton3D", true, false) as Skeleton3D
	if not body_skeleton:
		body.free()
		visual.queue_free()
		return null
	for part_name in ["Superhero_Female", "Eyebrows", "Eyes"]:
		var part := body_skeleton.find_child(part_name, false, false) as MeshInstance3D
		if part:
			if part_name == "Superhero_Female":
				part.mesh = _head_only_mesh(part.mesh as ArrayMesh)
			part.owner = null
			body_skeleton.remove_child(part)
			skeleton.add_child(part)
			part.skeleton = NodePath("..")
	body.free()
	var head_hood := skeleton.find_child("Female_Ranger_Head_Hood", false, false) as MeshInstance3D
	if head_hood:
		head_hood.visible = true
	_add_bandit_face_cover(skeleton)
	_add_bandit_gear(visual)
	_add_bandit_dagger(skeleton)
	var source := animation_scene.instantiate()
	add_child(source)
	var source_player := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var animator := AnimationPlayer.new()
	animator.name = "AnimacionDelBandido"
	animator.root_node = NodePath("..")
	outfit.add_child(animator)
	var library := AnimationLibrary.new()
	if source_player:
		for pair in [["Idle_A", "Idle"], ["Walking_A", "Jog_Fwd"], ["BanditAttack", "Sword_Attack"], ["Hit_A", "Hit_Chest"]]:
			if source_player.has_animation(pair[1]):
				var clip := source_player.get_animation(pair[1]).duplicate(true) as Animation
				if pair[0] in ["Idle_A", "Walking_A"]:
					clip.loop_mode = Animation.LOOP_LINEAR
				library.add_animation(pair[0], clip)
	animator.add_animation_library("", library)
	source.free()
	if animator.has_animation("Idle_A"):
		animator.play("Idle_A")
	visual.set_meta("animator", animator)
	return visual


func _tint_bandit_outfit(outfit: Node3D) -> void:
	for part in outfit.find_children("*", "MeshInstance3D", true, false):
		var mesh_part := part as MeshInstance3D
		if mesh_part.mesh == null:
			continue
		var tint := Color(0.58, 0.56, 0.50)
		if mesh_part.name.contains("Hood") or mesh_part.name.contains("Body"):
			tint = Color(0.42, 0.48, 0.43)
		elif mesh_part.name.contains("Feet") or mesh_part.name.contains("Bracer") or mesh_part.name.contains("Belt") or mesh_part.name.contains("Pauldrons"):
			tint = Color(0.72, 0.55, 0.38)
		for surface in mesh_part.mesh.get_surface_count():
			var source_material := mesh_part.get_active_material(surface) as StandardMaterial3D
			if source_material == null:
				continue
			var dyed := source_material.duplicate() as StandardMaterial3D
			dyed.albedo_color = source_material.albedo_color * tint
			dyed.roughness = 0.88
			mesh_part.set_surface_override_material(surface, dyed)


func _add_bandit_face_cover(skeleton: Skeleton3D) -> void:
	var head_index := skeleton.find_bone("Head")
	if head_index < 0:
		return
	var face := BoneAttachment3D.new()
	face.name = "CapuchaYPanuelo"
	face.bone_name = "Head"
	skeleton.add_child(face)
	face.transform = skeleton.get_bone_global_rest(head_index).affine_inverse()
	var mask_mesh := SphereMesh.new()
	mask_mesh.radius = 0.5
	mask_mesh.height = 1.0
	var mask := MeshInstance3D.new()
	mask.name = "MascaraDeBandido"
	mask.mesh = mask_mesh
	mask.material_override = mats["bandit_mask"]
	mask.position = Vector3(0, 1.53, 0.155)
	mask.scale = Vector3(0.29, 0.11, 0.07)
	face.add_child(mask)
	for side in [-1.0, 1.0]:
		var tie_mesh := BoxMesh.new()
		tie_mesh.size = Vector3(0.12, 0.045, 0.035)
		var tie := MeshInstance3D.new()
		tie.mesh = tie_mesh
		tie.material_override = mats["bandit_mask"]
		tie.position = Vector3(side * 0.22, 1.56, 0.10)
		face.add_child(tie)


func _add_bandit_gear(visual: Node3D) -> void:
	# A short weathered cape and layered straps make the ranger outfit read as a bandit.
	var cape := MeshInstance3D.new()
	cape.name = "CapaOscura"
	var cape_surface := SurfaceTool.new()
	cape_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cape_points := [Vector3(-0.19, 1.55, -0.17), Vector3(0.19, 1.55, -0.17), Vector3(0.36, 0.64, -0.13), Vector3(0, 0.52, -0.24), Vector3(-0.36, 0.64, -0.13)]
	for index in [0, 1, 2, 0, 2, 3, 0, 3, 4, 0, 4, 1]:
		cape_surface.add_vertex(cape_points[index])
	cape_surface.index()
	cape_surface.generate_normals()
	cape.mesh = cape_surface.commit()
	var cape_material := (mats["bandit_cloth"] as StandardMaterial3D).duplicate() as StandardMaterial3D
	cape_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cape.material_override = cape_material
	visual.add_child(cape)
	var strap := _add_box(visual, Vector3(-0.13, 1.24, 0.19), Vector3(0.1, 0.65, 0.075), "bandit_leather")
	strap.rotation.z = -0.3
	var belt := _add_box(visual, Vector3(0, 0.91, 0.025), Vector3(0.43, 0.12, 0.37), "bandit_leather")
	belt.name = "CinturonDeCuero"
	_add_sphere(visual, Vector3(0.24, 0.84, 0.16), Vector3(0.12, 0.13, 0.12), "bark")
	var scarf := Node3D.new()
	scarf.name = "PanueloRojo"
	var scarf_mesh := SphereMesh.new()
	scarf_mesh.radius = 0.5
	scarf_mesh.height = 1.0
	var scarf_piece := MeshInstance3D.new()
	scarf_piece.mesh = scarf_mesh
	scarf_piece.material_override = mats["bandit_mask"]
	scarf_piece.position = Vector3(0, 1.42, 0.14)
	scarf_piece.scale = Vector3(0.28, 0.12, 0.12)
	scarf.add_child(scarf_piece)
	visual.add_child(scarf)
	var shoulder := _add_sphere(visual, Vector3(0.3, 1.52, 0), Vector3(0.2, 0.18, 0.22), "bandit_leather")
	shoulder.name = "Hombrera"


func _add_bandit_dagger(skeleton: Skeleton3D) -> void:
	var hand_index := skeleton.find_bone("hand_r")
	if hand_index < 0:
		return
	var hand := BoneAttachment3D.new()
	hand.name = "DagaDelBandido"
	hand.bone_name = "hand_r"
	skeleton.add_child(hand)
	var rest := skeleton.get_bone_global_rest(hand_index)
	hand.transform = rest.affine_inverse() * Transform3D(Basis.IDENTITY, rest.origin)
	var dagger := Node3D.new()
	hand.add_child(dagger)
	_add_cylinder(dagger, Vector3(0, -0.04, 0), 0.035, 0.24, "bandit_leather")
	var guard := _add_box(dagger, Vector3(0, 0.1, 0), Vector3(0.17, 0.045, 0.055), "bandit_metal")
	guard.name = "GuardaDeDaga"
	var blade := _add_box(dagger, Vector3(0, 0.37, 0), Vector3(0.085, 0.48, 0.035), "bandit_metal")
	blade.name = "HojaDeDaga"
	var point := _add_cone(dagger, Vector3(0, 0.63, 0), 0.045, 0.13, "bandit_metal")
	point.rotation.z = PI


func _play_bandit_animation(animation_name: String) -> void:
	if enemy_animator and enemy_animator.has_animation(animation_name) and enemy_animator.current_animation != animation_name:
		enemy_animator.play(animation_name, 0.16)


func _build_arrow_pickups() -> void:
	for pickup_info in [[Vector3(5, 0.0, 55), "Carcaj del sendero"], [Vector3(-29, 0.0, 26), "Carcaj del campamento"], [Vector3(0, 0.0, -32), "Carcaj de las ruinas"]]:
		var pickup := Node3D.new()
		pickup.name = pickup_info[1]
		pickup.position = pickup_info[0]
		pickup.set_meta("arrow_count", 8)
		add_child(pickup)
		for index in range(4):
			var shaft := _add_cylinder(pickup, Vector3((index - 1.5) * 0.075, 0.31, 0), 0.018, 0.62, "bark_light")
			shaft.rotation.z = (index - 1.5) * 0.08
			var feather := _add_sphere(pickup, Vector3((index - 1.5) * 0.075, 0.59, 0), Vector3(0.045, 0.075, 0.025), "cloth")
			feather.rotation.z = (index - 1.5) * 0.12
		var glint := _add_sphere(pickup, Vector3(0, 0.1, 0), Vector3(0.22, 0.055, 0.22), "spirit_dim")
		glint.name = "Brillo"
		arrow_pickups.append(pickup)


func _make_sigil(index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "PiedraGuia%d" % (index + 1)
	_add_cylinder(root, Vector3.ZERO, 0.72, 0.28, "stone")
	_add_cylinder(root, Vector3(0, 0.2, 0), 0.46, 0.2, "stone_light")
	var rune := _add_sphere(root, Vector3(0, 0.46, 0), Vector3(0.2, 0.3, 0.15), "spirit_dim")
	rune.name = "RunicGlow"
	var symbol := _add_box(root, Vector3(0, 0.76, 0), Vector3(0.1, 0.48, 0.09), "gold")
	symbol.visible = false
	if index == 0: # Seed
		var leaf := _add_sphere(root, Vector3(0, 0.9, 0), Vector3(0.19, 0.29, 0.1), "grass_light")
		leaf.rotation.z = -0.35
		_add_box(root, Vector3(0, 0.9, -0.01), Vector3(0.045, 0.46, 0.045), "gold")
	elif index == 1: # Moon
		var moon := _add_torus(root, Vector3(0, 0.91, 0), 0.28, 0.075, "gold")
		moon.rotation.x = PI * 0.5
		_add_sphere(root, Vector3(0.17, 1.02, -0.015), Vector3(0.22, 0.29, 0.09), "stone_light")
	else: # Water
		for line in range(3):
			var ripple := _add_box(root, Vector3(0, 0.78 + line * 0.13, 0), Vector3(0.42 - line * 0.07, 0.045, 0.07), "gold")
			ripple.rotation.z = 0.08 if line % 2 == 0 else -0.08
	root.set_meta("sigil_index", index)
	root.set_meta("active", false)
	return root


func _add_tree(point: Vector3, scale_factor: float, broad: bool) -> void:
	var tree := Node3D.new()
	tree.position = point
	tree.scale = Vector3.ONE * scale_factor
	add_child(tree)
	_add_cylinder(tree, Vector3(0, 2.0, 0), 0.52, 4.2, "bark")
	_add_cylinder(tree, Vector3(0, 2.35, 0), 0.16, 3.6, "bark_light")
	var canopy_scale := 1.0 if broad else 0.77
	_add_sphere(tree, Vector3(0, 4.35, 0), Vector3(2.0, 1.5, 1.7) * canopy_scale, "leaf")
	_add_sphere(tree, Vector3(-0.85, 4.0, 0.45), Vector3(1.2, 1.0, 1.25) * canopy_scale, "leaf_light")
	_add_sphere(tree, Vector3(0.9, 4.1, -0.4), Vector3(1.15, 1.15, 1.2) * canopy_scale, "leaf")
	if broad:
		for branch in [-1.0, 1.0]:
			var limb := _add_cylinder(tree, Vector3(branch * 0.7, 3.15, 0), 0.13, 1.7, "bark")
			limb.rotation.z = branch * -0.7


func _add_rock(point: Vector3, size: float) -> void:
	var rock := _add_sphere(self, point + Vector3(0, 0.38 * size, 0), Vector3(0.9, 0.65, 0.75) * size, "stone")
	rock.rotation.y = point.x * 0.3
	_add_sphere(self, point + Vector3(-0.18, 0.58 * size, -0.08), Vector3(0.55, 0.25, 0.45) * size, "stone_light")


func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var panel := ColorRect.new()
	panel.color = Color(0.07, 0.09, 0.075, 0.72)
	panel.position = Vector2(24, 22)
	panel.size = Vector2(390, 118)
	hud.add_child(panel)
	var title := _label("EL GATO Y LA PRINCESA", Vector2(42, 31), 23, Color("f1dba5"))
	hud.add_child(title)
	quest_label = _label("Llega al santuario del bosque", Vector2(42, 64), 17, Color("f1ead5"))
	hud.add_child(quest_label)
	hp_label = _label("Corazones  ♥ ♥ ♥", Vector2(42, 94), 17, Color("f0b29b"))
	hud.add_child(hp_label)
	status_label = _label("", Vector2(24, 150), 15, Color("d9e1c1"))
	hud.add_child(status_label)

	dialogue_panel = ColorRect.new()
	dialogue_panel.position = Vector2(235, 525)
	dialogue_panel.size = Vector2(810, 105)
	dialogue_panel.color = Color(0.08, 0.1, 0.075, 0.82)
	dialogue_panel.visible = false
	hud.add_child(dialogue_panel)
	message_label = _label("", Vector2(250, 532), 21, Color("fff1ce"))
	message_label.size = Vector2(780, 90)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(message_label)
	interact_label = _label("", Vector2(390, 625), 18, Color("f5dfa8"))
	interact_label.size = Vector2(500, 36)
	interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(interact_label)
	var controls := _label("WASD mover  ·  Ratón mirar  ·  C arco  ·  RMB apuntar / clic izq. disparar  ·  E interactuar  ·  F bastón  ·  Q defender  ·  Espacio esquivar", Vector2(55, 683), 12, Color("eee4cf"))
	controls.size = Vector2(1170, 24)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(controls)

	aim_reticle = _label("+", Vector2(621, 341), 34, Color("f6e9c9"))
	aim_reticle.size = Vector2(38, 38)
	aim_reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aim_reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	aim_reticle.visible = false
	hud.add_child(aim_reticle)
	ammo_label = _label("Flechas  8", Vector2(1040, 86), 20, Color("f1dba5"))
	ammo_label.size = Vector2(205, 32)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ammo_label.visible = false
	hud.add_child(ammo_label)
	fps_label = _label("", Vector2(1070, 24), 17, Color("fff1ce"))
	fps_label.visible = false
	hud.add_child(fps_label)
	_build_pause_overlay()


func _build_pause_overlay() -> void:
	pause_overlay = Control.new()
	pause_overlay.name = "MenuDePausa"
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.visible = false
	hud.add_child(pause_overlay)
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.025, 0.04, 0.035, 0.83)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.add_child(dimmer)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -245
	panel.offset_top = -215
	panel.offset_right = 245
	panel.offset_bottom = 215
	panel.add_theme_stylebox_override("panel", _ui_panel_style())
	pause_overlay.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(margin)
	pause_menu_content = VBoxContainer.new()
	pause_menu_content.add_theme_constant_override("separation", 14)
	margin.add_child(pause_menu_content)
	var title := Label.new()
	title.text = "Aventura en pausa"
	title.add_theme_font_size_override("font_size", 31)
	title.add_theme_color_override("font_color", Color("f1dba5"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_menu_content.add_child(title)
	var resume := _make_ui_button("Continuar", true)
	pause_menu_content.add_child(resume)
	resume.pressed.connect(_toggle_pause)
	var settings := _make_ui_button("Ajustes", false)
	pause_menu_content.add_child(settings)
	settings.pressed.connect(_open_pause_options)
	var home := _make_ui_button("Volver al inicio", false)
	pause_menu_content.add_child(home)
	home.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	pause_options_panel = Control.new()
	pause_options_panel.set_script(preload("res://scripts/options_panel.gd"))
	pause_options_panel.visible = false
	pause_overlay.add_child(pause_options_panel)
	pause_options_panel.connect("back_requested", _close_pause_options)


func _open_pause_options() -> void:
	pause_menu_content.visible = false
	pause_options_panel.visible = true


func _close_pause_options() -> void:
	pause_options_panel.visible = false
	pause_menu_content.visible = true
	(pause_menu_content.get_child(2) as Button).grab_focus()


func _ui_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.06, 0.97)
	style.border_color = Color("a78e5e")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style


func _make_ui_button(text_value: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(360, 52)
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color("f6efd9"))
	button.add_theme_stylebox_override("normal", _ui_button_style(Color("53634a") if primary else Color("273a31")))
	button.add_theme_stylebox_override("hover", _ui_button_style(Color("7a7048")))
	button.add_theme_stylebox_override("pressed", _ui_button_style(Color("394a3c")))
	button.add_theme_stylebox_override("focus", _ui_button_style(Color("665b3d")))
	return button


func _ui_button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("c4aa72")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _label(text_value: String, at: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.08, 0.08, 0.07, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _process(delta: float) -> void:
	var grip := player.get_meta("staff_grip", null) as Node3D
	if grip:
		var actor_visual := player.get_meta("visual") as Node3D
		grip.global_basis = actor_visual.global_basis.orthonormalized()
	if fps_label.visible:
		var fps := Engine.get_frames_per_second()
		fps_label.text = "%d FPS  ·  %.1f ms" % [fps, 1000.0 / maxf(float(fps), 1.0)]
	if (game_won or game_over) and Input.is_action_just_pressed("interact"):
		get_tree().reload_current_scene()
		return
	if Input.is_action_just_pressed("pause") and not game_won and not game_over:
		_toggle_pause()
	if paused or game_won or game_over:
		return
	if Input.is_action_just_pressed("bow_toggle"):
		_toggle_bow()
	bow_aiming = bow_equipped and Input.is_action_pressed("bow_aim")
	var camera_arm := camera.get_parent() as SpringArm3D
	if camera_arm:
		camera_arm.spring_length = move_toward(camera_arm.spring_length, 2.85 if bow_aiming else 4.2, delta * 7.0)
	camera.fov = move_toward(camera.fov, 54.0 if bow_aiming else 62.0, delta * 30.0)
	camera.position.x = move_toward(camera.position.x, 0.36 if bow_aiming else 0.0, delta * 1.5)
	aim_reticle.visible = bow_aiming
	ammo_label.visible = bow_equipped
	ammo_label.text = "Flechas  %d" % arrows_remaining
	message_timer = maxf(0.0, message_timer - delta)
	if message_timer <= 0.0:
		message_label.text = ""
		dialogue_panel.visible = false
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	bow_cooldown = maxf(0.0, bow_cooldown - delta)
	bow_shoot_timer = maxf(0.0, bow_shoot_timer - delta)
	dodge_timer = maxf(0.0, dodge_timer - delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	guard_effect.visible = Input.is_action_pressed("block") and dodge_timer <= 0.0 and not bow_equipped
	_update_cat_motion(delta)
	if cat_hint_index > 0 and cat_stage == 0 and player.position.z < 30:
		cat_stage = 1
		_walk_cat_to(Vector3(-18, 0, 17))
	elif cat_stage == 1 and player.position.z < -34:
		cat_stage = 2
		_walk_cat_to(Vector3(12, 0, -57))
	_update_nearest_interactable()
	_update_hud()
	if Input.is_action_just_pressed("interact"):
		_interact()
	if Input.is_action_just_pressed("attack") and not bow_equipped:
		_attack()
	if bow_aiming and Input.is_action_just_pressed("bow_fire"):
		bow_fire_requested = true
	if Input.is_action_just_pressed("dodge"):
		_dodge()
	if Input.get_connected_joypads().size() > 0:
		var look_x := Input.get_axis("look_left", "look_right")
		var look_y := Input.get_axis("look_up", "look_down")
		camera_pivot.rotation.y -= look_x * delta * 2.2
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x + look_y * delta * 1.7, -0.52, 0.38)
	_update_enemy(delta)
	_check_shrine()


func _physics_process(delta: float) -> void:
	if player.global_position.y < -8.0:
		player.global_position = last_safe_position + Vector3(0, 0.1, 0)
		player.velocity = Vector3.ZERO
		_show_message("Nimbo te devuelve al último lugar seguro del bosque.", 2.5)
	camera_pivot.global_position = player.global_position + Vector3(0, 1.55, 0)
	if paused or game_won or game_over:
		player.velocity.x = move_toward(player.velocity.x, 0.0, WALK_SPEED * 6.0 * delta)
		player.velocity.z = move_toward(player.velocity.z, 0.0, WALK_SPEED * 6.0 * delta)
		player.move_and_slide()
		return
	if bow_fire_requested:
		bow_fire_requested = false
		_shoot_arrow()
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward := -camera_pivot.global_basis.z
	var right := camera_pivot.global_basis.x
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()
	var direction := right * input_vector.x + forward * -input_vector.y
	if direction.length() > 0.1 and dodge_timer <= 0.0:
		last_move_direction = direction.normalized()
	var movement_speed := WALK_SPEED * (0.45 if Input.is_action_pressed("block") else 1.0)
	var target := dodge_direction * DODGE_SPEED if dodge_timer > 0.0 else direction * movement_speed
	player.velocity.x = move_toward(player.velocity.x, target.x, 28.0 * delta)
	player.velocity.z = move_toward(player.velocity.z, target.z, 28.0 * delta)
	if not player.is_on_floor():
		player.velocity.y -= 22.0 * delta
	else:
		player.velocity.y = -0.2
	var facing_direction := dodge_direction if dodge_timer > 0.0 else (-camera_pivot.global_basis.z if bow_aiming else direction)
	facing_direction.y = 0.0
	if facing_direction.length() > 0.1:
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-facing_direction.x, -facing_direction.z), delta * (18.0 if dodge_timer > 0.0 else 10.0))
	player.move_and_slide()
	if player.is_on_floor() and absf(player.global_position.x) < 89.0 and player.global_position.z > -106.0 and player.global_position.z < 86.0:
		last_safe_position = player.global_position
	var animator := (player.get_meta("visual") as Node3D).get_meta("animator", null) as AnimationPlayer
	if animator:
		var target_animation := "Walking_A" if direction.length() > 0.1 else "Idle_A"
		if dodge_timer > 0.0:
			target_animation = "Jump_Full_Short"
		elif bow_aiming and bow_shoot_timer > 0.0:
			target_animation = "Bow_Shoot"
		elif bow_aiming:
			target_animation = "Bow_Aim"
		elif attack_cooldown > 0.18:
			target_animation = "Interact"
		if animator.has_animation(target_animation) and animator.current_animation != target_animation:
			var blend_time := 0.06 if dodge_timer > 0.0 else 0.18
			var playback_speed := 1.0
			if dodge_timer > 0.0:
				var roll := animator.get_animation(target_animation)
				playback_speed = roll.length / maxf(dodge_timer, 0.08)
			animator.play(target_animation, blend_time, playback_speed)
	if dodge_timer > 0.0:
		var visual: Node3D = player.get_meta("visual")
		visual.scale.y = 0.82
	else:
		var visual: Node3D = player.get_meta("visual")
		visual.scale.y = 1.0


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		using_gamepad = true
	elif event is InputEventKey or event is InputEventMouseMotion or event is InputEventMouseButton:
		using_gamepad = false
	if event is InputEventMouseButton and event.pressed and not paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not paused:
		mouse_sensitivity = GameSettings.mouse_sensitivity
		camera_pivot.rotation.y -= event.relative.x * mouse_sensitivity
		camera_pivot.rotation.x = clampf(camera_pivot.rotation.x - event.relative.y * mouse_sensitivity, -0.52, 0.38)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _update_nearest_interactable() -> void:
	near_interactable = null
	var nearest := 2.4
	var cat_distance := player.global_position.distance_to(cat.global_position)
	if cat_distance < nearest:
		nearest = cat_distance
		near_interactable = cat
	for stone in sigils:
		var distance := player.global_position.distance_to(stone.global_position)
		if distance < nearest:
			nearest = distance
			near_interactable = stone
	var gate := get_node_or_null("SantuarioCerrado")
	if gate and gate.visible:
		var distance := player.global_position.distance_to(gate.global_position)
		if distance < nearest:
			nearest = distance
			near_interactable = gate
	for pickup in arrow_pickups:
		if pickup.visible:
			var distance := player.global_position.distance_to(pickup.global_position)
			if distance < nearest:
				nearest = distance
				near_interactable = pickup
	if near_interactable == cat:
		interact_label.text = ("A" if using_gamepad else "E") + "  ·  Hablar con el espíritu"
	elif near_interactable in sigils:
		interact_label.text = ("A" if using_gamepad else "E") + "  ·  Tocar la piedra guía"
	elif near_interactable == gate:
		interact_label.text = ("A" if using_gamepad else "E") + "  ·  Examinar el sello"
	elif near_interactable in arrow_pickups:
		interact_label.text = ("A" if using_gamepad else "E") + "  ·  Recoger 8 flechas"
	else:
		interact_label.text = ""


func _walk_cat_to(destination: Vector3) -> void:
	destination.y = terrain_builder.terrain_height_at(destination.x, destination.z)
	cat_walk_target = destination


func _update_cat_motion(delta: float) -> void:
	var offset := cat_walk_target - cat.position
	offset.y = 0.0
	var is_walking := offset.length() > 0.08
	if is_walking:
		var direction := offset.normalized()
		cat.rotation.y = lerp_angle(cat.rotation.y, atan2(-direction.x, -direction.z), delta * 7.0)
		var step := minf(4.6 * delta, offset.length())
		cat.position += direction * step
		cat.position.y = terrain_builder.terrain_height_at(cat.position.x, cat.position.z)
		cat_walk_phase += delta * 10.0
	else:
		var to_player := player.global_position - cat.global_position
		to_player.y = 0.0
		if to_player.length() > 0.1:
			cat.rotation.y = lerp_angle(cat.rotation.y, atan2(-to_player.x, -to_player.z), delta * 2.5)
		cat_walk_phase = 0.0
	var breath := sin(Time.get_ticks_msec() * 0.002) * 0.008
	cat_visual.position.y = breath + (absf(sin(cat_walk_phase * 2.0)) * 0.025 if is_walking else 0.0)
	for index in cat_legs.size():
		var diagonal_phase := PI if index in [1, 2] else 0.0
		var leg_swing := sin(cat_walk_phase + diagonal_phase) * 0.38 if is_walking else sin(Time.get_ticks_msec() * 0.0015 + float(index)) * 0.018
		cat_legs[index].rotation.x = leg_swing
	var tail := cat_visual.get_node("Cola") as Node3D
	tail.rotation.z = sin(Time.get_ticks_msec() * 0.0024) * 0.24
	tail.rotation.x = cos(Time.get_ticks_msec() * 0.0018) * 0.08


func _interact() -> void:
	if near_interactable == null:
		return
	if near_interactable == cat:
		_cat_speak()
	elif near_interactable in sigils:
		_activate_sigil(near_interactable)
	elif near_interactable.has_meta("gate"):
		if shrine_open:
			_show_message("El umbral cede. Dentro, las raíces guardan un brillo antiguo.", 4.0)
		else:
			_show_message("Tres marcas rodean el sello. El santuario espera una melodía de piedra.", 3.4)
	elif arrow_pickups.has(near_interactable):
		arrows_remaining += int(near_interactable.get_meta("arrow_count", 8))
		near_interactable.visible = false
		_show_message("Guardas las flechas en el carcaj. Ahora tienes %d." % arrows_remaining, 2.0)


func _cat_speak() -> void:
	var lines := [
		"Soy Nimbo, memoria pequeña de este bosque. El santuario recuerda el orden de las cosas vivas.",
		"Escucha el arroyo: primero la luna, luego el agua, al final la semilla que despierta.",
		"El bandido protege el umbral. Puedes acercarte con el bastón o frenarlo con una flecha.",
	]
	var index := mini(cat_hint_index, lines.size() - 1)
	_show_message("Nimbo: «%s»" % lines[index], 5.2)
	cat_hint_index += 1


func _toggle_bow() -> void:
	bow_equipped = not bow_equipped
	bow_aiming = false
	var staff := player.get_meta("staff", null) as Node3D
	if staff:
		staff.visible = not bow_equipped
	if bow_socket:
		bow_socket.visible = bow_equipped
	if bow_equipped:
		_show_message("Arco listo. Mantén RMB para apuntar y pulsa clic izquierdo para disparar.", 3.0)
	else:
		_show_message("Guardas el arco y vuelves al bastón.", 1.8)


func _shoot_arrow() -> void:
	if not bow_equipped or not bow_aiming or bow_cooldown > 0.0:
		return
	if arrows_remaining <= 0:
		_show_message("No quedan flechas. Busca un carcaj junto al sendero.", 2.0)
		return
	arrows_remaining -= 1
	bow_cooldown = 0.42
	bow_shoot_timer = 0.24
	var center := get_viewport().get_visible_rect().size * 0.5
	var ray_origin := camera.project_ray_origin(center)
	var ray_direction := camera.project_ray_normal(center)
	var ray_end := ray_origin + ray_direction * 80.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 3, [player.get_rid()])
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var aim_hit := get_world_3d().direct_space_state.intersect_ray(query)
	var aim_point: Vector3 = aim_hit.position if not aim_hit.is_empty() else ray_end
	var launch := bow_socket.global_position if bow_socket else player.global_position + Vector3(0, 1.25, 0)
	var flight_query := PhysicsRayQueryParameters3D.create(launch, aim_point, 3, [player.get_rid()])
	flight_query.collide_with_areas = true
	flight_query.collide_with_bodies = true
	var flight_hit := get_world_3d().direct_space_state.intersect_ray(flight_query)
	var destination: Vector3 = flight_hit.position if not flight_hit.is_empty() else aim_point
	var enemy_hitbox: Area3D = null
	if is_instance_valid(enemy):
		enemy_hitbox = enemy.get_meta("arrow_hitbox", null) as Area3D
	var hit_enemy: bool = not flight_hit.is_empty() and flight_hit.get("collider") == enemy_hitbox
	var arrow := Node3D.new()
	arrow.name = "FlechaEnVuelo"
	add_child(arrow)
	arrow.global_position = launch
	if arrow.global_position.distance_to(destination) > 0.05:
		arrow.look_at(destination, Vector3.UP)
	_build_arrow_mesh(arrow)
	var travel_time := clampf(launch.distance_to(destination) / 38.0, 0.07, 1.6)
	var flight := create_tween()
	flight.tween_property(arrow, "global_position", destination, travel_time)
	flight.finished.connect(func():
		if hit_enemy:
			_arrow_hits_enemy()
		if is_instance_valid(arrow):
			arrow.queue_free()
	)


func _build_arrow_mesh(arrow: Node3D) -> void:
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.014
	shaft_mesh.bottom_radius = 0.014
	shaft_mesh.height = 0.68
	var shaft := MeshInstance3D.new()
	shaft.mesh = shaft_mesh
	shaft.material_override = mats["bark_light"]
	shaft.rotation.x = PI * 0.5
	arrow.add_child(shaft)
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0.002
	tip_mesh.bottom_radius = 0.055
	tip_mesh.height = 0.14
	var tip := MeshInstance3D.new()
	tip.mesh = tip_mesh
	tip.material_override = mats["stone_light"]
	tip.position.z = -0.36
	tip.rotation.x = -PI * 0.5
	arrow.add_child(tip)
	for side in [-1.0, 1.0]:
		var feather_mesh := BoxMesh.new()
		feather_mesh.size = Vector3(0.065, 0.018, 0.15)
		var feather := MeshInstance3D.new()
		feather.mesh = feather_mesh
		feather.material_override = mats["cloth"]
		feather.position = Vector3(side * 0.028, 0, 0.23)
		feather.rotation.z = side * 0.28
		arrow.add_child(feather)


func _arrow_hits_enemy() -> void:
	if not is_instance_valid(enemy) or not enemy.visible:
		return
	enemy_hp -= 1
	enemy_windup = 0.0
	enemy_warning.visible = false
	enemy_recovery = 0.9
	enemy_hit_timer = 0.36
	_play_bandit_animation("Hit_A")
	if enemy_hp <= 0:
		enemy.visible = false
		_show_message("La flecha alcanza al bandido y deja libre el sendero.", 2.8)
	else:
		_show_message("La flecha hace retroceder al bandido. Aún sigue en pie.", 2.0)


func _activate_sigil(stone: Node3D) -> void:
	var index := int(stone.get_meta("sigil_index"))
	if bool(stone.get_meta("active")):
		_show_message("La piedra ya canta con su nota tenue.", 2.0)
		return
	var expected := sigil_order[next_sigil]
	if index == expected:
		stone.set_meta("active", true)
		var rune := stone.get_node("RunicGlow") as MeshInstance3D
		rune.material_override = mats["gold"]
		rune.scale = Vector3.ONE * 1.35
		next_sigil += 1
		if next_sigil == sigil_order.size():
			shrine_open = true
			var gate := get_node("SantuarioCerrado") as Node3D
			gate.visible = false
			var gate_collision := gate.get_node_or_null("Colision")
			if gate_collision:
				gate_collision.queue_free()
			_show_message("Las tres notas se enlazan. El sello se disuelve y el santuario abre sus puertas.", 5.0)
		else:
			_show_message("La piedra responde. Una nota armoniosa despierta en el bosque.", 2.8)
	else:
		for lit_stone in sigils:
			lit_stone.set_meta("active", false)
			(lit_stone.get_node("RunicGlow") as MeshInstance3D).material_override = mats["spirit_dim"]
		next_sigil = 0
		_show_message("La nota se apaga. Nimbo dijo: luna, agua, semilla. Prueba esa secuencia.", 3.5)


func _attack() -> void:
	if attack_cooldown > 0.0:
		return
	attack_cooldown = 0.48
	var staff: Node3D = player.get_meta("staff")
	staff.rotation.x = -0.7
	var tween := create_tween()
	tween.tween_property(staff, "rotation:x", 0.0, 0.24)
	var to_enemy := enemy.global_position - player.global_position if is_instance_valid(enemy) else Vector3.ZERO
	to_enemy.y = 0
	if is_instance_valid(enemy) and enemy.visible and to_enemy.length() < 2.35 and (-player.global_basis.z).dot(to_enemy.normalized()) > 0.2:
		enemy_hp -= 1
		enemy_windup = 0.0
		enemy_warning.visible = false
		enemy_recovery = 0.8
		enemy_hit_timer = 0.36
		enemy.position += -player.global_basis.z * 0.42
		_play_bandit_animation("Hit_A")
		if enemy_hp <= 0:
			enemy.visible = false
			_show_message("El bandido cae y deja libre el sendero.", 3.0)
		else:
			_show_message("¡Golpe certero! El bandido retrocede, pero sigue peleando.", 1.8)
	else:
		_show_message("El bastón corta el aire. Acércate para alcanzar al bandido.", 1.5)


func _dodge() -> void:
	if dodge_timer > 0.0:
		return
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var forward := -camera_pivot.global_basis.z
	var right := camera_pivot.global_basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	var input_direction := right * input_vector.x + forward * -input_vector.y
	dodge_timer = 0.34
	dodge_direction = input_direction.normalized() if input_direction.length() > 0.1 else last_move_direction
	invulnerability = 0.6


func _update_enemy(delta: float) -> void:
	if not is_instance_valid(enemy) or not enemy.visible:
		return
	var distance := player.global_position.distance_to(enemy.global_position)
	enemy_recovery = maxf(0.0, enemy_recovery - delta)
	enemy_hit_timer = maxf(0.0, enemy_hit_timer - delta)
	if enemy_hit_timer > 0.0:
		_play_bandit_animation("Hit_A")
		return
	if enemy_windup > 0.0:
		enemy_windup -= delta
		if enemy_windup <= 0.0:
			enemy_warning.visible = false
			enemy_recovery = 1.2
			_play_bandit_animation("Idle_A")
			if distance < 1.9 and invulnerability <= 0.0:
				var toward_threat := enemy.global_position - player.global_position
				toward_threat.y = 0
				if Input.is_action_pressed("block") and (-player.global_basis.z).dot(toward_threat.normalized()) > 0.1:
					_show_message("El bastón detiene el golpe del bandido.", 1.6)
				else:
					player_hp -= 1
					invulnerability = 1.25
					_show_message("El bandido te alcanza. Esquiva o defiéndete con Q / LB.", 2.1)
					if player_hp <= 0:
						_game_ended(false)
		return
	if distance < 5.2 and distance > 1.05:
		var direction := (player.global_position - enemy.global_position).normalized()
		enemy.position += direction * delta * 1.25
		enemy.look_at(Vector3(player.global_position.x, enemy.global_position.y, player.global_position.z), Vector3.UP)
		_play_bandit_animation("Walking_A")
	else:
		_play_bandit_animation("Idle_A")
	if distance < 1.7 and enemy_recovery <= 0.0:
		enemy_windup = 0.8
		enemy_warning.visible = true
		_play_bandit_animation("BanditAttack")
		_show_message("¡El bandido alza la daga! Esquiva para salir del círculo.", 1.0)


func _check_shrine() -> void:
	if shrine_open and player.global_position.distance_to(Vector3(0, 0, -89)) < 3.2:
		_game_ended(true)


func _game_ended(won: bool) -> void:
	game_won = won
	game_over = not won
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var heading := "EL SANTUARIO TE RECUERDA" if won else "EL BOSQUE TE DEVUELVE AL SENDERO"
	var body := "Nimbo sonríe. Esta aventura recién comienza.\n\nR o A para volver a intentarlo." if won else "Respira, pequeña viajera. El camino sigue aquí.\n\nR o A para intentarlo de nuevo."
	var panel := ColorRect.new()
	panel.color = Color(0.05, 0.08, 0.06, 0.88)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(panel)
	var label := _label(heading + "\n\n" + body, Vector2(220, 235), 28, Color("f1dba5"))
	label.size = Vector2(840, 260)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud.add_child(label)


func _update_hud() -> void:
	var hearts := ""
	for i in range(3):
		hearts += "♥ " if i < player_hp else "♡ "
	hp_label.text = "Corazones  %s" % hearts
	if shrine_open:
		quest_label.text = "El umbral está abierto: entra al santuario"
	else:
		quest_label.text = "Armoniza las tres piedras guía  (%d/3)" % next_sigil
	if bow_equipped:
		status_label.text = "Arco equipado · C guardar · RMB apuntar · clic disparar"
	elif enemy.visible:
		status_label.text = "Un bandido bloquea el sendero · bastón F / esquivar Espacio"
	else:
		status_label.text = "El sendero está en calma"


func _show_message(text_value: String, seconds: float) -> void:
	message_text = text_value
	message_label.text = text_value if is_instance_valid(message_label) else ""
	if is_instance_valid(dialogue_panel):
		dialogue_panel.visible = true
	message_timer = seconds


func _toggle_pause() -> void:
	paused = not paused
	if paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		pause_menu_content.visible = true
		pause_options_panel.visible = false
		pause_overlay.visible = true
		(pause_menu_content.get_child(1) as Button).grab_focus()
	else:
		pause_overlay.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		message_timer = 0.0
		message_label.text = ""
		dialogue_panel.visible = false


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		get_tree().reload_current_scene()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		fps_label.visible = not fps_label.visible
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_MINUS, KEY_EQUAL, KEY_PLUS]:
		mouse_sensitivity = clampf(mouse_sensitivity + (0.0005 if event.keycode != KEY_MINUS else -0.0005), 0.0005, 0.008)
		GameSettings.set_mouse_sensitivity(mouse_sensitivity)
		_show_message("Sensibilidad de cámara: %d%%  (− / +)" % roundi(mouse_sensitivity / MOUSE_SENSITIVITY * 100), 2.0)


# Primitive builders keep this first slice self-contained and easy to replace with authored art.
func _mesh_node(parent: Node3D, mesh: Mesh, material_key: String, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mats[material_key]
	instance.position = at
	parent.add_child(instance)
	return instance


func _add_box(parent: Node3D, at: Vector3, size: Vector3, material_key: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := _mesh_node(parent, mesh, material_key, at)
	if parent == self and at.y <= -0.1:
		var body := StaticBody3D.new()
		body.position = at
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		add_child(body)
		instance.position = Vector3.ZERO
		instance.reparent(self)
		instance.position = at
	return instance


func _add_sphere(parent: Node3D, at: Vector3, size: Vector3, material_key: String) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	var instance := _mesh_node(parent, mesh, material_key, at)
	instance.scale = size * 2.0
	return instance


func _add_capsule(parent: Node3D, at: Vector3, radius: float, height: float, material_key: String) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return _mesh_node(parent, mesh, material_key, at)


func _add_cylinder(parent: Node3D, at: Vector3, radius: float, height: float, material_key: String) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.9
	mesh.bottom_radius = radius
	mesh.height = height
	return _mesh_node(parent, mesh, material_key, at)


func _add_cone(parent: Node3D, at: Vector3, radius: float, height: float, material_key: String) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.015
	mesh.bottom_radius = radius
	mesh.height = height
	return _mesh_node(parent, mesh, material_key, at)


func _add_torus(parent: Node3D, at: Vector3, radius: float, inner_radius: float, material_key: String) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = radius
	return _mesh_node(parent, mesh, material_key, at)
