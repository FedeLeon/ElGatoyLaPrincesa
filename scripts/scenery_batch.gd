extends Node3D
## Collects repeated GLTF meshes into spatial MultiMesh batches.

const CELL_SIZE := 48.0
const MAX_VISIBILITY := 105.0

var _parts_cache: Dictionary = {}
var _batches: Dictionary = {}
var _illustrated_meshes: Dictionary = {}


func add_model(scene_path: String, at: Vector3, yaw: float = 0.0, scale: float = 1.0) -> void:
	var parts: Array = _get_parts(scene_path)
	if parts.is_empty():
		return
	var world_transform := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), at)
	for part in parts:
		_add_part(scene_path, part.mesh, part.index, world_transform * part.transform, at)


func add_mesh(mesh_key: String, mesh: Mesh, at: Vector3, yaw: float = 0.0, scale: float = 1.0) -> void:
	if mesh == null:
		return
	var world_transform := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), at)
	_add_part(mesh_key, mesh, 0, world_transform, at)


func _add_part(path: String, mesh: Mesh, index: int, transform: Transform3D, anchor: Vector3) -> void:
	var cell := Vector2i(floori(anchor.x / CELL_SIZE), floori(anchor.z / CELL_SIZE))
	var key := "%s|%d|%d|%d" % [path, index, cell.x, cell.y]
	if not _batches.has(key):
		_batches[key] = {"mesh": mesh, "transforms": [], "cell": cell, "path": path, "index": index}
	var cell_origin := Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)
	var local_transform := Transform3D(Basis.IDENTITY, cell_origin).affine_inverse() * transform
	_batches[key].transforms.append(local_transform)


func finish() -> void:
	for batch in _batches.values():
		var hero_tree: bool = "ElderOak" in batch.path
		var is_tree: bool = hero_tree or "TwistedTree_" in batch.path or "CommonTree_" in batch.path
		if is_tree:
			if not "ElderOak_Foliage" in batch.path:
				_add_illustrated_trees(batch)
			continue
		var basename: String = batch.path.get_file().get_basename()
		if basename.begins_with("Rock_Medium_"):
			_add_illustrated_trees(batch, "rock", Vector2(3.0, 2.2))
			continue
		if basename == "Fern_1" or basename == "Bush_Common":
			_add_illustrated_trees(batch, "fern", Vector2(2.5, 1.8))
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = batch.mesh
		multi.instance_count = batch.transforms.size()
		for i in batch.transforms.size():
			multi.set_instance_transform(i, batch.transforms[i])
		var instance := MultiMeshInstance3D.new()
		instance.name = "Batch_%s_%d_%d" % [batch.path.get_file().get_basename(), batch.cell.x, batch.cell.y]
		instance.multimesh = multi
		instance.position = Vector3(batch.cell.x * CELL_SIZE, 0.0, batch.cell.y * CELL_SIZE)
		# Keep shadow maps for the silhouette framing trees only. Repeated forest
		# dressing receives directional and ambient light without each
		# distant tree batch redrawing its shadow caster.
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.visibility_range_end = MAX_VISIBILITY
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		# Cover a cell and the largest nearby canopy without keeping adjacent
		# cells visible unnecessarily at the edge of the camera frustum.
		instance.custom_aabb = AABB(Vector3(-12, -2, -12), Vector3(CELL_SIZE + 24, 36, CELL_SIZE + 24))
		add_child(instance)
	_batches.clear()


func _add_illustrated_trees(batch: Dictionary, kind: String = "ancient_tree", dimensions: Vector2 = Vector2(5.0, 7.0)) -> void:
	if not _illustrated_meshes.has(kind):
		var mesh := QuadMesh.new()
		mesh.size = dimensions
		var material := StandardMaterial3D.new()
		material.albedo_texture = load("res://assets/created/isometric/pixel_%s.png" % kind)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.2
		material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material = material
		_illustrated_meshes[kind] = mesh
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = _illustrated_meshes[kind]
	multi.instance_count = batch.transforms.size()
	for i in batch.transforms.size():
		var transform: Transform3D = batch.transforms[i]
		var size := transform.basis.get_scale().x
		# Keep the artwork upright; the shader turns it to the camera.
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), transform.origin + Vector3(0, dimensions.y * 0.5 * size, 0)))
	var node := MultiMeshInstance3D.new()
	node.name = "ArbolesIlustrados"
	node.multimesh = multi
	node.position = Vector3(batch.cell.x * CELL_SIZE, 0, batch.cell.y * CELL_SIZE)
	node.custom_aabb = AABB(Vector3(-12, -2, -12), Vector3(CELL_SIZE + 24, 30, CELL_SIZE + 24))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _get_parts(scene_path: String) -> Array:
	if _parts_cache.has(scene_path):
		return _parts_cache[scene_path]
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_warning("No se pudo cargar modelo: %s" % scene_path)
		return []
	var prototype := packed.instantiate() as Node3D
	if prototype == null:
		return []
	add_child(prototype)
	prototype.position = Vector3(0, -1000, 0)
	prototype.force_update_transform()
	var parts: Array = []
	var found: Array[MeshInstance3D] = []
	_collect_meshes(prototype, found)
	for index in found.size():
		var item := found[index]
		if item.mesh:
			parts.append({"mesh": item.mesh, "transform": prototype.global_transform.affine_inverse() * item.global_transform, "index": index})
	prototype.queue_free()
	_parts_cache[scene_path] = parts
	return parts


func _collect_meshes(node: Node, output: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		output.append(node)
	for child in node.get_children():
		_collect_meshes(child, output)
