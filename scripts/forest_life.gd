extends Node3D
## Original procedural forest details, grouped into a few shared meshes.

const ANCHORS := [Vector3(0, 0, 68), Vector3(4, 0, 52), Vector3(12, 0, 33), Vector3(-6, 0, 9), Vector3(-14, 0, -12), Vector3(-6, 0, -27), Vector3(7, 0, -43), Vector3(4, 0, -59), Vector3(0, 0, -74)]
const BUTTERFLY_ANCHORS := [Vector3(-4, 1.4, 65), Vector3(8, 1.6, 55), Vector3(-7, 1.4, 40), Vector3(8, 1.4, 15), Vector3(-13, 1.4, -9), Vector3(10, 1.5, -29), Vector3(-8, 1.6, -55)]

var wings: MultiMesh
var butterfly_bodies: MultiMesh
var origins: Array[Vector3] = []
var phases: Array[float] = []
var elapsed := 0.0

func _ready() -> void:
	_build_mushrooms()
	_build_butterflies()


func _material(color: Color, unshaded: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _batch(mesh: Mesh, material: Material, count: int, label: String) -> MultiMesh:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = mesh
	batch.instance_count = count
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = batch
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = 170
	add_child(node)
	return batch


func _build_mushrooms() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 6309
	var positions: Array[Vector3] = []
	var sizes: Array[float] = []
	for anchor in ANCHORS:
		for side in [-1.0, 1.0]:
			for cluster in 3:
				var center: Vector3 = anchor + Vector3(side * random.randf_range(4.7, 9.0), 0, random.randf_range(-4.0, 4.0))
				for mushroom in random.randi_range(2, 4):
					positions.append(center + Vector3(random.randf_range(-0.65, 0.65), 0, random.randf_range(-0.65, 0.65)))
					sizes.append(random.randf_range(0.7, 1.2))
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.065
	stem_mesh.bottom_radius = 0.09
	stem_mesh.height = 0.32
	stem_mesh.radial_segments = 8
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 0.24
	cap_mesh.height = 0.48
	cap_mesh.radial_segments = 12
	cap_mesh.rings = 6
	var spot_mesh := SphereMesh.new()
	spot_mesh.radius = 0.035
	spot_mesh.height = 0.07
	spot_mesh.radial_segments = 6
	spot_mesh.rings = 4
	var stems := _batch(stem_mesh, _material(Color("ded5ae")), positions.size(), "TallosDeHongos")
	var caps := _batch(cap_mesh, _material(Color.WHITE), positions.size(), "SombrerosDeHongos")
	var spots := _batch(spot_mesh, _material(Color("f2e5c5")), positions.size() * 3, "PuntosDeHongos")
	for i in positions.size():
		var p := positions[i]
		var size := sizes[i]
		stems.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), p + Vector3(0, 0.16 * size, 0)))
		stems.set_instance_color(i, Color.WHITE)
		caps.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(size, 0.56 * size, size)), p + Vector3(0, 0.33 * size, 0)))
		caps.set_instance_color(i, Color("b8624d") if i % 4 else Color("d6a65d"))
		for j in 3:
			var offset: Vector3 = [Vector3(-0.10, 0.43, 0), Vector3(0.10, 0.43, 0.02), Vector3(0, 0.45, -0.08)][j] * size
			spots.set_instance_transform(i * 3 + j, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), p + offset))
			spots.set_instance_color(i * 3 + j, Color.WHITE)


func _build_butterflies() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 12871
	for anchor in BUTTERFLY_ANCHORS:
		for i in 4:
			origins.append(anchor + Vector3(random.randf_range(-2.3, 2.3), random.randf_range(-0.2, 1.1), random.randf_range(-2.5, 2.5)))
			phases.append(random.randf_range(0, TAU))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge := [Vector3(-0.09, 0, 0), Vector3(-0.065, 0.06, 0), Vector3(0.04, 0.08, 0), Vector3(0.09, 0.035, 0), Vector3(0.07, -0.06, 0), Vector3(-0.04, -0.05, 0)]
	for i in edge.size():
		for vertex in [Vector3.ZERO, edge[i], edge[(i + 1) % edge.size()]]:
			surface.set_normal(Vector3.FORWARD)
			surface.add_vertex(vertex)
	wings = _batch(surface.commit(), _material(Color.WHITE, true), origins.size() * 2, "AlasDeMariposas")
	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.025
	body_mesh.height = 0.12
	body_mesh.radial_segments = 6
	body_mesh.rings = 4
	butterfly_bodies = _batch(body_mesh, _material(Color("514b37"), true), origins.size(), "CuerposDeMariposas")
	for i in origins.size():
		var color: Color = [Color("f3db9c"), Color("badbd0"), Color("e9b2aa")][i % 3]
		wings.set_instance_color(i * 2, color)
		wings.set_instance_color(i * 2 + 1, color)
		butterfly_bodies.set_instance_color(i, Color.WHITE)
	_update_wings()


func _process(delta: float) -> void:
	elapsed += delta
	_update_wings()


func _update_wings() -> void:
	if wings == null:
		return
	for i in origins.size():
		var phase := phases[i]
		var center := origins[i] + Vector3(sin(elapsed * 0.6 + phase) * 0.9, sin(elapsed * 2.0 + phase) * 0.22, cos(elapsed * 0.5 + phase) * 0.7)
		var yaw := elapsed * 0.35 + phase
		var flap := 0.25 + absf(sin(elapsed * 11.0 + phase)) * 1.15
		var heading := Basis(Vector3.UP, yaw)
		butterfly_bodies.set_instance_transform(i, Transform3D(heading, center))
		for side_index in 2:
			var side := -1.0 if side_index == 0 else 1.0
			var wing_basis := heading * Basis(Vector3.UP, side * flap)
			var wing_position := center + heading * Vector3(side * 0.085, 0, 0)
			wings.set_instance_transform(i * 2 + side_index, Transform3D(wing_basis, wing_position))
