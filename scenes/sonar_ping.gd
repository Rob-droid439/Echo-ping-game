extends Node3D
## Sonar-Ping: expandierender Doppel-Ring + Lichtblitz.
## Scannt waehrend der Expansion alle Nodes der Gruppe "echo_receiver":
## Wer von der Wellenfront erreicht wird, wird revealed (Marker + Alert-Anim + HUD).

var rmax: float = 25.0
var expand_speed: float = 15.625
var _dur: float = 1.6
const RING2_DELAY: float = 0.25
const RING2_DUR: float = 2.0
const MARKER_SCRIPT: Script = preload("res://scenes/ping_marker.gd")

var _t: float = 0.0
var _hit: Array = []
var _mat1: StandardMaterial3D
var _mat2: StandardMaterial3D

@onready var _ring1: MeshInstance3D = $Ring1
@onready var _ring2: MeshInstance3D = $Ring2
@onready var _flash: OmniLight3D = $Flash


func _ready() -> void:
	_dur = rmax / maxf(expand_speed, 0.01)
	_mat1 = (_ring1.get_active_material(0) as StandardMaterial3D).duplicate()
	_mat2 = (_ring2.get_active_material(0) as StandardMaterial3D).duplicate()
	_ring1.set_surface_override_material(0, _mat1)
	_ring2.set_surface_override_material(0, _mat2)
	_ring2.visible = false


func _physics_process(delta: float) -> void:
	_t += delta
	var k1: float = clampf(_t / _dur, 0.0, 1.0)
	var r1: float = rmax * (1.0 - pow(1.0 - k1, 2.0))
	_ring1.scale = Vector3(r1, 1.5, r1)
	_mat1.albedo_color.a = 1.0 - k1
	_scan(r1)
	var k2: float = clampf((_t - RING2_DELAY) / RING2_DUR, 0.0, 1.0)
	if k2 > 0.0:
		_ring2.visible = true
		var r2: float = rmax * (1.0 - pow(1.0 - k2, 2.0))
		_ring2.scale = Vector3(r2, 1.5, r2)
		_mat2.albedo_color.a = 0.6 * (1.0 - k2)
	_flash.light_energy = maxf(0.0, 4.0 * (1.0 - _t / 0.8))
	_flash.omni_range = maxf(4.0, r1)
	if _t > RING2_DELAY + RING2_DUR + 0.2:
		queue_free()


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
		mk.position = Vector3(0.0, 2.2, 0.0)
		var hud: Node = get_tree().get_first_node_in_group("sonar_hud")
		if hud != null and hud.has_method("add_contact"):
			hud.add_contact()
	for ap in rec.find_children("*", "AnimationPlayer", true, false):
		if (ap as AnimationPlayer).has_animation("E_Anim_Alert"):
			(ap as AnimationPlayer).play("E_Anim_Alert")
