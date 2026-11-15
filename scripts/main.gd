extends Node3D
## 2.5D pixel-art adventure prototype with axis-aligned movement and a short forest quest.

const WALK_SPEED := 5.2
const DODGE_SPEED := 10.5
const MOUSE_SENSITIVITY := 0.0025
const PRINCESS_SPRITE_HEIGHT := 2.55
const BACKPACK_START_CAPACITY := 12
const BACKPACK_MAX_CAPACITY := 36
const FOREST_UI_CARD := preload("res://scripts/forest_ui_card.gd")
const ITEM_CATALOG := {
	"flechas": {"name": "Flechas", "icon": "res://assets/ui/items/arrows.svg", "unit": "unidades", "stack_limit": 20},
}
@export_range(0.0005, 0.008, 0.0005) var mouse_sensitivity := MOUSE_SENSITIVITY

var player: CharacterBody3D
var camera_pivot: Node3D
var camera: Camera3D
var navigation_grid: AStarGrid2D
var click_path: PackedVector3Array = []
var destination_marker: MeshInstance3D
var princess_illustration: Sprite3D
var bandit_illustration: Sprite3D
var cat_illustration: Sprite3D
var illustration_time := 0.0
var princess_direction_row := 0
var bandit_direction_row := 0
var animation_textures: Dictionary = {}
var illustrated_walk_frame := -1
var previous_walk_frame := -1
var illustrated_walk_distance := 0.0
var enemy_death_time := 0.0
var enemy_attack_visual_recovery := 0.0
var enemy_previous_position := Vector3.ZERO
var enemy_vfx_step := 0.0
var cat_vfx_step := 0.0
var player_hit_time := 0.0
const NAV_CELL := 1.5
const NAV_ORIGIN := Vector2(-90.0, -107.0)
const NAV_WIDTH := 121
const NAV_DEPTH := 130
var cat: Node3D
var cat_walk_target := Vector3.ZERO
var terrain_builder
var enemy: Node3D
var enemy_hp := 2
var enemy_defeated := false
var player_hp := 3
var attack_cooldown := 0.0
var bow_equipped := false
var bow_fire_requested := false
var bow_cooldown := 0.0
var bow_shoot_timer := 0.0
var arrows_remaining := 8
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
var guard_effect: Node3D
var guard_rings: Array[MeshInstance3D] = []
var guard_orbs: Array[MeshInstance3D] = []
var guard_particles: GPUParticles3D
var guard_light: OmniLight3D
var guard_time := 0.0
var guard_flash_timer := 0.0
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
var dialogue_panel: Panel
var interact_panel: Panel
var ammo_panel: Panel
var interact_label: Label
var hp_label: Label
var quest_label: Label
var status_label: Label
var fps_label: Label
var pickup_notification: Panel
var pickup_notification_icon: TextureRect
var pickup_notification_name: Label
var pickup_notification_amount: Label
var pickup_notification_tween: Tween
var inventory_overlay: Control
var inventory_bow_state: Label
var inventory_staff_state: Label
var inventory_capacity_label: Label
var inventory_capacity_fill: ColorRect
var inventory_health_label: Label
var inventory_weapon_label: Label
var inventory_attack_label: Label
var inventory_arrows_label: Label
var inventory_bow_button: Button
var inventory_staff_button: Button
var inventory_item_slots: Array[Button] = []
var backpack_capacity := BACKPACK_START_CAPACITY
var inventory_open := false
var collected_items: Dictionary = {"flechas": 8}
var waterfall_pools: Array[Vector3] = []
var water_effects: Node3D
var last_safe_position := Vector3(0, 0.15, 72)

var mats: Dictionary = {}


func _ready() -> void:
	# Apply weapon sockets after the child AnimationPlayers update the skeleton.
	process_priority = 100
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
	_build_pixel_display()
	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_message("Clic izquierdo para caminar. Busca a Nimbo y sigue el sendero hasta el santuario.", 7.0)
	GameAudio.enter_forest(self, waterfall_pools)


func _exit_tree() -> void:
	if has_node("/root/GameAudio"):
		GameAudio.leave_forest()


func _setup_materials() -> void:
	mats = {
		"grass": _mat(Color("435742"), 1.0),
		"grass_light": _mat(Color("66764a"), 1.0),
		"bark": _mat(Color("51483a"), 1.0),
		"bark_light": _mat(Color("78664a"), 1.0),
		"staff_bark": _mat(Color("68432d"), 0.96),
		"staff_edge": _mat(Color("9c7048"), 0.92),
		"staff_wrap": _mat(Color("41352d"), 1.0),
		"staff_gem": _mat(Color("8ae4c2"), 0.22, true),
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
		"guard_energy": _mat(Color("4ccbb7"), 0.18, true),
		"guard_gold": _mat(Color("d7aa57"), 0.2, true),
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
	(mats["guard_energy"] as StandardMaterial3D).emission_energy_multiplier = 1.25
	(mats["guard_gold"] as StandardMaterial3D).emission_energy_multiplier = 0.9


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
	environment.ambient_light_color = Color("b4c5a2")
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.0
	environment.adjustment_contrast = 1.045
	environment.adjustment_saturation = 1.0
	environment.fog_enabled = true
	environment.fog_light_color = Color("a7b8a1")
	environment.fog_density = 0.00115
	environment.fog_sky_affect = 0.0
	env.environment = environment
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("f6ddb2")
	sun.light_energy = 0.68
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 46.0
	sun.shadow_blur = 2.0
	add_child(sun)

	terrain_builder = preload("res://scripts/forest_world.gd").new()
	var world_data: Dictionary = terrain_builder.build(self)
	sigils = world_data.sigils
	waterfall_pools = world_data.water_pools


func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Princesa"
	player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	player.position = Vector3(0, terrain_builder.terrain_height_at(0, 71.5) + 0.12, 71.5)
	last_safe_position = player.position
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.9
	collision.shape = capsule
	collision.position.y = 0.95
	player.add_child(collision)
	add_child(player)
	_build_guard_effect()
	princess_illustration = _make_illustrated_sprite(player, "res://assets/created/isometric/princess_painted_walk_sheet.png", PRINCESS_SPRITE_HEIGHT / 362.0, PRINCESS_SPRITE_HEIGHT * 0.5, Vector2i(4, 3), Vector2i(1, 0))
	princess_illustration.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	camera_pivot = Node3D.new()
	camera_pivot.position = Vector3(0, 1.55, 0)
	camera_pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	add_child(camera_pivot)
	camera_pivot.global_position = player.global_position + Vector3(0, 1.55, 0)
	camera = Camera3D.new()
	# Sin giro azimutal: X queda horizontal y Z vertical en pantalla, conservando profundidad 2.5D.
	camera_pivot.rotation = Vector3(deg_to_rad(-55.0), 0.0, 0.0)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.5
	camera.position = Vector3(0, 0, 35)
	camera.current = true
	camera_pivot.add_child(camera)
	var marker_mesh := PlaneMesh.new()
	marker_mesh.size = Vector2.ONE * NAV_CELL
	destination_marker = MeshInstance3D.new()
	destination_marker.mesh = marker_mesh
	var marker_material := ShaderMaterial.new()
	marker_material.shader = load("res://assets/shaders/grid_target.gdshader")
	destination_marker.material_override = marker_material
	destination_marker.rotation.x = PI * 0.5
	destination_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	destination_marker.visible = false
	add_child(destination_marker)


func _build_guard_effect() -> void:
	guard_effect = Node3D.new()
	guard_effect.name = "SelloDeEnergia"
	guard_effect.position = Vector3(0, 1.08, -0.62)
	guard_effect.visible = false
	player.add_child(guard_effect)
	guard_light = OmniLight3D.new()
	guard_light.name = "LuzDelHechizo"
	guard_light.light_color = Color("69e5cb")
	guard_light.light_energy = 0.8
	guard_light.omni_range = 2.8
	guard_light.shadow_enabled = false
	guard_light.position = Vector3(0, 0, -0.12)
	guard_effect.add_child(guard_light)
	var ring_specs := [
		[0.79, 0.76, "guard_energy", 0.66],
		[0.65, 0.615, "guard_gold", -0.92],
		[0.49, 0.465, "guard_energy", 1.32],
	]
	for spec in ring_specs:
		var ring := _add_torus(guard_effect, Vector3.ZERO, spec[0], spec[1], spec[2])
		ring.rotation.x = PI * 0.5
		guard_rings.append(ring)
		ring.set_meta("spin_speed", spec[3])
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.045
	spark_mesh.height = 0.09
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	spark_material.albedo_color = Color("72e6d0")
	spark_material.emission_enabled = true
	spark_material.emission = Color("72e6d0")
	spark_material.emission_energy_multiplier = 1.7
	spark_material.blend_mode = StandardMaterial3D.BLEND_MODE_ADD
	spark_mesh.material = spark_material
	for index in range(5):
		var spark := MeshInstance3D.new()
		spark.name = "OrbeGiratorio%d" % index
		spark.mesh = spark_mesh
		spark.material_override = spark_material
		guard_effect.add_child(spark)
		guard_orbs.append(spark)
	var particle_process := ParticleProcessMaterial.new()
	particle_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	particle_process.emission_ring_axis = Vector3.UP
	particle_process.emission_ring_radius = 0.73
	particle_process.emission_ring_inner_radius = 0.54
	particle_process.emission_ring_height = 0.04
	particle_process.direction = Vector3.UP
	particle_process.spread = 26.0
	particle_process.initial_velocity_min = 0.06
	particle_process.initial_velocity_max = 0.32
	particle_process.orbit_velocity_min = 0.25
	particle_process.orbit_velocity_max = 0.72
	particle_process.gravity = Vector3.ZERO
	particle_process.scale_min = 0.48
	particle_process.scale_max = 1.15
	particle_process.color = Color("72e6d0")
	guard_particles = GPUParticles3D.new()
	guard_particles.name = "ParticulasArcanas"
	guard_particles.amount = 32
	guard_particles.lifetime = 0.9
	guard_particles.explosiveness = 0.0
	guard_particles.emitting = false
	guard_particles.process_material = particle_process
	guard_particles.draw_pass_1 = spark_mesh
	guard_particles.rotation.x = PI * 0.5
	guard_particles.position.z = -0.015
	guard_effect.add_child(guard_particles)
	for index in range(5):
		var sigil := MeshInstance3D.new()
		var sigil_mesh := SphereMesh.new()
		sigil_mesh.radius = 0.045
		sigil_mesh.height = 0.09
		sigil.mesh = sigil_mesh
		sigil.material_override = mats["guard_gold"]
		guard_effect.add_child(sigil)
		guard_orbs.append(sigil)


func _animate_guard_effect(delta: float) -> void:
	guard_particles.emitting = guard_effect.visible
	if not guard_effect.visible:
		return
	guard_time += delta
	for ring in guard_rings:
		ring.rotate_object_local(Vector3.UP, float(ring.get_meta("spin_speed")) * delta)
		var pulse := 1.0 + sin(guard_time * 4.0 + float(ring.get_meta("spin_speed"))) * 0.025
		ring.scale = Vector3.ONE * pulse
	for index in range(guard_orbs.size()):
		var orbit_speed := 1.05 if index < 5 else -0.72
		var radius := 0.72 if index < 5 else 0.48
		var angle := guard_time * orbit_speed + TAU * float(index % 5) / 5.0
		var orb := guard_orbs[index]
		orb.position = Vector3(cos(angle) * radius, sin(angle) * radius, -0.025)
		var pulse := 0.82 + (sin(guard_time * 5.5 + index) + 1.0) * 0.16
		orb.scale = Vector3.ONE * pulse
	guard_flash_timer = maxf(0.0, guard_flash_timer - delta)
	var flash := guard_flash_timer / 0.32
	(mats["guard_energy"] as StandardMaterial3D).emission_energy_multiplier = 1.25 + flash * 2.6
	(mats["guard_gold"] as StandardMaterial3D).emission_energy_multiplier = 0.9 + flash * 1.7
	guard_light.light_energy = 0.55 + 1.5 * (0.5 + 0.5 * sin(guard_time * 8.0)) + flash * 2.0


func _trigger_guard_spell() -> void:
	guard_flash_timer = 0.32
	if guard_particles:
		guard_particles.restart()
		guard_particles.emitting = true
	_spawn_pixel_burst(player.global_position + Vector3(0, 1.0, 0) - player.global_basis.z * 0.8, Color("7cf4dc"), 18, 2.7, 3.4, 0.48)
	_spawn_pixel_ring(player.global_position + Vector3(0, 0.08, 0), Color("e4ce83"), 2.4, 0.44)


func _spawn_pixel_burst(at: Vector3, tint: Color, count: int = 10, speed: float = 2.4, light_range: float = 2.2, duration: float = 0.38) -> void:
	# Short-lived, unshaded square motes read clearly after the low-resolution
	# world pass and reuse one tiny mesh/material per burst.
	var effect := Node3D.new()
	effect.name = "DestelloDePixeles"
	add_child(effect)
	effect.global_position = at
	var particle := CPUParticles3D.new()
	particle.name = "Chispas"
	particle.amount = count
	particle.lifetime = duration
	particle.one_shot = true
	particle.explosiveness = 0.92
	particle.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particle.emission_sphere_radius = 0.10
	particle.direction = Vector3.UP
	particle.spread = 180.0
	particle.initial_velocity_min = speed * 0.42
	particle.initial_velocity_max = speed
	particle.gravity = Vector3(0, -3.8, 0)
	particle.damping_min = 1.5
	particle.damping_max = 3.0
	particle.scale_amount_min = 0.55
	particle.scale_amount_max = 1.35
	particle.color = tint
	particle.local_coords = true
	var fade := Gradient.new()
	fade.set_color(0, tint)
	fade.add_point(0.68, Color(tint.r, tint.g, tint.b, 0.9))
	fade.set_color(1, Color(tint.r, tint.g, tint.b, 0.0))
	particle.color_ramp = fade
	var mote := BoxMesh.new()
	mote.size = Vector3(0.105, 0.105, 0.105)
	var mote_material := StandardMaterial3D.new()
	mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_material.albedo_color = tint
	mote_material.emission_enabled = true
	mote_material.emission = tint
	mote_material.emission_energy_multiplier = 1.35
	mote.material = mote_material
	particle.mesh = mote
	effect.add_child(particle)
	if light_range > 0.0:
		var light := OmniLight3D.new()
		light.name = "PulsoDeLuz"
		light.light_color = tint
		light.light_energy = 1.8
		light.omni_range = light_range
		light.shadow_enabled = false
		light.position.y = 0.35
		effect.add_child(light)
		var fade_light := create_tween()
		fade_light.tween_property(light, "light_energy", 0.0, minf(duration, 0.28)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	particle.emitting = true
	get_tree().create_timer(duration + 0.22).timeout.connect(func():
		if is_instance_valid(effect):
			effect.queue_free()
	)


func _spawn_pixel_ring(at: Vector3, tint: Color, radius: float, duration: float = 0.38, horizontal: bool = false) -> void:
	var ripple := MeshInstance3D.new()
	ripple.name = "AroDeChispa"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.37
	mesh.outer_radius = 0.43
	mesh.rings = 12
	mesh.ring_segments = 6
	ripple.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(tint.r, tint.g, tint.b, 0.9)
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 1.25
	ripple.material_override = material
	ripple.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ripple.scale = Vector3.ONE * 0.35
	if horizontal:
		ripple.rotation.x = PI * 0.5
	add_child(ripple)
	ripple.global_position = at
	var expansion := create_tween().set_parallel(true)
	expansion.tween_property(ripple, "scale", Vector3.ONE * (radius / 0.4), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	expansion.tween_property(material, "albedo_color", Color(tint.r, tint.g, tint.b, 0.0), duration)
	get_tree().create_timer(duration + 0.05).timeout.connect(func():
		if is_instance_valid(ripple):
			ripple.queue_free()
	)


func _make_illustrated_sprite(parent: Node3D, texture_path: String, pixel_size: float, height: float, frame_grid: Vector2i = Vector2i.ONE, initial_frame: Vector2i = Vector2i.ZERO) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = "PersonajeIlustrado"
	sprite.texture = load(texture_path)
	sprite.hframes = frame_grid.x
	sprite.vframes = frame_grid.y
	sprite.frame_coords = initial_frame
	sprite.pixel_size = pixel_size
	sprite.position.y = height
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.alpha_scissor_threshold = 0.18
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(sprite)
	return sprite


func _build_cat() -> void:
	cat = Node3D.new()
	cat.name = "EspirituGato"
	cat.position = Vector3(-2.0, terrain_builder.terrain_height_at(-2.0, 59.0), 59.0)
	add_child(cat)
	cat_illustration = _make_illustrated_sprite(cat, "res://assets/created/isometric/pixel_nimbo.png", 0.0009, 0.48)
	cat_walk_target = cat.position


func _build_encounter() -> void:
	enemy = Node3D.new()
	enemy.name = "BandidoDelBosque"
	enemy.position = Vector3(8, 0.0, -44)
	add_child(enemy)
	bandit_illustration = _make_illustrated_sprite(enemy, "res://assets/created/isometric/pixel_bandit_walk_sheet.png", 0.00145, 1.05, Vector2i(4, 3), Vector2i(1, 0))
	enemy_previous_position = enemy.global_position
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
	enemy_warning.material_override = (mats["enemy_glow"] as StandardMaterial3D).duplicate()
	enemy_warning.visible = false


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
		var pickup_light := OmniLight3D.new()
		pickup_light.name = "LuzDelCarcaj"
		pickup_light.position.y = 0.55
		pickup_light.light_color = Color("d8e7a7")
		pickup_light.light_energy = 0.38
		pickup_light.omni_range = 2.6
		pickup_light.shadow_enabled = false
		pickup.add_child(pickup_light)
		arrow_pickups.append(pickup)


func _build_pixel_display() -> void:
	var display := CanvasLayer.new()
	display.name = "PantallaPixel"
	display.layer = 1
	add_child(display)
	var overlay := ColorRect.new()
	overlay.name = "PixeladoDelMundo"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pixel_material := ShaderMaterial.new()
	pixel_material.shader = load("res://assets/shaders/pixel_world.gdshader")
	overlay.material = pixel_material
	display.add_child(overlay)


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 2
	add_child(hud)
	var journey_card := _make_hud_card(Vector2(22, 20), Vector2(360, 104), Color("b9a46e"))
	journey_card.set("ornamented", false)
	var heading := _label("RUMBO", Vector2(42, 32), 11, Color("c8b77e"))
	hud.add_child(heading)
	quest_label = _label("Santuario", Vector2(42, 49), 21, Color("f1ead5"))
	hud.add_child(quest_label)
	status_label = _label("Piedras guía  ·  0 / 3", Vector2(42, 78), 13, Color("cbd1b5"))
	hud.add_child(status_label)
	hp_label = _label("♥  ♥  ♥", Vector2(248, 49), 18, Color("e79a83"))
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_label.size = Vector2(112, 26)
	hud.add_child(hp_label)

	dialogue_panel = _make_hud_card(Vector2(226, 522), Vector2(828, 104), Color("b9a46e"))
	dialogue_panel.visible = false
	message_label = _label("", Vector2(254, 536), 18, Color("fff1ce"))
	message_label.size = Vector2(772, 76)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.add_child(message_label)

	interact_panel = _make_hud_card(Vector2(424, 642), Vector2(432, 48), Color("91ad78"))
	interact_panel.set("ornamented", false)
	interact_panel.visible = false
	interact_label = _label("", Vector2(440, 650), 16, Color("f5dfa8"))
	interact_label.size = Vector2(400, 30)
	interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(interact_label)

	ammo_panel = _make_hud_card(Vector2(1092, 22), Vector2(164, 58), Color("b9a46e"))
	ammo_panel.set("ornamented", false)
	ammo_panel.visible = false
	ammo_label = _label("➶  8", Vector2(1104, 33), 19, Color("f1dba5"))
	ammo_label.size = Vector2(140, 34)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ammo_label.visible = false
	hud.add_child(ammo_label)
	fps_label = _label("", Vector2(1070, 24), 17, Color("fff1ce"))
	fps_label.visible = false
	hud.add_child(fps_label)
	_build_pickup_notification()
	_build_pause_overlay()
	_build_inventory_overlay()
	# Keep this reference alive and document the dedicated journey card in-tree.
	journey_card.name = "PlacaDeRuta"


func _build_pickup_notification() -> void:
	pickup_notification = Panel.new()
	pickup_notification.name = "AvisoObjetoObtenido"
	pickup_notification.set_script(FOREST_UI_CARD)
	pickup_notification.set("accent_color", Color("b9a46e"))
	pickup_notification.set("ornamented", false)
	pickup_notification.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pickup_notification.offset_left = -350
	pickup_notification.offset_top = 96
	pickup_notification.offset_right = -24
	pickup_notification.offset_bottom = 180
	pickup_notification.modulate.a = 0.0
	pickup_notification.visible = false
	pickup_notification.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(pickup_notification)
	pickup_notification_icon = TextureRect.new()
	pickup_notification_icon.position = Vector2(14, 20)
	pickup_notification_icon.size = Vector2(50, 50)
	pickup_notification_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pickup_notification_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pickup_notification_icon.texture = load(ITEM_CATALOG["flechas"]["icon"])
	pickup_notification.add_child(pickup_notification_icon)
	var heading := _label("OBJETO OBTENIDO", Vector2(78, 22), 11, Color("c8b77e"))
	pickup_notification.add_child(heading)
	pickup_notification_name = _label("Flechas", Vector2(78, 39), 18, Color("f1ead5"))
	pickup_notification.add_child(pickup_notification_name)
	pickup_notification_amount = _label("+8", Vector2(252, 43), 17, Color("b9d59c"))
	pickup_notification_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pickup_notification_amount.size = Vector2(52, 24)
	pickup_notification.add_child(pickup_notification_amount)


func _build_inventory_overlay() -> void:
	inventory_overlay = Control.new()
	inventory_overlay.name = "Inventario"
	inventory_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_overlay.visible = false
	inventory_overlay.z_index = 30
	hud.add_child(inventory_overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.012, 0.023, 0.019, 0.88)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_overlay.add_child(shade)
	var frame := _make_inventory_card(Vector2(22, 18), Vector2(1236, 684), Color("b9a46e"))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := _label("EQUIPO Y MOCHILA", Vector2(48, 31), 25, Color("f1dba5"))
	inventory_overlay.add_child(title)
	var close_button := _make_ui_button("Cerrar  ·  I / Esc", false)
	close_button.position = Vector2(1014, 27)
	close_button.custom_minimum_size = Vector2(210, 40)
	close_button.add_theme_font_size_override("font_size", 15)
	inventory_overlay.add_child(close_button)
	close_button.pressed.connect(func() -> void: _toggle_inventory(false))
	var equipment := _make_inventory_card(Vector2(42, 84), Vector2(560, 592), Color("91ad78"))
	var equipment_heading := _label("EQUIPAMIENTO", Vector2(61, 103), 15, Color("c8b77e"))
	inventory_overlay.add_child(equipment_heading)
	_add_princess_front()
	_add_body_slot("Cabeza", Vector2(78, 154), "head")
	_add_body_slot("Amuleto", Vector2(78, 232), "amulet")
	_add_body_slot("Mano izq.", Vector2(78, 310), "bow")
	_add_body_slot("Mano der.", Vector2(78, 388), "staff")
	_add_body_slot("Anillo", Vector2(78, 466), "ring")
	_add_body_slot("Hombros", Vector2(448, 184), "shoulders")
	_add_body_slot("Armadura", Vector2(448, 262), "armor")
	_add_body_slot("Guantes", Vector2(448, 340), "gloves")
	_add_body_slot("Piernas", Vector2(448, 418), "legs")
	_add_body_slot("Botas", Vector2(448, 496), "boots")
	var stats := _make_inventory_card(Vector2(622, 84), Vector2(616, 192), Color("b9a46e"))
	inventory_overlay.add_child(_label("ESTADÍSTICAS", Vector2(642, 103), 15, Color("c8b77e")))
	inventory_health_label = _label("", Vector2(650, 137), 18, Color("f1ead5"))
	inventory_overlay.add_child(inventory_health_label)
	inventory_weapon_label = _label("", Vector2(650, 168), 16, Color("f1ead5"))
	inventory_overlay.add_child(inventory_weapon_label)
	inventory_attack_label = _label("", Vector2(935, 137), 16, Color("b9d59c"))
	inventory_overlay.add_child(inventory_attack_label)
	inventory_arrows_label = _label("", Vector2(935, 168), 16, Color("b9d59c"))
	inventory_overlay.add_child(inventory_arrows_label)
	var backpack := _make_inventory_card(Vector2(622, 292), Vector2(616, 384), Color("91ad78"))
	inventory_overlay.add_child(_label("MOCHILA", Vector2(642, 311), 16, Color("c8b77e")))
	inventory_capacity_label = _label("", Vector2(1038, 313), 14, Color("f1ead5"))
	inventory_capacity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	inventory_capacity_label.size = Vector2(174, 22)
	inventory_overlay.add_child(inventory_capacity_label)
	var capacity_track := ColorRect.new()
	capacity_track.position = Vector2(20, 52)
	capacity_track.size = Vector2(574, 8)
	capacity_track.color = Color("26382e")
	backpack.add_child(capacity_track)
	inventory_capacity_fill = ColorRect.new()
	inventory_capacity_fill.size = Vector2(0, 8)
	inventory_capacity_fill.color = Color("b8ca82")
	capacity_track.add_child(inventory_capacity_fill)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(18, 70)
	scroll.size = Vector2(580, 294)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	backpack.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	for slot_index in range(BACKPACK_MAX_CAPACITY):
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(87, 66)
		slot.focus_mode = Control.FOCUS_NONE
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_theme_stylebox_override("normal", _ui_button_style(Color("26382e")))
		grid.add_child(slot)
		inventory_item_slots.append(slot)
	_refresh_inventory_panel()


func _make_inventory_card(at: Vector2, card_size: Vector2, accent: Color) -> Panel:
	var card := Panel.new()
	card.set_script(FOREST_UI_CARD)
	card.set("accent_color", accent)
	card.set("ornamented", false)
	card.position = at
	card.size = card_size
	inventory_overlay.add_child(card)
	return card


func _add_princess_front() -> void:
	var sheet := load("res://assets/created/isometric/princess_painted_walk_sheet.png") as Texture2D
	if sheet == null:
		return
	var cell_size := Vector2(sheet.get_width() / 4.0, sheet.get_height() / 3.0)
	var front := AtlasTexture.new()
	front.atlas = sheet
	front.region = Rect2(Vector2(cell_size.x, 0.0), cell_size)
	var portrait := TextureRect.new()
	portrait.name = "PrincesaDeFrente"
	portrait.position = Vector2(172, 143)
	portrait.size = Vector2(300, 490)
	portrait.texture = front
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_overlay.add_child(portrait)


func _add_body_slot(slot_name: String, at: Vector2, item_id: String) -> void:
	var button := Button.new()
	button.position = at
	button.custom_minimum_size = Vector2(68, 58)
	button.size = Vector2(68, 58)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _ui_button_style(Color("26382e")))
	button.add_theme_stylebox_override("hover", _ui_button_style(Color("53634a")))
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", Color("c8b77e"))
	button.text = "·"
	inventory_overlay.add_child(button)
	var label := _label(slot_name, at + Vector2(-5, 57), 10, Color("c8b77e"))
	label.size = Vector2(80, 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inventory_overlay.add_child(label)
	if item_id == "bow" or item_id == "staff":
		var icon := TextureRect.new()
		icon.position = Vector2(18, 11)
		icon.size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = load("res://assets/ui/items/bow.svg" if item_id == "bow" else "res://assets/ui/items/staff.svg")
		button.add_child(icon)
		button.text = ""
		button.pressed.connect(func() -> void: _select_inventory_weapon(item_id))
		if item_id == "bow":
			inventory_bow_button = button
			inventory_bow_state = label
		else:
			inventory_staff_button = button
			inventory_staff_state = label


func _refresh_inventory_panel() -> void:
	if is_instance_valid(inventory_bow_state):
		inventory_bow_state.text = "Activo" if bow_equipped else "Listo"
		inventory_staff_state.text = "Listo" if bow_equipped else "Activo"
		inventory_bow_button.add_theme_stylebox_override("normal", _ui_button_style(Color("53634a") if bow_equipped else Color("26382e")))
		inventory_staff_button.add_theme_stylebox_override("normal", _ui_button_style(Color("26382e") if bow_equipped else Color("53634a")))
	if is_instance_valid(inventory_health_label):
		inventory_health_label.text = "Vida     %s" % "♥".repeat(player_hp) + "  %s" % "·".repeat(maxi(0, 3 - player_hp))
		inventory_weapon_label.text = "En mano  Arco" if bow_equipped else "En mano  Bastón"
		inventory_attack_label.text = "Daño     1"
		inventory_arrows_label.text = "Flechas  %d" % arrows_remaining
	var used_slots := _backpack_used_slots()
	if is_instance_valid(inventory_capacity_label):
		inventory_capacity_label.text = "%d / %d espacios" % [used_slots, backpack_capacity]
		inventory_capacity_fill.size.x = 574.0 * float(used_slots) / float(maxi(1, backpack_capacity))
	for slot in inventory_item_slots:
		slot.text = ""
		slot.disabled = inventory_item_slots.find(slot) >= backpack_capacity
		slot.modulate = Color(1, 1, 1, 1) if not slot.disabled else Color(0.52, 0.57, 0.49, 0.65)
		for child in slot.get_children():
			child.queue_free()
	var item_ids: Array = collected_items.keys()
	item_ids.sort()
	var slot_index := 0
	for item_id in item_ids:
		var amount := int(collected_items[item_id])
		if amount <= 0 or not ITEM_CATALOG.has(item_id):
			continue
		var data: Dictionary = ITEM_CATALOG[item_id]
		var stack_limit := maxi(1, int(data.get("stack_limit", 1)))
		var stacks := ceili(float(amount) / float(stack_limit))
		for stack_index in range(stacks):
			if slot_index >= inventory_item_slots.size():
				return
			var slot := inventory_item_slots[slot_index]
			var icon := TextureRect.new()
			icon.position = Vector2(24, 8)
			icon.size = Vector2(38, 36)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture = load(data["icon"])
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(icon)
			var stack_amount := mini(stack_limit, amount - stack_index * stack_limit)
			var amount_label := Label.new()
			amount_label.position = Vector2(3, 45)
			amount_label.size = Vector2(80, 17)
			amount_label.text = "%s · %d" % [String(data["name"]), stack_amount]
			amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			amount_label.add_theme_font_size_override("font_size", 10)
			amount_label.add_theme_color_override("font_color", Color("f1ead5"))
			amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(amount_label)
			slot_index += 1


func _backpack_used_slots() -> int:
	var used := 0
	for item_id in collected_items:
		var amount := int(collected_items[item_id])
		if amount <= 0:
			continue
		var stack_limit := int(ITEM_CATALOG.get(item_id, {}).get("stack_limit", 1))
		used += ceili(float(amount) / float(maxi(1, stack_limit)))
	return used


func expand_backpack(extra_slots: int) -> void:
	if extra_slots <= 0:
		return
	backpack_capacity = mini(backpack_capacity + extra_slots, BACKPACK_MAX_CAPACITY)
	_refresh_inventory_panel()


func _select_inventory_weapon(item_id: String) -> void:
	if item_id != "bow" and item_id != "staff":
		return
	bow_equipped = item_id == "bow"
	_refresh_inventory_panel()


func _grant_item(item_id: String, amount: int) -> bool:
	if amount <= 0 or not ITEM_CATALOG.has(item_id):
		return false
	var current_amount := int(collected_items.get(item_id, 0))
	var next_amount := current_amount + amount
	var stack_limit := maxi(1, int(ITEM_CATALOG[item_id].get("stack_limit", 1)))
	var next_slots := _backpack_used_slots() - ceili(float(current_amount) / float(stack_limit)) + ceili(float(next_amount) / float(stack_limit))
	if next_slots > backpack_capacity:
		_show_message("La mochila está llena. Busca una ampliación para llevar más.", 2.8)
		return false
	collected_items[item_id] = next_amount
	if item_id == "flechas":
		arrows_remaining = int(collected_items[item_id])
	GameAudio.play_at("pickup", player.global_position + Vector3(0, 1.1, 0), self)
	_spawn_pixel_burst(player.global_position + Vector3(0, 1.0, 0), Color("f2d987"), 14, 2.2, 2.8, 0.48)
	_spawn_pixel_ring(player.global_position + Vector3(0, 0.06, 0), Color("bce89a"), 1.8, 0.36)
	_refresh_inventory_panel()
	_show_pickup_notification(item_id, amount)
	return true


func _show_pickup_notification(item_id: String, amount: int) -> void:
	if not ITEM_CATALOG.has(item_id):
		return
	var data: Dictionary = ITEM_CATALOG[item_id]
	if pickup_notification_tween and pickup_notification_tween.is_running():
		pickup_notification_tween.kill()
	pickup_notification_icon.texture = load(data["icon"])
	pickup_notification_name.text = String(data["name"])
	pickup_notification_amount.text = "+%d" % amount
	pickup_notification.modulate.a = 0.0
	pickup_notification.visible = true
	pickup_notification_tween = create_tween()
	pickup_notification_tween.tween_property(pickup_notification, "modulate:a", 1.0, 0.18)
	pickup_notification_tween.tween_interval(2.25)
	pickup_notification_tween.tween_property(pickup_notification, "modulate:a", 0.0, 0.3)
	pickup_notification_tween.tween_callback(func() -> void: pickup_notification.visible = false)


func _make_hud_card(at: Vector2, card_size: Vector2, accent: Color) -> Panel:
	var card := Panel.new()
	card.set_script(FOREST_UI_CARD)
	card.set("accent_color", accent)
	card.position = at
	card.size = card_size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(card)
	return card


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
	resume.pressed.connect(func() -> void: _toggle_pause(false))
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
	style.bg_color = Color(0.035, 0.055, 0.045, 0.96)
	style.border_color = Color("b9a46e")
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.shadow_color = Color(0.01, 0.025, 0.02, 0.45)
	style.shadow_size = 0
	style.shadow_offset = Vector2(0, 4)
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
	button.pressed.connect(func() -> void: GameAudio.play_ui("ui_confirm"))
	button.mouse_entered.connect(func() -> void: GameAudio.play_ui("ui_hover"))
	return button


func _ui_button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("c4aa72")
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
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
	_animate_illustrations(delta)
	if fps_label.visible:
		var fps := Engine.get_frames_per_second()
		fps_label.text = "%d FPS  ·  %.1f ms" % [fps, 1000.0 / maxf(float(fps), 1.0)]
	if (game_won or game_over) and Input.is_action_just_pressed("interact"):
		get_tree().reload_current_scene()
		return
	if Input.is_action_just_pressed("inventory") and not paused and not game_won and not game_over:
		_toggle_inventory()
	if Input.is_action_just_pressed("pause") and not game_won and not game_over:
		if inventory_open:
			_toggle_inventory()
		else:
			_toggle_pause()
	if paused or inventory_open or game_won or game_over:
		_reset_player_footstep_tracking()
		return
	if Input.is_action_just_pressed("bow_toggle"):
		_toggle_bow()
	# Drawing the bow immediately enters the close aiming stance and camera.
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
	var guard_requested := Input.is_action_pressed("block") and dodge_timer <= 0.0 and not bow_equipped
	if guard_requested and not guard_effect.visible:
		_spawn_pixel_burst(player.global_position + Vector3(0, 0.85, 0) - player.global_basis.z * 0.7, Color("76e5ce"), 10, 1.8, 1.6, 0.34)
	guard_effect.visible = guard_requested
	_animate_guard_effect(delta)
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
	_update_footstep_audio()
	_update_enemy(delta)
	_animate_enemy_warning()
	_check_shrine()


func _animate_enemy_warning() -> void:
	if not is_instance_valid(enemy_warning) or not enemy_warning.visible:
		return
	var urgency := 1.0 - clampf(enemy_windup / 0.8, 0.0, 1.0)
	var pulse := 0.94 + (sin(illustration_time * 18.0) + 1.0) * 0.07
	enemy_warning.scale = Vector3.ONE * pulse
	var warning_material := enemy_warning.material_override as StandardMaterial3D
	if warning_material:
		warning_material.emission_energy_multiplier = 0.7 + urgency * 2.4


func _screen_direction(direction: Vector3, default_row: int) -> Dictionary:
	if direction.length_squared() < 0.01:
		return {"row": default_row, "flip": false}
	var center := player.global_position
	var projected := camera.unproject_position(center + direction) - camera.unproject_position(center)
	if absf(projected.x) > absf(projected.y) * 1.15:
		return {"row": 1, "flip": projected.x < 0.0}
	return {"row": 2 if projected.y < 0.0 else 0, "flip": false}


func _illustration_frame(sprite: Sprite3D, path: String, columns: int, rows: int, column: int, row: int, height: float) -> void:
	if not animation_textures.has(path):
		animation_textures[path] = load(path)
	var texture: Texture2D = animation_textures[path]
	if not texture:
		return
	if sprite.texture != texture or sprite.hframes != columns or sprite.vframes != rows:
		sprite.frame = 0
		sprite.hframes = 1
		sprite.vframes = 1
		sprite.texture = texture
		sprite.hframes = columns
		sprite.vframes = rows
	var desired_pixel_size := height / (float(texture.get_height()) / float(rows))
	if absf(sprite.pixel_size - desired_pixel_size) > 0.000001:
		sprite.pixel_size = desired_pixel_size
	sprite.frame_coords = Vector2i(clampi(column, 0, columns - 1), clampi(row, 0, rows - 1))


func _animate_illustrations(delta: float) -> void:
	if paused or inventory_open:
		return
	illustration_time += delta
	player_hit_time = maxf(0.0, player_hit_time - delta)
	enemy_attack_visual_recovery = maxf(0.0, enemy_attack_visual_recovery - delta)
	if is_instance_valid(princess_illustration):
		princess_illustration.modulate = Color(1.0, 0.55, 0.48) if player_hit_time > 0.0 else Color.WHITE
		var speed := Vector2(player.velocity.x, player.velocity.z).length()
		var moving := speed > 0.5 and dodge_timer <= 0.0
		if moving:
			illustrated_walk_distance += speed * delta
		var direction := _screen_direction(player.velocity, princess_direction_row)
		if moving:
			princess_direction_row = direction.row
			princess_illustration.flip_h = direction.flip
		var walk_frame := posmod(floori(illustrated_walk_distance / 0.55), 4)
		illustrated_walk_frame = walk_frame if moving and attack_cooldown <= 0.18 and bow_shoot_timer <= 0.0 else -1
		princess_illustration.position.y = PRINCESS_SPRITE_HEIGHT * 0.5
		princess_illustration.rotation.z = 0.0
		if dodge_timer > 0.0:
			var phase := clampi(floori((1.0 - dodge_timer / 0.34) * 4.0), 0, 3)
			_illustration_frame(princess_illustration, "res://assets/created/isometric/princess_painted_action_sheet.png", 4, 2, phase, 1, PRINCESS_SPRITE_HEIGHT)
		elif attack_cooldown > 0.18 and not bow_equipped:
			var phase := clampi(floori((0.48 - attack_cooldown) / 0.30 * 4.0), 0, 3)
			_illustration_frame(princess_illustration, "res://assets/created/isometric/princess_painted_action_sheet.png", 4, 2, phase, 0, PRINCESS_SPRITE_HEIGHT)
		elif Input.is_action_pressed("block") and not bow_equipped:
			_illustration_frame(princess_illustration, "res://assets/created/isometric/princess_painted_guard_sheet.png", 4, 1, walk_frame if moving else 0, 0, PRINCESS_SPRITE_HEIGHT)
		elif bow_equipped and bow_shoot_timer > 0.0:
			var phase := clampi(1 + floori((0.24 - bow_shoot_timer) / 0.24 * 3.0), 1, 3)
			_illustration_frame(princess_illustration, "res://assets/created/isometric/princess_painted_bow_shoot_sheet.png", 4, 1, phase, 0, PRINCESS_SPRITE_HEIGHT)
			if not using_gamepad:
				princess_illustration.flip_h = get_viewport().get_mouse_position().x < camera.unproject_position(player.global_position).x
		elif bow_equipped and not moving:
			_illustration_frame(princess_illustration, "res://assets/created/isometric/princess_painted_bow_shoot_sheet.png", 4, 1, 0, 0, PRINCESS_SPRITE_HEIGHT)
			if not using_gamepad:
				princess_illustration.flip_h = get_viewport().get_mouse_position().x < camera.unproject_position(player.global_position).x
		else:
			var sheet := "res://assets/created/isometric/princess_painted_bow_walk_sheet.png" if bow_equipped else "res://assets/created/isometric/princess_painted_walk_sheet.png"
			_illustration_frame(princess_illustration, sheet, 4, 3, walk_frame if moving else 1, princess_direction_row, PRINCESS_SPRITE_HEIGHT)
	if is_instance_valid(bandit_illustration):
		bandit_illustration.modulate = Color(1.0, 0.55, 0.48) if enemy_hit_timer > 0.0 and not enemy_defeated else Color.WHITE
		var enemy_movement := enemy.global_position - enemy_previous_position
		enemy_previous_position = enemy.global_position
		var facing := _screen_direction(enemy_movement, bandit_direction_row)
		if enemy_movement.length_squared() > 0.00001:
			bandit_direction_row = facing.row
			bandit_illustration.flip_h = facing.flip
		if enemy_defeated:
			enemy_death_time += delta
			var phase := clampi(floori(enemy_death_time / 0.8 * 4.0), 0, 3)
			_illustration_frame(bandit_illustration, "res://assets/created/isometric/pixel_bandit_action_sheet.png", 4, 2, phase, 1, 2.1)
		elif enemy_hit_timer > 0.0:
			_illustration_frame(bandit_illustration, "res://assets/created/isometric/pixel_bandit_action_sheet.png", 4, 2, 0, 1, 2.1)
		elif enemy_windup > 0.0:
			bandit_illustration.flip_h = camera.unproject_position(player.global_position).x < camera.unproject_position(enemy.global_position).x
			var phase := 0 if enemy_windup > 0.6 else (1 if enemy_windup > 0.15 else 2)
			_illustration_frame(bandit_illustration, "res://assets/created/isometric/pixel_bandit_action_sheet.png", 4, 2, phase, 0, 2.1)
		elif enemy_attack_visual_recovery > 0.0:
			_illustration_frame(bandit_illustration, "res://assets/created/isometric/pixel_bandit_action_sheet.png", 4, 2, 3, 0, 2.1)
		else:
			var frame := posmod(floori(illustration_time * 5.0), 4) if enemy_movement.length_squared() > 0.00001 else 1
			_illustration_frame(bandit_illustration, "res://assets/created/isometric/pixel_bandit_walk_sheet.png", 4, 3, frame, bandit_direction_row, 2.1)
	if is_instance_valid(cat_illustration):
		var walking: bool = cat.global_position.distance_to(cat_walk_target) > 0.2
		if walking:
			var facing := _screen_direction(cat_walk_target - cat.global_position, 1)
			cat_illustration.flip_h = facing.flip
			_illustration_frame(cat_illustration, "res://assets/created/isometric/pixel_nimbo_walk_sheet.png", 4, 1, posmod(floori(illustration_time * 7.0), 4), 0, 1.1)
		else:
			_illustration_frame(cat_illustration, "res://assets/created/isometric/pixel_nimbo.png", 1, 1, 0, 0, 0.92)


func _update_footstep_audio() -> void:
	if illustrated_walk_frame < 0 or not player.is_on_floor():
		previous_walk_frame = -1
		return
	if illustrated_walk_frame != previous_walk_frame and illustrated_walk_frame in [0, 2]:
		var surface := "water" if is_instance_valid(water_effects) and water_effects.in_water else "grass"
		GameAudio.play_at("step_%s_%d" % [surface, randi_range(1, 3)], player.global_position + Vector3(0, 0.08, 0), self, randf_range(0.93, 1.07), -5.0)
		if surface == "grass":
			var foot_offset := player.global_basis.x * (-0.13 if illustrated_walk_frame == 0 else 0.13)
			_spawn_pixel_burst(player.global_position + foot_offset + Vector3(0, 0.10, 0), Color("d7ce9a"), 3, 0.62, 0.0, 0.23)
	previous_walk_frame = illustrated_walk_frame


func _reset_player_footstep_tracking() -> void:
	previous_walk_frame = -1


func _physics_process(delta: float) -> void:
	if player.global_position.y < -8.0:
		player.global_position = last_safe_position + Vector3(0, 0.1, 0)
		player.velocity = Vector3.ZERO
		_show_message("Nimbo te devuelve al último lugar seguro del bosque.", 2.5)
	if paused or inventory_open or game_won or game_over:
		player.velocity.x = move_toward(player.velocity.x, 0.0, WALK_SPEED * 6.0 * delta)
		player.velocity.z = move_toward(player.velocity.z, 0.0, WALK_SPEED * 6.0 * delta)
		player.move_and_slide()
		_update_camera_follow_target()
		return
	if bow_fire_requested:
		bow_fire_requested = false
		_shoot_arrow()
	var direction := Vector3.ZERO
	if not click_path.is_empty() and dodge_timer <= 0.0:
		var to_point := click_path[0] - player.global_position
		to_point.y = 0.0
		if to_point.length() < 0.06:
			player.global_position.x = click_path[0].x
			player.global_position.z = click_path[0].z
			player.velocity.x = 0.0
			player.velocity.z = 0.0
			click_path.remove_at(0)
			if click_path.is_empty():
				destination_marker.visible = false
		else:
			direction = to_point.normalized()
	if direction.length() > 0.1 and dodge_timer <= 0.0:
		last_move_direction = direction.normalized()
	var movement_speed := WALK_SPEED
	if bow_equipped:
		movement_speed = 2.8
	elif Input.is_action_pressed("block"):
		movement_speed *= 0.45
	var speed := movement_speed
	if not click_path.is_empty() and dodge_timer <= 0.0:
		var remaining := Vector2(click_path[0].x - player.global_position.x, click_path[0].z - player.global_position.z).length()
		speed = minf(speed, remaining / maxf(delta, 0.001))
	var target := dodge_direction * DODGE_SPEED if dodge_timer > 0.0 else direction * speed
	player.velocity.x = target.x
	player.velocity.z = target.z
	if not player.is_on_floor():
		player.velocity.y -= 22.0 * delta
	else:
		player.velocity.y = -0.2
	var facing_direction := dodge_direction if dodge_timer > 0.0 else direction
	if bow_equipped and direction.length() < 0.1 and not using_gamepad:
		var aim := _mouse_ground_point()
		if aim != Vector3.INF:
			facing_direction = aim - player.global_position
	facing_direction.y = 0.0
	if facing_direction.length() > 0.1:
		player.rotation.y = lerp_angle(player.rotation.y, atan2(-facing_direction.x, -facing_direction.z), delta * (18.0 if dodge_timer > 0.0 else 10.0))
	player.move_and_slide()
	_update_camera_follow_target()
	if player.is_on_floor() and absf(player.global_position.x) < 89.0 and player.global_position.z > -106.0 and player.global_position.z < 86.0:
		last_safe_position = player.global_position
func _update_camera_follow_target() -> void:
	if not is_instance_valid(camera_pivot) or not is_instance_valid(player):
		return
	camera_pivot.global_position = player.global_position + Vector3(0, 1.0, 0)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		using_gamepad = true
	elif event is InputEventKey or event is InputEventMouseMotion or event is InputEventMouseButton:
		using_gamepad = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not paused and not inventory_open and not game_won and not game_over:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var point := _mouse_ground_point()
			if point != Vector3.INF:
				_set_click_destination(point)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			var point := _mouse_ground_point()
			if point != Vector3.INF:
				var direction := point - player.global_position
				direction.y = 0.0
				if direction.length() > 0.2:
					last_move_direction = direction.normalized()
				_dodge()
		elif event.button_index == MOUSE_BUTTON_RIGHT and bow_equipped:
			bow_fire_requested = true
	elif event.is_action_pressed("bow_fire") and event is InputEventJoypadMotion and bow_equipped:
		bow_fire_requested = true


func _mouse_ground_point() -> Vector3:
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(mouse) * 160.0, 1, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else Vector3.INF


func _build_navigation_grid() -> void:
	navigation_grid = AStarGrid2D.new()
	navigation_grid.region = Rect2i(0, 0, NAV_WIDTH, NAV_DEPTH)
	# Let the click-to-move route cross square cells on diagonals while still
	# refusing corner cuts where two solid cells meet.
	navigation_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation_grid.update()
	var probe := CylinderShape3D.new()
	probe.radius = 0.62
	probe.height = 1.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	var space := get_world_3d().direct_space_state
	for x in range(NAV_WIDTH):
		for z in range(NAV_DEPTH):
			var point := _grid_world(Vector2i(x, z))
			point.y = terrain_builder.terrain_height_at(point.x, point.z) + 0.9
			query.transform = Transform3D(Basis.IDENTITY, point)
			if not space.intersect_shape(query, 1).is_empty():
				navigation_grid.set_point_solid(Vector2i(x, z))


func _grid_world(cell: Vector2i) -> Vector3:
	return Vector3(NAV_ORIGIN.x + cell.x * NAV_CELL, 0, NAV_ORIGIN.y + cell.y * NAV_CELL)


func _nearest_open_cell(point: Vector3) -> Vector2i:
	var cell := Vector2i(clampi(roundi((point.x - NAV_ORIGIN.x) / NAV_CELL), 0, NAV_WIDTH - 1), clampi(roundi((point.z - NAV_ORIGIN.y) / NAV_CELL), 0, NAV_DEPTH - 1))
	for radius in range(5):
		var best := Vector2i(-1, -1)
		var best_distance := INF
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				var candidate := cell + Vector2i(x, z)
				if not navigation_grid.is_in_boundsv(candidate) or navigation_grid.is_point_solid(candidate):
					continue
				var distance := _grid_world(candidate).distance_squared_to(Vector3(point.x, 0, point.z))
				if distance < best_distance:
					best = candidate
					best_distance = distance
		if best.x >= 0:
			return best
	return Vector2i(-1, -1)


func _set_click_destination(point: Vector3) -> void:
	if navigation_grid == null:
		_build_navigation_grid()
	var start := _nearest_open_cell(player.global_position)
	var end := _nearest_open_cell(point)
	if start.x < 0 or end.x < 0:
		return
	var cells := navigation_grid.get_id_path(start, end)
	if cells.is_empty():
		_show_message("No encuentro un camino hasta allí.", 2.0)
		return
	click_path.clear()
	for index in range(1, cells.size()):
		click_path.append(_grid_world(cells[index]))
	var destination := _grid_world(end)
	destination_marker.global_position = Vector3(destination.x, terrain_builder.terrain_height_at(destination.x, destination.z) + 0.12, destination.z)
	_spawn_pixel_ring(destination_marker.global_position + Vector3(0, 0.025, 0), Color("79eed0"), 1.7, 0.48, true)
	_spawn_pixel_burst(destination_marker.global_position + Vector3(0, 0.12, 0), Color("8df2d6"), 18, 1.8, 2.2, 0.56)
	if click_path.is_empty():
		destination_marker.visible = false
		return
	destination_marker.visible = true


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
		interact_label.text = ("A" if using_gamepad else "E") + "  ·  Hablar"
	elif near_interactable in sigils:
		interact_label.text = ("A" if using_gamepad else "E") + "  ·  Armonizar"
	elif near_interactable == gate:
		interact_label.text = ("A" if using_gamepad else "E") + "  ·  Examinar"
	elif near_interactable in arrow_pickups:
		interact_label.text = ("A" if using_gamepad else "E") + "  ·  Flechas"
	else:
		interact_label.text = ""
	interact_panel.visible = not interact_label.text.is_empty()


func _walk_cat_to(destination: Vector3) -> void:
	destination.y = terrain_builder.terrain_height_at(destination.x, destination.z)
	cat_walk_target = destination


func _update_cat_motion(delta: float) -> void:
	cat_vfx_step = maxf(0.0, cat_vfx_step - delta)
	var offset := cat_walk_target - cat.position
	offset.y = 0.0
	var is_walking := offset.length() > 0.08
	var is_running := is_walking and offset.length() > 7.0
	if is_walking:
		var direction := offset.normalized()
		cat.rotation.y = lerp_angle(cat.rotation.y, atan2(-direction.x, -direction.z), delta * 7.0)
		var travel_speed := 3.2 if is_running else 2.25
		var step := minf(travel_speed * delta, offset.length())
		cat.position += direction * step
		cat.position.y = terrain_builder.terrain_height_at(cat.position.x, cat.position.z)
		if cat_vfx_step <= 0.0:
			cat_vfx_step = 0.42
			_spawn_pixel_burst(cat.global_position + Vector3(0, 0.32, 0), Color("88e7cb"), 4, 0.8, 0.55, 0.32)
	else:
		var to_player := player.global_position - cat.global_position
		to_player.y = 0.0
		if to_player.length() > 0.1:
			cat.rotation.y = lerp_angle(cat.rotation.y, atan2(-to_player.x, -to_player.z), delta * 2.5)


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
		if _grant_item("flechas", int(near_interactable.get_meta("arrow_count", 8))):
			near_interactable.visible = false


func _cat_speak() -> void:
	GameAudio.play_at("nimbo_call", cat.global_position + Vector3(0, 0.7, 0), self)
	_spawn_pixel_burst(cat.global_position + Vector3(0, 0.82, 0), Color("8ce9cb"), 16, 1.8, 2.6, 0.64)
	_spawn_pixel_ring(cat.global_position + Vector3(0, 0.04, 0), Color("b7e6a1"), 1.8, 0.48)
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
	if bow_equipped:
		_spawn_pixel_burst(player.global_position + Vector3(0, 1.3, 0), Color("eed08b"), 9, 1.4, 1.7, 0.32)
		_show_message("Arco listo. Apunta con el cursor y dispara con clic derecho.", 3.0)
	else:
		_show_message("Guardas el arco y vuelves al bastón.", 1.8)
	_refresh_inventory_panel()


func _shoot_arrow() -> void:
	if not bow_equipped or bow_cooldown > 0.0:
		return
	if arrows_remaining <= 0:
		_show_message("No quedan flechas. Busca un carcaj junto al sendero.", 2.0)
		return
	arrows_remaining -= 1
	collected_items["flechas"] = arrows_remaining
	_refresh_inventory_panel()
	bow_cooldown = 0.42
	bow_shoot_timer = 0.24
	GameAudio.play_at("arrow_release", player.global_position + Vector3(0, 1.3, 0), self, randf_range(0.96, 1.04))
	var center := get_viewport().get_visible_rect().size * 0.5 if using_gamepad else get_viewport().get_mouse_position()
	var ray_origin := camera.project_ray_origin(center)
	var ray_direction := camera.project_ray_normal(center)
	var ray_end := ray_origin + ray_direction * 80.0
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, 3, [player.get_rid()])
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var aim_hit := get_world_3d().direct_space_state.intersect_ray(query)
	var aim_point: Vector3 = aim_hit.position if not aim_hit.is_empty() else ray_end
	var launch := player.global_position + Vector3(0, 1.25, 0) - player.global_basis.z * 0.16
	_spawn_pixel_burst(launch, Color("e5d492"), 7, 1.8, 1.7, 0.28)
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
	_add_arrow_spark_trail(arrow)
	var travel_time := clampf(launch.distance_to(destination) / 38.0, 0.07, 1.6)
	var flight := create_tween()
	flight.tween_property(arrow, "global_position", destination, travel_time)
	flight.finished.connect(func():
		if hit_enemy:
			_arrow_hits_enemy()
		else:
			GameAudio.play_at("arrow_impact", destination, self, 1.0, -5.0)
			_spawn_pixel_burst(destination, Color("d4dca2"), 8, 1.7, 1.5, 0.3)
		if is_instance_valid(arrow):
			arrow.queue_free()
	)


func _add_arrow_spark_trail(arrow: Node3D) -> void:
	var trail := CPUParticles3D.new()
	trail.name = "EstelaDeChispas"
	trail.amount = 14
	trail.lifetime = 0.2
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.025
	trail.direction = Vector3(0, 0, 1)
	trail.spread = 18.0
	trail.initial_velocity_min = 0.12
	trail.initial_velocity_max = 0.52
	trail.gravity = Vector3.ZERO
	trail.scale_amount_min = 0.35
	trail.scale_amount_max = 0.8
	trail.color = Color("e8ce83")
	var mote := BoxMesh.new()
	mote.size = Vector3(0.055, 0.055, 0.055)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("e8ce83")
	material.emission_enabled = true
	material.emission = Color("e8ce83")
	material.emission_energy_multiplier = 1.4
	mote.material = material
	trail.mesh = mote
	arrow.add_child(trail)
	trail.emitting = true


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
	if not is_instance_valid(enemy) or not enemy.visible or enemy_defeated:
		return
	GameAudio.play_at("arrow_impact", enemy.global_position + Vector3(0, 0.9, 0), self, 1.0, -1.5)
	GameAudio.play_at("bandit_hit", enemy.global_position + Vector3(0, 1.0, 0), self, randf_range(0.95, 1.05))
	_spawn_pixel_burst(enemy.global_position + Vector3(0, 1.0, 0), Color("ffc47e"), 20, 3.2, 3.0, 0.44)
	_spawn_pixel_ring(enemy.global_position + Vector3(0, 0.07, 0), Color("d88d69"), 1.7, 0.36)
	enemy_hp -= 1
	enemy_windup = 0.0
	enemy_warning.visible = false
	enemy_recovery = 0.9
	enemy_hit_timer = 0.36
	if enemy_hp <= 0:
		_defeat_enemy("La flecha alcanza al bandido. Su cuerpo queda en el sendero.")
	else:
		_show_message("La flecha hace retroceder al bandido. Aún sigue en pie.", 2.0)


func _defeat_enemy(message: String) -> void:
	if enemy_defeated:
		return
	enemy_defeated = true
	enemy_hp = 0
	enemy_windup = 0.0
	enemy_hit_timer = 0.0
	GameAudio.play_at("bandit_death", enemy.global_position + Vector3(0, 0.8, 0), self)
	_spawn_pixel_burst(enemy.global_position + Vector3(0, 0.8, 0), Color("e5c881"), 24, 2.7, 3.7, 0.68)
	_spawn_pixel_ring(enemy.global_position + Vector3(0, 0.06, 0), Color("86c99b"), 2.2, 0.52)
	if is_instance_valid(enemy_warning):
		enemy_warning.visible = false
	if is_instance_valid(enemy):
		var hitbox := enemy.get_meta("arrow_hitbox", null) as Area3D
		if hitbox:
			hitbox.set_deferred("monitoring", false)
			hitbox.set_deferred("monitorable", false)
			for child in hitbox.get_children():
				if child is CollisionShape3D:
					(child as CollisionShape3D).set_deferred("disabled", true)
	_show_message(message, 3.0)


func _activate_sigil(stone: Node3D) -> void:
	var index := int(stone.get_meta("sigil_index"))
	if bool(stone.get_meta("active")):
		_show_message("La piedra ya canta con su nota tenue.", 2.0)
		return
	var expected := sigil_order[next_sigil]
	if index == expected:
		GameAudio.play_at("sigil_on", stone.global_position + Vector3(0, 0.6, 0), self, 1.0 + float(index) * 0.035)
		_spawn_pixel_burst(stone.global_position + Vector3(0, 1.1, 0), Color("c7f0bd"), 18, 2.7, 3.4, 0.5)
		_spawn_pixel_ring(stone.global_position + Vector3(0, 0.09, 0), Color("e4d38f"), 2.3, 0.52)
		stone.set_meta("active", true)
		var rune := stone.get_node("RunicGlow") as MeshInstance3D
		rune.visible = true
		rune.material_override = mats["gold"]
		rune.scale = Vector3.ONE * 1.35
		var activated_light := stone.get_node_or_null("RunicLight") as OmniLight3D
		if activated_light:
			activated_light.visible = true
		next_sigil += 1
		if next_sigil == sigil_order.size():
			shrine_open = true
			GameAudio.play_at("shrine_open", stone.global_position + Vector3(0, 1.0, 0), self)
			_spawn_pixel_burst(Vector3(0, 1.5, -85.5), Color("9cf0d0"), 34, 3.6, 5.5, 0.82)
			_spawn_pixel_ring(Vector3(0, 0.1, -85.5), Color("e5d18d"), 6.2, 0.9)
			GameAudio.play_music("sanctuary", 2.8)
			var gate := get_node("SantuarioCerrado") as Node3D
			gate.visible = false
			var gate_collision := gate.get_node_or_null("Colision")
			if gate_collision:
				gate_collision.queue_free()
			# The walkable cells change when the gate opens. Rebuild lazily on
			# the next destination after the queued collider has been removed.
			navigation_grid = null
			_show_message("Las tres notas se enlazan. El sello se disuelve y el santuario abre sus puertas.", 5.0)
		else:
			_show_message("La piedra responde. Una nota armoniosa despierta en el bosque.", 2.8)
	else:
		GameAudio.play_at("sigil_wrong", stone.global_position + Vector3(0, 0.6, 0), self)
		_spawn_pixel_burst(stone.global_position + Vector3(0, 0.85, 0), Color("de8b78"), 8, 1.55, 1.4, 0.3)
		for lit_stone in sigils:
			lit_stone.set_meta("active", false)
			var rune := lit_stone.get_node("RunicGlow") as MeshInstance3D
			rune.material_override = mats["spirit_dim"]
			rune.visible = false
			var reset_light := lit_stone.get_node_or_null("RunicLight") as OmniLight3D
			if reset_light:
				reset_light.visible = false
		next_sigil = 0
		_show_message("La nota se apaga. Nimbo dijo: luna, agua, semilla. Prueba esa secuencia.", 3.5)


func _attack() -> void:
	if attack_cooldown > 0.0:
		return
	attack_cooldown = 0.48
	GameAudio.play_at("staff_swing", player.global_position + Vector3(0, 1.0, 0), self, randf_range(0.94, 1.06))
	var swing_center := player.global_position + Vector3(0, 0.92, 0) - player.global_basis.z * 0.88
	_spawn_pixel_burst(swing_center, Color("b9e2a4"), 12, 2.7, 1.8, 0.28)
	_spawn_pixel_ring(player.global_position + Vector3(0, 0.07, 0), Color("d4c47e"), 1.35, 0.28)
	var to_enemy := enemy.global_position - player.global_position if is_instance_valid(enemy) else Vector3.ZERO
	to_enemy.y = 0
	if is_instance_valid(enemy) and enemy.visible and not enemy_defeated and to_enemy.length() < 2.35 and (-player.global_basis.z).dot(to_enemy.normalized()) > 0.2:
		GameAudio.play_at("staff_hit", enemy.global_position + Vector3(0, 0.9, 0), self)
		_spawn_pixel_burst(enemy.global_position + Vector3(0, 1.0, 0), Color("ffd18a"), 18, 3.2, 3.0, 0.42)
		_spawn_pixel_ring(enemy.global_position + Vector3(0, 0.08, 0), Color("e89e72"), 1.75, 0.34)
		GameAudio.play_at("bandit_hit", enemy.global_position + Vector3(0, 1.0, 0), self, randf_range(0.95, 1.05))
		enemy_hp -= 1
		enemy_windup = 0.0
		enemy_warning.visible = false
		enemy_recovery = 0.8
		enemy_hit_timer = 0.36
		enemy.position += -player.global_basis.z * 0.42
		if enemy_hp <= 0:
			_defeat_enemy("El bandido cae y queda tendido en el sendero.")
		else:
			_show_message("¡Golpe certero! El bandido retrocede, pero sigue peleando.", 1.8)
	else:
		_show_message("El bastón corta el aire. Acércate para alcanzar al bandido.", 1.5)


func _dodge() -> void:
	if dodge_timer > 0.0:
		return
	dodge_timer = 0.34
	dodge_direction = last_move_direction.normalized() if last_move_direction.length() > 0.1 else Vector3.FORWARD
	invulnerability = 0.6
	GameAudio.play_at("dodge", player.global_position + Vector3(0, 0.55, 0), self)
	_spawn_pixel_burst(player.global_position + Vector3(0, 0.72, 0), Color("a5e8c1"), 18, 3.8, 3.0, 0.46)
	_spawn_pixel_ring(player.global_position + Vector3(0, 0.06, 0), Color("d7e6a3"), 2.1, 0.34)


func _update_enemy(delta: float) -> void:
	if not is_instance_valid(enemy) or not enemy.visible or enemy_defeated:
		return
	var distance := player.global_position.distance_to(enemy.global_position)
	enemy_recovery = maxf(0.0, enemy_recovery - delta)
	enemy_hit_timer = maxf(0.0, enemy_hit_timer - delta)
	if enemy_hit_timer > 0.0:
		return
	if enemy_windup > 0.0:
		enemy_windup -= delta
		if enemy_windup <= 0.0:
			enemy_attack_visual_recovery = 0.2
			enemy_warning.visible = false
			enemy_recovery = 1.2
			if distance < 1.9 and invulnerability <= 0.0:
				var toward_threat := enemy.global_position - player.global_position
				toward_threat.y = 0
				if Input.is_action_pressed("block") and (-player.global_basis.z).dot(toward_threat.normalized()) > 0.1:
					GameAudio.play_at("guard", player.global_position + Vector3(0, 1.1, 0), self)
					GameAudio.play_at("bandit_attack", enemy.global_position + Vector3(0, 1.0, 0), self, 1.0, -5.0)
					_trigger_guard_spell()
					_show_message("El bastón detiene el golpe del bandido.", 1.6)
				else:
					player_hp -= 1
					player_hit_time = 0.32
					_spawn_pixel_burst(player.global_position + Vector3(0, 0.95, 0), Color("ed7a69"), 16, 2.6, 2.7, 0.38)
					_spawn_pixel_ring(player.global_position + Vector3(0, 0.06, 0), Color("e88368"), 1.6, 0.3)
					GameAudio.play_at("player_hurt", player.global_position + Vector3(0, 1.0, 0), self)
					GameAudio.play_at("bandit_attack", enemy.global_position + Vector3(0, 1.0, 0), self)
					invulnerability = 1.25
					_show_message("El bandido te alcanza. Esquiva o defiéndete con Q / LB.", 2.1)
					if player_hp <= 0:
						_game_ended(false)
		return
	if distance < 5.2 and distance > 1.05:
		enemy_vfx_step = maxf(0.0, enemy_vfx_step - delta)
		var direction := (player.global_position - enemy.global_position).normalized()
		enemy.position += direction * delta * 1.25
		if enemy_vfx_step <= 0.0:
			enemy_vfx_step = 0.48
			_spawn_pixel_burst(enemy.global_position + Vector3(0, 0.08, 0), Color("b6ab82"), 3, 0.48, 0.0, 0.22)
		enemy.look_at(Vector3(player.global_position.x, enemy.global_position.y, player.global_position.z), Vector3.UP)
	if distance < 1.7 and enemy_recovery <= 0.0:
		enemy_windup = 0.8
		enemy_warning.visible = true
		GameAudio.play_at("bandit_windup", enemy.global_position + Vector3(0, 1.0, 0), self)
		_spawn_pixel_burst(enemy.global_position + Vector3(0, 1.2, 0), Color("e88368"), 9, 1.25, 1.2, 0.38)
		_show_message("¡El bandido alza la daga! Esquiva para salir del círculo.", 1.0)


func _check_shrine() -> void:
	if shrine_open and player.global_position.distance_to(Vector3(0, 0, -89)) < 3.2:
		_game_ended(true)


func _game_ended(won: bool) -> void:
	game_won = won
	game_over = not won
	if won:
		GameAudio.play_ui("victory")
		GameAudio.play_music("sanctuary", 1.4)
	else:
		GameAudio.play_ui("game_over")
	_spawn_pixel_burst(player.global_position + Vector3(0, 0.9, 0), Color("f0d995") if won else Color("d98272"), 28, 2.8, 4.5, 0.84)
	_spawn_pixel_ring(player.global_position + Vector3(0, 0.07, 0), Color("b9e3a0") if won else Color("d98272"), 3.2, 0.82)
	GameAudio.set_paused(not won)
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
		hearts += "♥ " if i < player_hp else "· "
	hp_label.text = hearts.strip_edges()
	if shrine_open:
		quest_label.text = "Santuario"
		status_label.text = "Umbral abierto"
	else:
		quest_label.text = "Santuario"
		status_label.text = "Piedras guía  ·  %d / 3" % next_sigil
	ammo_label.text = "➶   %d" % arrows_remaining
	ammo_panel.visible = bow_equipped
	ammo_label.visible = bow_equipped


func _show_message(text_value: String, seconds: float) -> void:
	message_text = text_value
	message_label.text = text_value if is_instance_valid(message_label) else ""
	if is_instance_valid(dialogue_panel):
		dialogue_panel.visible = true
	message_timer = seconds


func _toggle_pause(play_pause_cue: bool = true) -> void:
	paused = not paused
	if play_pause_cue:
		GameAudio.play_ui("ui_pause")
	GameAudio.set_paused(paused)
	if paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		pause_menu_content.visible = true
		pause_options_panel.visible = false
		pause_overlay.visible = true
		(pause_menu_content.get_child(1) as Button).grab_focus()
	else:
		pause_overlay.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		message_timer = 0.0
		message_label.text = ""
		dialogue_panel.visible = false


func _toggle_inventory(play_confirm_cue: bool = true) -> void:
	if paused or game_won or game_over:
		return
	inventory_open = not inventory_open
	if play_confirm_cue:
		GameAudio.play_ui("ui_confirm")
	inventory_overlay.visible = inventory_open
	if inventory_open:
		_refresh_inventory_panel()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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
