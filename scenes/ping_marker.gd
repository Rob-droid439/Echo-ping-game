extends Node3D
## Schwebender Reveal-Marker ueber aufgedeckten Zielen.
## Wird per set_script() erzeugt, baut sein Mesh selbst, bobt + faded 6 s.

var _t: float = 0.0
const LIFE: float = 6.0
var _ball: MeshInstance3D
var _mat: StandardMaterial3D


func _ready() -> void:
	name = "PingMarker"
	_mat = StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_color = Color(0.3, 1.0, 0.9, 1.0)
	_mat.emission_enabled = true
	_mat.emission = Color(0.3, 1.0, 0.9, 1.0)
	_mat.emission_energy_multiplier = 3.0
	_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mat.no_depth_test = true
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	sm.material = _mat
	_ball = MeshInstance3D.new()
	_ball.mesh = sm
	_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ball)


func _process(delta: float) -> void:
	_t += delta
	_ball.position.y = sin(_t * 3.0) * 0.15
	if _t > LIFE - 2.0:
		_mat.albedo_color.a = maxf(0.0, (LIFE - _t) / 2.0)
	if _t >= LIFE:
		_calm_parent()
		queue_free()


func _calm_parent() -> void:
	var p: Node = get_parent()
	if p == null:
		return
	for ap in p.find_children("*", "AnimationPlayer", true, false):
		if (ap as AnimationPlayer).has_animation("E_Anim_Idle"):
			(ap as AnimationPlayer).play("E_Anim_Idle")
