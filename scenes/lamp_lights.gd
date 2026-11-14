extends Node3D
## Street lamps with the same light quality as the droid beam:
## a wide soft ground pool (outer spot, linear falloff, shadowed), a bright
## core column (inner spot, unshadowed), and a fake-volumetric cone that
## reuses the droid beam shader (blend_add, silhouette feather, screen-depth
## contact fade) so it dissolves on geometry instead of intersecting it.
## The rigs are built from the map's lamp-head meshes — no manual placement.

@export var map_path := "EchoCart_L1"
## find_children pattern for the lamp-head meshes. L1 names the fixture by
## place ("L1_Lamp_W Gasse_Head"), L2 by index ("L2_Lamp_Head_0").
@export var head_pattern := "L1_Lamp_*_Head"
@export var enabled := true

## Cone mesh half-angle; ground radius = drop * tan(angle).
@export var pool_half_angle := 24.0
## Spots sit this far below the lamp head so the fixture cannot shadow them.
@export var light_lift := 0.35
@export var outer_energy := 4.8
@export var core_energy := 1.6
@export var outer_fog_energy := 0.15
@export var core_fog_energy := 0.35
@export var beam_density := 0.85
@export var beam_softness := 0.9
@export var surface_fade := 0.5

## Matches the lamp-head emission for material coherence.
const TINT := Color(0.88, 0.94, 1.0)
const NEAR_D := 0.12
const SEGMENTS := 48

var _beam_material: ShaderMaterial


func _ready() -> void:
	if not enabled:
		return
	var map := get_parent().get_node_or_null(map_path) as Node3D
	if map == null:
		push_warning("LampLights: map node '%s' not found" % map_path)
		return
	var shader := load("res://assets/shaders/droid_beam.gdshader") as Shader
	_beam_material = ShaderMaterial.new()
	_beam_material.shader = shader
	_beam_material.set_shader_parameter("beam_tint", TINT)
	_beam_material.set_shader_parameter("beam_density", beam_density)
	_beam_material.set_shader_parameter("beam_softness", beam_softness)
	_beam_material.set_shader_parameter("surface_fade", surface_fade)
	for h in map.find_children(head_pattern, "MeshInstance3D", true, false):
		_build_rig(h as MeshInstance3D)


func _build_rig(head: MeshInstance3D) -> void:
	if head == null:
		return
	var head_aabb: AABB = head.global_transform * head.get_aabb()
	var apex := head_aabb.position + Vector3(0.0, -0.06, 0.0)
	var ground_y := _pole_base_y(head)
	var drop := apex.y - ground_y
	if drop < 1.0:
		return
	var pool_r := drop * tan(deg_to_rad(pool_half_angle))

	var rig := Node3D.new()
	rig.name = String(head.name).replace("_Head", "_Rig")
	rig.position = apex
	add_child(rig)

	# Cone: axis down (-Y), radius 0 at the apex -> pool_r at the ground.
	var cone := MeshInstance3D.new()
	cone.name = "Cone"
	cone.mesh = _make_cone_mesh(drop, pool_r)
	cone.material_override = _beam_material
	rig.add_child(cone)

	# Outer light: the wide, soft pool. Shadowed so walls cut the light.
	var outer := SpotLight3D.new()
	outer.name = "Outer"
	outer.light_color = TINT
	outer.light_energy = outer_energy
	outer.light_indirect_energy = 0.3
	outer.light_volumetric_fog_energy = outer_fog_energy
	outer.light_specular = 0.25
	outer.light_size = 0.3
	outer.spot_angle = pool_half_angle * 1.25
	outer.spot_angle_attenuation = 1.15
	outer.spot_attenuation = 1.0
	outer.spot_range = drop + 1.5
	outer.rotation.x = -PI / 2.0
	outer.shadow_enabled = true
	outer.shadow_blur = 1.0
	outer.shadow_bias = 0.03
	outer.shadow_normal_bias = 1.0
	rig.add_child(outer)

	# Core light: the bright centre column of the shaft.
	var core := SpotLight3D.new()
	core.name = "Core"
	core.light_color = TINT
	core.light_energy = core_energy
	core.light_indirect_energy = 0.12
	core.light_volumetric_fog_energy = core_fog_energy
	core.light_specular = 0.45
	core.light_size = 0.08
	core.spot_angle = pool_half_angle * 0.7
	core.spot_angle_attenuation = 1.35
	core.spot_attenuation = 1.0
	core.spot_range = drop * 0.85
	core.rotation.x = -PI / 2.0
	core.shadow_enabled = false
	rig.add_child(core)

	# Lift both lights below the head fixture (self-shadow guard, same trick
	# as the droid's lights riding ahead of the eye).
	outer.position = Vector3(0.0, -light_lift, 0.0)
	core.position = Vector3(0.0, -light_lift, 0.0)


func _pole_base_y(head: MeshInstance3D) -> float:
	var pole := head.get_parent().get_node_or_null(
		String(head.name).replace("_Head", "_Pole")) as MeshInstance3D
	if pole == null:
		return 0.0
	return (pole.global_transform * pole.get_aabb()).position.y


func _make_cone_mesh(drop: float, pool_r: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var tan_half := tan(deg_to_rad(pool_half_angle))
	for ring in [NEAR_D, drop]:
		var radius: float = float(ring) * tan_half
		for i in range(SEGMENTS):
			var a := TAU * float(i) / float(SEGMENTS)
			verts.append(Vector3(cos(a) * radius, -float(ring), sin(a) * radius))
			normals.append(Vector3(cos(a), tan_half, sin(a)).normalized())
			uvs.append(Vector2(float(i) / SEGMENTS, (float(ring) - NEAR_D) / (drop - NEAR_D)))
	for i in range(SEGMENTS):
		var n := (i + 1) % SEGMENTS
		indices.append_array(PackedInt32Array([i, SEGMENTS + i, SEGMENTS + n, i, SEGMENTS + n, n]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
