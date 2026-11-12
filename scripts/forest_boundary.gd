extends RefCounted
## A continuous mountain rim and visible waterfalls shelter the playable map.

const WEST := -90.0
const EAST := 90.0
const NORTH := -107.0
const SOUTH := 87.0

var root: Node3D
var mountain_material: StandardMaterial3D
var waterfall_material: ShaderMaterial
var pool_material: ShaderMaterial
var pools: Array[Vector3] = []


func build(parent: Node3D) -> Array[Vector3]:
	root = parent
	mountain_material = StandardMaterial3D.new()
	mountain_material.albedo_color = Color("88937c")
	mountain_material.albedo_texture = load("res://assets/polyhaven/rocky_terrain_02/Diffuse.jpg")
	mountain_material.normal_enabled = true
	mountain_material.normal_texture = load("res://assets/polyhaven/rocky_terrain_02/nor_gl.jpg")
	mountain_material.normal_scale = 0.6
	mountain_material.roughness = 0.95
	mountain_material.vertex_color_use_as_albedo = true
	mountain_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	waterfall_material = ShaderMaterial.new()
	waterfall_material.shader = load("res://assets/shaders/forest_waterfall.gdshader")
	pool_material = ShaderMaterial.new()
	pool_material.shader = load("res://assets/shaders/forest_pool.gdshader")
	_build_ridge(Vector3(WEST, 0, NORTH - 12), Vector3(0, 0, 1), Vector3.LEFT, SOUTH - NORTH + 24, 1.0)
	_build_ridge(Vector3(EAST, 0, NORTH - 12), Vector3(0, 0, 1), Vector3.RIGHT, SOUTH - NORTH + 24, 2.1)
	_build_ridge(Vector3(WEST - 12, 0, NORTH), Vector3.RIGHT, Vector3.FORWARD, EAST - WEST + 24, 3.2)
	_build_ridge(Vector3(WEST - 12, 0, SOUTH), Vector3.RIGHT, Vector3.BACK, EAST - WEST + 24, 4.5)
	_add_barrier(Vector3(WEST, 15, (NORTH + SOUTH) * 0.5), Vector3(1, 30, SOUTH - NORTH + 2))
	_add_barrier(Vector3(EAST, 15, (NORTH + SOUTH) * 0.5), Vector3(1, 30, SOUTH - NORTH + 2))
	_add_barrier(Vector3((WEST + EAST) * 0.5, 15, NORTH), Vector3(EAST - WEST + 2, 30, 1))
	_add_barrier(Vector3((WEST + EAST) * 0.5, 15, SOUTH), Vector3(EAST - WEST + 2, 30, 1))
	_add_falls(Vector3(WEST + 0.7, 0, 30), Vector3.LEFT, 7.0)
	_add_falls(Vector3(WEST + 0.7, 0, -43), Vector3.LEFT, 5.5)
	_add_falls(Vector3(EAST - 0.7, 0, 18), Vector3.RIGHT, 7.0)
	_add_falls(Vector3(EAST - 0.7, 0, -61), Vector3.RIGHT, 5.0)
	_add_falls(Vector3(-42, 0, NORTH + 0.7), Vector3.FORWARD, 6.0)
	_add_falls(Vector3(45, 0, NORTH + 0.7), Vector3.FORWARD, 7.0)
	_add_falls(Vector3(-48, 0, SOUTH - 0.7), Vector3.BACK, 5.0)
	_add_falls(Vector3(48, 0, SOUTH - 0.7), Vector3.BACK, 6.0)
	return pools


func _build_ridge(start: Vector3, along: Vector3, outward: Vector3, length: float, phase: float) -> void:
	var segments := ceili(length / 7.0)
	var rows: Array[Array] = []
	for i in range(segments + 1):
		var t := float(i) / segments
		var base := start + along * (length * t)
		var peak := 24.0 + sin(t * 16.0 + phase) * 5.0 + sin(t * 39.0 + phase * 2.0) * 2.8
		var shoulder := peak * (0.64 + 0.08 * sin(t * 22.0 + phase))
		rows.append([
			base + Vector3(0, -0.08, 0),
			base + outward * 7.0 + Vector3(0, peak, 0),
			base + outward * 18.0 + Vector3(0, shoulder, 0),
			base + outward * 35.0 + Vector3(0, -0.2, 0),
		])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		for row in 3:
			var a: Vector3 = rows[i][row]
			var b: Vector3 = rows[i + 1][row]
			var c: Vector3 = rows[i][row + 1]
			var d: Vector3 = rows[i + 1][row + 1]
			for vertex in [a, b, c, b, d, c]:
				surface.set_uv(Vector2(float(i) * 1.4 if vertex == a or vertex == c else float(i + 1) * 1.4, vertex.y / 6.0))
				var tone := 0.83 + clampf(vertex.y / 90.0, 0.0, 0.17)
				surface.set_color(Color(tone, tone, tone, 1))
				surface.add_vertex(vertex)
	surface.index()
	surface.generate_normals()
	var ridge := MeshInstance3D.new()
	ridge.name = "MontanasDelBosque"
	ridge.mesh = surface.commit()
	ridge.material_override = mountain_material
	ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ridge, true)


func _add_barrier(at: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "ColisionDeMontana"
	body.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	root.add_child(body, true)


func _add_falls(base: Vector3, outward: Vector3, width: float) -> void:
	var across := Vector3(-outward.z, 0, outward.x)
	var bottom_left := base - across * width * 0.5 + Vector3(0, 0.1, 0)
	var bottom_right := base + across * width * 0.5 + Vector3(0, 0.1, 0)
	var top_center := base + outward * 7.0 + Vector3(0, _ridge_top_height(base, outward), 0)
	var top_left := top_center - across * width * 0.5
	var top_right := top_center + across * width * 0.5
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for entry in [[top_left, Vector2(0, 0)], [bottom_left, Vector2(0, 1)], [top_right, Vector2(1, 0)], [top_right, Vector2(1, 0)], [bottom_left, Vector2(0, 1)], [bottom_right, Vector2(1, 1)]]:
		surface.set_uv(entry[1])
		surface.add_vertex(entry[0])
	var falls := MeshInstance3D.new()
	falls.name = "Cascada"
	falls.mesh = surface.commit()
	falls.material_override = waterfall_material
	falls.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(falls, true)
	var pool := MeshInstance3D.new()
	pool.name = "RemansoDeCascada"
	var pool_mesh := PlaneMesh.new()
	pool_mesh.size = Vector2.ONE * width * 1.16
	pool.mesh = pool_mesh
	pool.material_override = pool_material
	pool.position = base + Vector3(0, 0.075, 0) - outward * 1.6
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(pool, true)
	pools.append(pool.position)


func _ridge_top_height(base: Vector3, outward: Vector3) -> float:
	var along_position: float
	var length: float
	var phase: float
	if outward == Vector3.LEFT or outward == Vector3.RIGHT:
		along_position = base.z - (NORTH - 12.0)
		length = SOUTH - NORTH + 24.0
		phase = 1.0 if outward == Vector3.LEFT else 2.1
	else:
		along_position = base.x - (WEST - 12.0)
		length = EAST - WEST + 24.0
		phase = 3.2 if outward == Vector3.FORWARD else 4.5
	var segments := ceili(length / 7.0)
	var coordinate := clampf(along_position / length, 0.0, 1.0) * segments
	var left := floori(coordinate)
	var fraction := coordinate - left
	var t1 := float(left) / segments
	var t2 := float(mini(left + 1, segments)) / segments
	var h1 := 24.0 + sin(t1 * 16.0 + phase) * 5.0 + sin(t1 * 39.0 + phase * 2.0) * 2.8
	var h2 := 24.0 + sin(t2 * 16.0 + phase) * 5.0 + sin(t2 * 39.0 + phase * 2.0) * 2.8
	return lerpf(h1, h2, fraction)
