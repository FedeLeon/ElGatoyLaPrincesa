extends Node3D
## Reuses a small ring pool and one particle emitter for shallow-water steps.

const STREAM_MIN_X := -87.5
const STREAM_MAX_X := 87.5
const STREAM_MIN_Z := -14.4
const STREAM_MAX_Z := -9.6
const SURFACE_Y := 0.085
const RING_COUNT := 7

var actor: CharacterBody3D
var game: Node
var waterfall_pools: Array[Vector3] = []
var splashes: CPUParticles3D
var rings: Array[MeshInstance3D] = []
var ring_age: Array[float] = []
var ring_index := 0
var previous_position := Vector3.ZERO
var distance_since_step := 0.0
var in_water := false


func configure(character: CharacterBody3D, game_root: Node, pools: Array[Vector3]) -> void:
	actor = character
	game = game_root
	waterfall_pools = pools
	previous_position = actor.global_position
	_build_effects()


func _build_effects() -> void:
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.43
	ring_mesh.outer_radius = 0.47
	ring_mesh.rings = 16
	ring_mesh.ring_segments = 6
	for i in RING_COUNT:
		var ring := MeshInstance3D.new()
		ring.name = "OndaDePisada%d" % i
		ring.mesh = ring_mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.72, 0.94, 0.88, 0.75)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		ring.material_override = material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.visible = false
		add_child(ring)
		rings.append(ring)
		ring_age.append(1.0)
	var droplet_mesh := SphereMesh.new()
	droplet_mesh.radius = 0.035
	droplet_mesh.height = 0.07
	droplet_mesh.radial_segments = 6
	droplet_mesh.rings = 4
	var droplet_material := StandardMaterial3D.new()
	droplet_material.albedo_color = Color("c2eee3")
	droplet_material.roughness = 0.22
	droplet_mesh.material = droplet_material
	splashes = CPUParticles3D.new()
	splashes.name = "SalpicadurasDePisadas"
	splashes.amount = 18
	splashes.lifetime = 0.48
	splashes.mesh = droplet_mesh
	splashes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	splashes.emission_sphere_radius = 0.16
	splashes.direction = Vector3.UP
	splashes.spread = 50.0
	splashes.initial_velocity_min = 0.8
	splashes.initial_velocity_max = 1.8
	splashes.gravity = Vector3(0, -5.0, 0)
	splashes.scale_amount_min = 0.55
	splashes.scale_amount_max = 1.0
	splashes.local_coords = false
	splashes.emitting = false
	add_child(splashes)


func _process(delta: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(splashes):
		return
	if game.get("paused") or game.get("game_won") or game.get("game_over"):
		splashes.emitting = false
		previous_position = actor.global_position
		return
	var position := actor.global_position
	in_water = _is_in_water(position) and absf(position.y) < 0.13 and actor.is_on_floor()
	var speed := Vector2(actor.velocity.x, actor.velocity.z).length()
	var moving := in_water and speed > 0.65
	splashes.global_position = Vector3(position.x, SURFACE_Y + 0.05, position.z)
	splashes.emitting = moving
	if moving:
		var distance := Vector2(position.x - previous_position.x, position.z - previous_position.z).length()
		distance_since_step += minf(distance, 0.5)
		if distance_since_step >= 0.85:
			distance_since_step = 0.0
			_emit_ring(position)
	else:
		distance_since_step = 0.0
	previous_position = position
	for i in rings.size():
		if ring_age[i] >= 0.85:
			continue
		ring_age[i] += delta
		var progress := clampf(ring_age[i] / 0.85, 0.0, 1.0)
		rings[i].scale = Vector3.ONE * lerpf(0.25, 1.35, progress)
		var mat := rings[i].material_override as StandardMaterial3D
		mat.albedo_color = Color(0.72, 0.94, 0.88, (1.0 - progress) * 0.75)
		if progress >= 1.0:
			rings[i].visible = false


func _emit_ring(position: Vector3) -> void:
	var ring := rings[ring_index]
	ring.global_position = Vector3(position.x, SURFACE_Y, position.z)
	ring.scale = Vector3.ONE * 0.25
	ring.visible = true
	ring_age[ring_index] = 0.0
	ring_index = (ring_index + 1) % RING_COUNT


func _is_in_water(position: Vector3) -> bool:
	if position.x >= STREAM_MIN_X and position.x <= STREAM_MAX_X and position.z >= STREAM_MIN_Z and position.z <= STREAM_MAX_Z:
		return true
	for pool in waterfall_pools:
		if Vector2(position.x - pool.x, position.z - pool.z).length_squared() <= 3.2 * 3.2:
			return true
	return false
