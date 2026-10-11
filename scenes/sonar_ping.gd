extends Node3D
## Sonar-Ping: expandierendes Ring-Kreuz (horizontal + 2 vertikal = 3D-Kugel-
## Anmutung statt flacher Scheibe) + Funken-Streuung (GPUParticles, kugel-
## foermig, Front-Tempo) + gedimmter Lichtblitz (1,6 statt 4,0).
## Scannt waehrend der Expansion alle Nodes der Gruppe "echo_receiver":
## Wer von der Wellenfront erreicht wird, wird revealed (Marker + Alert-Anim + HUD).

var rmax: float = 25.0
var expand_speed: float = 15.625
var _dur: float = 1.6
const RING2_DELAY: float = 0.25
const RING2_DUR: float = 2.0
const MARKER_SCRIPT: Script = preload("res://scenes/ping_marker.gd")

var _t: float = 0.0
var _r_now: float = 0.0
var _hit: Array = []
var _mat1: StandardMaterial3D
var _mat2: StandardMaterial3D

@onready var _ring1: MeshInstance3D = $Ring1
@onready var _ring2: MeshInstance3D = $Ring2
@onready var _ringv1: MeshInstance3D = $RingV1
@onready var _ringv2: MeshInstance3D = $RingV2
@onready var _flash: OmniLight3D = $Flash


func _ready() -> void:
	add_to_group("active_ping")
	_dur = rmax / maxf(expand_speed, 0.01)
	_mat1 = (_ring1.get_active_material(0) as StandardMaterial3D).duplicate()
	_mat2 = (_ring2.get_active_material(0) as StandardMaterial3D).duplicate()
	_ring1.set_surface_override_material(0, _mat1)
	_ring2.set_surface_override_material(0, _mat2)
	_ringv1.set_surface_override_material(0, _mat1)
	_ringv2.set_surface_override_material(0, _mat2)
	# Vertikal-Ringe: Kreuz-Ebenen (XY + ZY), Skalierung laeuft im lokalen
	# XZ-Frame wie bei den Horizontal-Ringen -> expandierende Kugel-Silhouette.
	_ringv1.rotation.x = PI * 0.5
	_ringv2.rotation.x = PI * 0.5
	_ringv2.rotation.y = PI * 0.5
	_ring2.visible = false
	_ringv2.visible = false
	_build_sparks()


## Einmal-Funken: Kugel-Emission mit Front-Tempo + Daempfung (Streu-Schweif
## hinter der Wellenfront), Billboard-Quads, Alpha-Rampe -> kein Aufpoppen.
## Programmiert statt .tscn (weniger Export-Bruchstellen, Tempo aus Powerups).
func _build_sparks() -> void:
	var p := GPUParticles3D.new()
	p.name = "Sparks"
	p.amount = 160
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.85
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.0
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 180.0
	pm.initial_velocity_min = expand_speed * 0.65
	pm.initial_velocity_max = expand_speed * 1.15
	pm.damping_min = 3.0
	pm.damping_max = 5.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var grad := Gradient.new()
	grad.set_color(0, Color(0.5, 0.95, 1.0, 0.7))
	grad.set_color(1, Color(0.4, 0.9, 1.0, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	pm.color_ramp = ramp
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.albedo_color = Color(0.5, 0.95, 1.0, 0.7)
	qm.emission_enabled = true
	qm.emission = Color(0.4, 0.9, 1.0)
	qm.emission_energy_multiplier = 0.8
	quad.material = qm
	p.draw_pass_1 = quad
	add_child(p)
	p.emitting = true


func _physics_process(delta: float) -> void:
	_t += delta
	var k1: float = clampf(_t / _dur, 0.0, 1.0)
	var r1: float = rmax * (1.0 - pow(1.0 - k1, 2.0))
	_r_now = r1
	_ring1.scale = Vector3(r1, 1.5, r1)
	_ringv1.scale = Vector3(r1, 1.5, r1)
	_mat1.albedo_color.a = 1.0 - k1
	_scan(r1)
	var k2: float = clampf((_t - RING2_DELAY) / RING2_DUR, 0.0, 1.0)
	if k2 > 0.0:
		_ring2.visible = true
		_ringv2.visible = true
		var r2: float = rmax * (1.0 - pow(1.0 - k2, 2.0))
		_ring2.scale = Vector3(r2, 1.5, r2)
		_ringv2.scale = Vector3(r2, 1.5, r2)
		_mat2.albedo_color.a = 0.6 * (1.0 - k2)
	_flash.light_energy = maxf(0.0, 1.6 * (1.0 - _t / 0.8))
	_flash.omni_range = maxf(4.0, r1)
	if _t > RING2_DELAY + RING2_DUR + 0.2:
		queue_free()


func get_radius() -> float:
	return _r_now


func _scan(radius: float) -> void:
	for rec in get_tree().get_nodes_in_group("echo_receiver"):
		if not (rec is Node3D) or rec in _hit:
			continue
		var d: Vector3 = (rec as Node3D).global_position - global_position
		if Vector2(d.x, d.z).length() <= radius:
			_hit.append(rec)
			_reveal(rec)


func _reveal(rec: Node) -> void:
	var first: bool = not rec.has_meta("echo_revealed")
	if first:
		rec.set_meta("echo_revealed", true)
		var mk := Node3D.new()
		mk.set_script(MARKER_SCRIPT)
		mk.name = "PingMarker"
		rec.add_child(mk)
		var h := 2.0
		if rec.has_method("get_marker_height"):
			h = float(rec.get_marker_height())
		mk.position = Vector3(0.0, h, 0.0)
		var hud: Node = get_tree().get_first_node_in_group("sonar_hud")
		if hud != null and hud.has_method("add_contact"):
			hud.add_contact()
	for ap in rec.find_children("*", "AnimationPlayer", true, false):
		if (ap as AnimationPlayer).has_animation("E_Anim_Alert"):
			(ap as AnimationPlayer).play("E_Anim_Alert")
