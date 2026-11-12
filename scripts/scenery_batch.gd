extends Node3D
## Collects repeated GLTF meshes into spatial MultiMesh batches.

const CELL_SIZE := 48.0
const MAX_VISIBILITY := 105.0

var _parts_cache: Dictionary = {}
var _batches: Dictionary = {}


func add_model(scene_path: String, at: Vector3, yaw: float = 0.0, scale: float = 1.0) -> void:
	var parts: Array = _get_parts(scene_path)
	if parts.is_empty():
		return
	var world_transform := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * scale), at)
	for part in parts:
		var mesh: Mesh = part.mesh
		var transform: Transform3D = world_transform * part.transform
		var cell := Vector2i(floori(at.x / CELL_SIZE), floori(at.z / CELL_SIZE))
		var key := "%s|%d|%d|%d" % [scene_path, part.index, cell.x, cell.y]
		if not _batches.has(key):
			_batches[key] = {"mesh": mesh, "transforms": [], "cell": cell, "path": scene_path, "index": part.index}
		var cell_origin := Vector3(cell.x * CELL_SIZE, 0.0, cell.y * CELL_SIZE)
		var local_transform := Transform3D(Basis.IDENTITY, cell_origin).affine_inverse() * transform
		_batches[key].transforms.append(local_transform)


func finish() -> void:
	for batch in _batches.values():
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
		# A small number of giant crowns cast the large canopy shadows; the
		# repeated background trees remain visible without duplicating shadow work.
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if "TwistedTree_" in batch.path else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.visibility_range_end = MAX_VISIBILITY
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		# Cover a cell and the largest nearby canopy without keeping adjacent
		# cells visible unnecessarily at the edge of the camera frustum.
		instance.custom_aabb = AABB(Vector3(-22, -2, -22), Vector3(CELL_SIZE + 44, 40, CELL_SIZE + 44)) if "TwistedTree_" in batch.path else AABB(Vector3(-12, -2, -12), Vector3(CELL_SIZE + 24, 36, CELL_SIZE + 24))
		add_child(instance)
	_batches.clear()


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
