extends RefCounted
## Large, deterministic forest layout built from low draw-call static batches.

const BATCH_SCRIPT := preload("res://scripts/scenery_batch.gd")
const NATURE := "res://assets/quaternius/nature/"
const DUNGEON := "res://assets/kaykit/dungeon/Assets/gltf/"
const RESOURCES := "res://assets/kaykit/resources/Assets/gltf/"

var root: Node3D
var batches: Node3D
var rng := RandomNumberGenerator.new()
var tree_colliders: StaticBody3D
var trunk_shape: CylinderShape3D
var solid_bodies: Dictionary = {}


func build(parent: Node3D) -> Dictionary:
	root = parent
	rng.seed = 783413
	batches = Node3D.new()
	batches.name = "VegetacionAgrupada"
	batches.set_script(BATCH_SCRIPT)
	root.add_child(batches)
	tree_colliders = StaticBody3D.new()
	tree_colliders.name = "Troncos"
	root.add_child(tree_colliders)
	trunk_shape = CylinderShape3D.new()
	trunk_shape.radius = 0.4
	trunk_shape.height = 3.0
	_build_ground()
	_build_path()
	_build_stream()
	_build_foliage()
	_build_entrance_clearing()
	_build_giant_canopy()
	var water_pools: Array[Vector3] = preload("res://scripts/forest_boundary.gd").new().build(root)
	_build_landmarks()
	batches.finish()
	var forest_life := Node3D.new()
	forest_life.name = "VidaDelBosque"
	forest_life.set_script(preload("res://scripts/forest_life.gd"))
	root.add_child(forest_life)
	return {"gate": root.get_node("SantuarioCerrado"), "sigils": _sigils, "water_pools": water_pools}


var _sigils: Array[Node3D] = []


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var mesh := _build_terrain_mesh()
	ground.mesh = mesh
	var ground_material := _material(Color("acb494"), 0.96)
	ground_material.albedo_texture = load("res://assets/polyhaven/forest_leaves_02/Diffuse.jpg")
	ground_material.normal_enabled = true
	ground_material.normal_texture = load("res://assets/polyhaven/forest_leaves_02/nor_gl.jpg")
	ground_material.normal_scale = 0.45
	ground_material.uv1_scale = Vector3(55.0, 58.0, 1.0)
	ground.material_override = ground_material
	root.add_child(ground)
	var body := StaticBody3D.new()
	body.name = "ColisionDelTerrenoOndulado"
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	root.add_child(body)


func _build_terrain_mesh() -> ArrayMesh:
	var width := 190.0
	var depth := 205.0
	var columns := 64
	var rows := 69
	var step_x := width / float(columns)
	var step_z := depth / float(rows)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z_index in range(rows):
		for x_index in range(columns):
			var x0 := -width * 0.5 + float(x_index) * step_x
			var x1 := x0 + step_x
			var z0 := -10.0 - depth * 0.5 + float(z_index) * step_z
			var z1 := z0 + step_z
			var p00 := Vector3(x0, _terrain_height(x0, z0), z0)
			var p10 := Vector3(x1, _terrain_height(x1, z0), z0)
			var p01 := Vector3(x0, _terrain_height(x0, z1), z1)
			var p11 := Vector3(x1, _terrain_height(x1, z1), z1)
			for vertex in [p00, p01, p10, p10, p01, p11]:
				surface.set_uv(Vector2((vertex.x + width * 0.5) / width, (vertex.z + depth * 0.5 + 10.0) / depth))
				surface.add_vertex(vertex)
	surface.index()
	surface.generate_normals()
	return surface.commit()


func _terrain_height(x: float, z: float) -> float:
	var position := Vector2(x, z)
	var path_distance := _distance_to_path(position)
	var flatten := _smooth_factor(path_distance, 4.0, 14.0)
	flatten *= _smooth_factor(absf(z + 12.0), 4.5, 10.0)
	var clearings := [
		Vector2(-33, 25), Vector2(-31, 24), Vector2(-34, 25), Vector2(33, 6),
		Vector2(27, -34), Vector2(0, -82), Vector2(0, -86), Vector2(-5.7, -84),
		Vector2(5.7, -84), Vector2(-23, 38), Vector2(24, 26), Vector2(-27, -42),
		Vector2(23, -60), Vector2(-20, 36), Vector2(20, 28), Vector2(-24, -39),
		Vector2(18, -58), Vector2(0, -60), Vector2(19, -20), Vector2(-18, 13),
		Vector2(5, 55), Vector2(-29, 26), Vector2(0, -32),
	]
	for clearing in clearings:
		flatten *= _smooth_factor(position.distance_to(clearing), 3.5, 9.0)
	var rolling := 2.0 * sin(x * 0.045 + z * 0.018) + 1.2 * sin(z * 0.067 - x * 0.028) + 0.5 * cos((x + z) * 0.12)
	return rolling * flatten


func terrain_height_at(x: float, z: float) -> float:
	return _terrain_height(x, z)


func _ground_position(x: float, z: float) -> Vector3:
	return Vector3(x, _terrain_height(x, z), z)


func _distance_to_path(point: Vector2) -> float:
	var path_points := [Vector2(0, 77), Vector2(2, 62), Vector2(8, 46), Vector2(13, 30), Vector2(7, 15), Vector2(-8, 3), Vector2(-14, -12), Vector2(-7, -28), Vector2(7, -42), Vector2(7, -56), Vector2(0, -76)]
	var closest := INF
	for index in range(path_points.size() - 1):
		var start: Vector2 = path_points[index]
		var segment: Vector2 = path_points[index + 1] - start
		var progress := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
		closest = minf(closest, point.distance_to(start + segment * progress))
	return closest


func _smooth_factor(value: float, start: float, finish: float) -> float:
	var t := clampf((value - start) / (finish - start), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _build_path() -> void:
	# A single irregular ribbon makes the trail follow the clearing naturally.
	var points := [Vector3(0, 0.025, 77), Vector3(2, 0.025, 62), Vector3(8, 0.025, 46), Vector3(13, 0.025, 30), Vector3(7, 0.025, 15), Vector3(-8, 0.025, 3), Vector3(-14, 0.025, -12), Vector3(-7, 0.025, -28), Vector3(7, 0.025, -42), Vector3(7, 0.025, -56), Vector3(0, 0.025, -76)]
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	for p in points:
		curve.add_point(p)
	var distance := curve.get_baked_length()
	var segments := ceili(distance / 2.0)
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for i in range(segments + 1):
		var d := distance * float(i) / float(segments)
		var p := curve.sample_baked(d, true)
		var next := curve.sample_baked(minf(d + 0.5, distance), true)
		if i == segments:
			next = p + (p - curve.sample_baked(maxf(d - 0.5, 0.0), true))
		var direction := (next - p).normalized()
		var side := Vector3(direction.z, 0, -direction.x)
		var width := 2.7 + sin(d * 0.12) * 0.4 + sin(d * 0.31) * 0.18
		left.append(p + side * (width + 0.17 * sin(d * 0.57)))
		right.append(p - side * (width + 0.2 * sin(d * 0.43 + 1.5)))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var shade := 0.88 + 0.08 * sin(float(i) * 0.7)
		for vertex in [left[i], left[i + 1], right[i], right[i], left[i + 1], right[i + 1]]:
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(vertex.x / 3.0, vertex.z / 3.0))
			surface.set_color(Color(shade, shade, shade, 1.0))
			surface.add_vertex(vertex)
	var ribbon := MeshInstance3D.new()
	ribbon.name = "Sendero"
	ribbon.mesh = surface.commit()
	var material := _material(Color("d4c49f"), 1.0)
	material.albedo_texture = load("res://assets/polyhaven/park_dirt/Diffuse.jpg")
	material.vertex_color_use_as_albedo = true
	ribbon.material_override = material
	root.add_child(ribbon)


func _build_stream() -> void:
	# The shallow stream is visual only: its floor is the same walkable ground.
	var water := MeshInstance3D.new()
	water.name = "Arroyo"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(175, 4.8)
	water.mesh = mesh
	water.position = Vector3(0, 0.07, -12)
	var water_material := ShaderMaterial.new()
	water_material.shader = load("res://assets/shaders/forest_stream.gdshader")
	water.material_override = water_material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(water)
	_build_bridge()


func _build_bridge() -> void:
	# A walkable deck and shallow ramps let players cross the bridge or stream.
	var bridge := Node3D.new()
	bridge.name = "PuenteDeCedro"
	bridge.position = Vector3(-13, 0, -12)
	root.add_child(bridge)
	var wood := _material(Color("6d4d35"), 0.95)
	wood.albedo_texture = load("res://assets/quaternius/nature/Bark_NormalTree.png")
	var plank_mesh := BoxMesh.new()
	plank_mesh.size = Vector3(2.8, 0.12, 0.46)
	var planks := MultiMesh.new()
	planks.transform_format = MultiMesh.TRANSFORM_3D
	planks.mesh = plank_mesh
	planks.instance_count = 12
	for i in planks.instance_count:
		planks.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(0, 0.16, (float(i) - 5.5) * 0.5)))
	var deck := MultiMeshInstance3D.new()
	deck.name = "Tablas"
	deck.multimesh = planks
	deck.material_override = wood
	deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bridge.add_child(deck)
	var body := StaticBody3D.new()
	body.name = "SuperficieDelPuente"
	bridge.add_child(body)
	var middle := CollisionShape3D.new()
	var middle_shape := BoxShape3D.new()
	middle_shape.size = Vector3(2.7, 0.12, 5.9)
	middle.shape = middle_shape
	middle.position = Vector3(0, 0.16, 0)
	body.add_child(middle)
	for side in [-1.0, 1.0]:
		var ramp_angle: float = side * atan(0.22 / 1.2)
		var ramp_mesh := BoxMesh.new()
		ramp_mesh.size = Vector3(2.7, 0.12, 1.2)
		var ramp := MeshInstance3D.new()
		ramp.name = "Rampa"
		ramp.mesh = ramp_mesh
		ramp.material_override = wood
		ramp.position = Vector3(0, 0.05, side * 3.42)
		ramp.rotation.x = ramp_angle
		ramp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bridge.add_child(ramp, true)
		var ramp_shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = ramp_mesh.size
		ramp_shape.shape = box
		ramp_shape.position = ramp.position
		ramp_shape.rotation.x = ramp_angle
		body.add_child(ramp_shape)


func _build_foliage() -> void:
	var trees := ["CommonTree_1", "CommonTree_2", "CommonTree_3"]
	var rocks := ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"]
	# A 190 by 205 m region, with intentional clearings around the route and landmarks.
	var attempts := 0
	var placed := 0
	while placed < 200 and attempts < 3000:
		attempts += 1
		var p := _ground_position(rng.randf_range(-88, 88), rng.randf_range(-106, 88))
		if _near_path(p, 13.0) or _in_clearings(p):
			continue
		var name: String = trees[rng.randi_range(0, trees.size() - 1)]
		var size := rng.randf_range(1.35, 2.15)
		batches.add_model(NATURE + name + ".gltf", p, rng.randf_range(-PI, PI), size)
		var collision := CollisionShape3D.new()
		collision.shape = trunk_shape
		collision.position = p + Vector3(0, 1.5, 0)
		collision.scale = Vector3(size, 1, size)
		tree_colliders.add_child(collision)
		placed += 1
	for i in 180:
		var p := _ground_position(rng.randf_range(-87, 87), rng.randf_range(-104, 87))
		if _near_path(p, 6.0) or _in_clearings(p):
			continue
		var name := "Fern_1" if i % 2 == 0 else "Bush_Common"
		var yaw := rng.randf_range(-PI, PI)
		var size := rng.randf_range(0.65, 1.25)
		batches.add_model(NATURE + name + ".gltf", p, yaw, size)
		if name == "Bush_Common":
			_add_solid_collider(p, yaw, Vector3(1.05, 1.3, 1.05) * size, Vector3(0, 0.55 * size, 0), "Arbusto")
	for i in 110:
		var p := _ground_position(rng.randf_range(-87, 87), rng.randf_range(-104, 87))
		if _near_path(p, 5.0) or _in_clearings(p):
			continue
		var name: String = rocks[rng.randi_range(0, rocks.size() - 1)]
		var yaw := rng.randf_range(-PI, PI)
		var size := rng.randf_range(0.65, 1.6)
		batches.add_model(NATURE + name + ".gltf", p, yaw, size)
		_add_rock_collider(p, yaw, size, name)


func _build_entrance_clearing() -> void:
	# Framing the opening with uneven groups gives the player a forest edge
	# while leaving room to reach Nimbo and follow the path.
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 95731
	var tree_names := ["CommonTree_1", "CommonTree_2", "CommonTree_3"]
	for i in 55:
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := _ground_position(side * local_rng.randf_range(10, 27), local_rng.randf_range(43, 82))
		if _near_path(p, 8.0) or p.distance_to(Vector3(-2, 0, 59)) < 5.0:
			continue
		var size := local_rng.randf_range(1.6, 2.3)
		var name: String = tree_names[i % tree_names.size()]
		batches.add_model(NATURE + name + ".gltf", p, local_rng.randf_range(-PI, PI), size)
		var collision := CollisionShape3D.new()
		collision.shape = trunk_shape
		collision.position = p + Vector3(0, 1.5, 0)
		collision.scale = Vector3(size, 1, size)
		tree_colliders.add_child(collision)
	for i in 85:
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := _ground_position(side * local_rng.randf_range(7.0, 25.0), local_rng.randf_range(42, 84))
		if _near_path(p, 5.0) or p.distance_to(Vector3(-2, 0, 59)) < 3.0:
			continue
		var name := "Fern_1" if i % 3 else "Rock_Medium_2"
		var yaw := local_rng.randf_range(-PI, PI)
		var size := local_rng.randf_range(0.65, 1.3)
		batches.add_model(NATURE + name + ".gltf", p, yaw, size)
		if name == "Rock_Medium_2":
			_add_rock_collider(p, yaw, size, name)
	# Colored, textured grass models are used instead of the untextured source meshes.
	var trail_points := [Vector3(0, 0, 72), Vector3(3, 0, 60), Vector3(9, 0, 45), Vector3(13, 0, 30), Vector3(6, 0, 15), Vector3(-8, 0, 2), Vector3(-14, 0, -12), Vector3(-7, 0, -28), Vector3(7, 0, -43), Vector3(6, 0, -57), Vector3(0, 0, -75)]
	for i in 220:
		var center: Vector3 = trail_points[local_rng.randi_range(0, trail_points.size() - 1)]
		var p := _ground_position(center.x + local_rng.randf_range(-12, 12), center.z + local_rng.randf_range(-9, 9))
		if _near_path(p, 4.5) or p.distance_to(Vector3(-2, 0, 59)) < 3.0:
			continue
		batches.add_model(NATURE + "Grass_Common_Tall.gltf", p, local_rng.randf_range(-PI, PI), local_rng.randf_range(0.55, 1.25))
	# Giant trees line the path and their overlapping crowns form a canopy.
	for center in trail_points:
		for side in [-1.0, 1.0]:
			var p: Vector3 = center + Vector3(side * local_rng.randf_range(7.0, 9.0), 0, local_rng.randf_range(-1.5, 1.5))
			if _near_path(p, 5.8) or p.distance_to(Vector3(-2, 0, 59)) < 4.0:
				continue
			var size := local_rng.randf_range(2.1, 2.6)
			batches.add_model(NATURE + "CommonTree_3.gltf", p, local_rng.randf_range(-PI, PI), size)
			var collision := CollisionShape3D.new()
			collision.shape = trunk_shape
			collision.position = p + Vector3(0, 1.5, 0)
			collision.scale = Vector3(size, 1, size)
			tree_colliders.add_child(collision)


func _build_giant_canopy() -> void:
	# Wider crowns lean toward the trail, making the canopy feel continuous.
	var giants := [
		[Vector3(13, 0, 68), PI, 1.4],
		[Vector3(-9, 0, 53), 0.0, 1.5],
		[Vector3(-8, 0, 14), 0.0, 1.45],
		[Vector3(-23, 0, -13), 0.0, 1.4],
		[Vector3(17, 0, -42), PI, 1.4],
		[Vector3(-9, 0, -62), 0.0, 1.35],
	]
	for giant in giants:
		var p: Vector3 = giant[0]
		p.y = _terrain_height(p.x, p.z)
		var size: float = giant[2]
		batches.add_model(NATURE + "TwistedTree_Green.gltf", p, giant[1], size)
		var collision := CollisionShape3D.new()
		collision.shape = trunk_shape
		collision.position = p + Vector3(0, 1.5, 0)
		collision.scale = Vector3(size * 1.4, 1, size * 1.4)
		tree_colliders.add_child(collision)


func _build_background_hills() -> void:
	var hill_mesh := SphereMesh.new()
	hill_mesh.radius = 1.0
	hill_mesh.height = 2.0
	hill_mesh.radial_segments = 20
	hill_mesh.rings = 10
	var hill_mat := _material(Color("526447"), 1.0)
	for side in [-1.0, 1.0]:
		for z in [-70.0, -22.0, 28.0, 78.0]:
			var hill := MeshInstance3D.new()
			hill.name = "ColinaDeFondo"
			hill.mesh = hill_mesh
			hill.material_override = hill_mat
			hill.position = Vector3(side * 105.0, -4.0, z)
			hill.scale = Vector3(18.0, 7.0, 29.0)
			hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(hill)


func _build_landmarks() -> void:
	# Side camp, old waystones, forest shrine, and the final sanctuary.
	_add_prop(RESOURCES + "Wood_Log_Stack.gltf", Vector3(-34, 0, 25), 0.4, 1.5)
	_add_prop("res://assets/kaykit/tools/Assets/gltf/lantern.gltf", Vector3(-31, 0, 24), 0, 1.4)
	_add_prop("res://assets/kaykit/tools/Assets/gltf/map.gltf", Vector3(-34, 1.0, 25), 0.2, 1.2)
	_add_prop(RESOURCES + "Stone_Chunks_Large.gltf", Vector3(33, 0, 6), 0.5, 2.2)
	_add_prop(RESOURCES + "Wood_Planks_Stack_Medium.gltf", Vector3(27, 0, -34), -0.7, 1.4)
	_add_prop("res://assets/kaykit/tools/Assets/gltf/pickaxe.gltf", Vector3(27, 0, -32), 0, 1.0)
	for p in [Vector3(-23, 0, 38), Vector3(24, 0, 26), Vector3(-27, 0, -42), Vector3(23, 0, -60)]:
		_add_prop("res://assets/kaykit/dungeon/Assets/gltf/pillar_decorated.gltf", p, rng.randf_range(-PI, PI), 1.2)
	for p in [Vector3(-20, 0, 36), Vector3(20, 0, 28), Vector3(-24, 0, -39), Vector3(18, 0, -58)]:
		_add_prop("res://assets/kaykit/dungeon/Assets/gltf/wall_broken.gltf", p, rng.randf_range(-PI, PI), 1.2)
	var stairs := _add_prop("res://assets/kaykit/dungeon/Assets/gltf/stairs_wide.gltf", Vector3(0, 0, -82), 0, 2.0)
	if stairs:
		# The original kit piece is five metres tall before scaling. Flatten it
		# into shallow steps and use a gentle solid ramp for character movement.
		stairs.scale.y = 0.12
		var stair_body := StaticBody3D.new()
		stair_body.name = "RampaDelSantuario"
		stair_body.position = Vector3(0, 0.20, -77.5)
		var stair_collision := CollisionShape3D.new()
		var stair_box := BoxShape3D.new()
		stair_box.size = Vector3(13.2, 0.2, 9.5)
		stair_collision.shape = stair_box
		stair_collision.rotation.x = atan(0.6 / 9.5)
		stair_body.add_child(stair_collision)
		root.add_child(stair_body)
	var entrance := load("res://assets/kaykit/dungeon/Assets/gltf/wall_doorway.gltf").instantiate() as Node3D
	entrance.name = "Santuario"
	entrance.position = Vector3(0, 0, -86)
	entrance.scale = Vector3(2.2, 2.2, 1.6)
	root.add_child(entrance)
	var decorative_door := entrance.find_child("wall_doorway_door", true, false) as Node3D
	if decorative_door:
		decorative_door.visible = false
	_add_box_collision(entrance, Vector3(-1.5, 1.8, 0), Vector3(0.9, 3.6, 0.85))
	_add_box_collision(entrance, Vector3(1.5, 1.8, 0), Vector3(0.9, 3.6, 0.85))
	var gate := load("res://assets/kaykit/dungeon/Assets/gltf/wall_gated.gltf").instantiate() as Node3D
	gate.name = "SantuarioCerrado"
	gate.position = Vector3(0, 0, -85.5)
	gate.scale = Vector3(2.1, 2.1, 1.6)
	gate.set_meta("gate", true)
	root.add_child(gate)
	_add_box_collision(gate, Vector3(0, 1.0, 0), Vector3(2.0, 2.0, 0.35))
	_add_prop("res://assets/kaykit/dungeon/Assets/gltf/torch_lit.gltf", Vector3(-5.7, 0.0, -84), 0, 1.2)
	_add_prop("res://assets/kaykit/dungeon/Assets/gltf/torch_lit.gltf", Vector3(5.7, 0.0, -84), 0, 1.2)
	var sigil_positions := [Vector3(0, 0, -60), Vector3(19, 0, -20), Vector3(-18, 0, 13)]
	for i in sigil_positions.size():
		var sigil := Node3D.new()
		sigil.name = "PiedraGuia%d" % (i + 1)
		sigil.position = sigil_positions[i]
		var model_path := "res://assets/kaykit/dungeon/Assets/gltf/pillar_decorated.gltf"
		var model := load(model_path).instantiate() as Node3D
		model.scale = Vector3(0.38, 0.5, 0.38)
		sigil.add_child(model)
		var glow := MeshInstance3D.new()
		glow.name = "RunicGlow"
		var orb := SphereMesh.new()
		orb.radius = 0.23
		orb.height = 0.46
		glow.mesh = orb
		glow.position = Vector3(0, 2.0, -0.48)
		glow.material_override = _material(Color("66c4a1"), 0.3, true)
		sigil.add_child(glow)
		var label := Label3D.new()
		label.name = "Symbol"
		label.text = ["SEMILLA  ◆", "LUNA  ☾", "AGUA  ≋"][i]
		label.font_size = 48
		label.pixel_size = 0.012
		label.outline_size = 8
		label.modulate = Color("fff0b5")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0, 2.8, 0)
		sigil.add_child(label)
		sigil.set_meta("sigil_index", i)
		sigil.set_meta("active", false)
		root.add_child(sigil)
		_add_box_collision(sigil, Vector3(0, 0.85, 0), Vector3(0.9, 1.7, 0.7))
		_sigils.append(sigil)


func _add_box_collision(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Colision"
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body, true)


func _add_rock_collider(at: Vector3, yaw: float, scale: float, model_name: String) -> void:
	# These bounds come from the imported meshes; the inset avoids an
	# invisible rectangular margin around their irregular silhouettes.
	var dimensions := {
		"Rock_Medium_1": Vector3(3.225, 2.260, 2.989),
		"Rock_Medium_2": Vector3(3.049, 1.899, 2.479),
		"Rock_Medium_3": Vector3(3.420, 2.316, 3.476),
	}
	var centers := {
		"Rock_Medium_1": Vector3(-0.115, 0.859, 0.345),
		"Rock_Medium_2": Vector3(-0.189, 0.899, 0.080),
		"Rock_Medium_3": Vector3(-0.114, 0.843, 0.848),
	}
	var size: Vector3 = dimensions[model_name] * Vector3(0.75, 0.90, 0.75) * scale
	var offset: Vector3 = centers[model_name] * scale
	_add_solid_collider(at, yaw, size, offset, "Piedra")


func _add_solid_collider(at: Vector3, yaw: float, size: Vector3, offset: Vector3, label: String) -> void:
	var cell := Vector2i(floori(at.x / 32.0), floori(at.z / 32.0))
	if not solid_bodies.has(cell):
		var body := StaticBody3D.new()
		body.name = "Solidos_%d_%d" % [cell.x, cell.y]
		root.add_child(body)
		solid_bodies[cell] = body
	var collider := CollisionShape3D.new()
	collider.name = label
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	collider.position = at + Basis(Vector3.UP, yaw) * offset
	collider.rotation.y = yaw
	solid_bodies[cell].add_child(collider, true)


func _add_prop(path: String, at: Vector3, yaw: float, scale: float) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var model := packed.instantiate() as Node3D
	model.position = at
	model.rotation.y = yaw
	model.scale = Vector3.ONE * scale
	root.add_child(model)
	if path.contains("pillar_decorated"):
		_add_box_collision(model, Vector3(0, 1.6, 0), Vector3(1.4, 3.2, 1.0))
	elif path.contains("wall_broken"):
		_add_box_collision(model, Vector3(0, 0.65, 0), Vector3(3.2, 1.3, 0.75))
	elif path.contains("Wood_Log_Stack"):
		_add_box_collision(model, Vector3(0, 0.70, 0), Vector3(1.5, 1.4, 1.3))
	elif path.contains("Stone_Chunks_Large"):
		_add_box_collision(model, Vector3(0, 0.5, 0), Vector3(1.35, 1.0, 1.2))
	elif path.contains("Wood_Planks_Stack_Medium"):
		_add_box_collision(model, Vector3(0, 0.3, 0), Vector3(1.5, 0.6, 1.4))
	elif path.ends_with("/lantern.gltf"):
		_add_box_collision(model, Vector3(0, 0.45, 0), Vector3(0.65, 0.9, 0.65))
	elif path.ends_with("/pickaxe.gltf"):
		_add_box_collision(model, Vector3(0, 0.4, 0), Vector3(1.1, 1.0, 0.18))
	elif path.ends_with("/map.gltf"):
		_add_box_collision(model, Vector3(0, 0.15, 0), Vector3(1.6, 0.3, 1.0))
	elif path.ends_with("/torch_lit.gltf"):
		_add_box_collision(model, Vector3(0, 0.2, 0), Vector3(0.35, 0.8, 0.35))
	return model


func _near_path(p: Vector3, margin: float) -> bool:
	var points := [Vector3(0, 0, 77), Vector3(2, 0, 62), Vector3(8, 0, 46), Vector3(13, 0, 30), Vector3(7, 0, 15), Vector3(-8, 0, 3), Vector3(-14, 0, -12), Vector3(-7, 0, -28), Vector3(7, 0, -42), Vector3(7, 0, -56), Vector3(0, 0, -76)]
	for i in range(points.size() - 1):
		if _distance_to_segment(p, points[i], points[i + 1]) < margin:
			return true
	return absf(p.z + 12.0) < 5.0


func _distance_to_segment(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _in_clearings(p: Vector3) -> bool:
	return p.distance_to(Vector3(-33, 0, 25)) < 9 or p.distance_to(Vector3(33, 0, 6)) < 7 or p.distance_to(Vector3(27, 0, -34)) < 7 or p.distance_to(Vector3(0, 0, -85)) < 13 or p.distance_to(Vector3(-18, 0, 13)) < 5 or p.distance_to(Vector3(19, 0, -20)) < 5 or p.distance_to(Vector3(0, 0, -60)) < 5


func _material(color: Color, roughness: float, glow: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.45
	return mat
