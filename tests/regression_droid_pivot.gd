extends SceneTree
## Droid Rig-Pivot-Regression (Bot-Springen Fix 2026-10-11):
## Yaw muss das Mesh starr um die Koerperachse drehen. Vor dem Fix schwang
## der Zentrier-Offset (-1,53 x auf dem Yaw-Node) Pods/Thruster 4-7 m aus.
## Aufruf: console --headless --path . -s res://tests/regression_droid_pivot.gd
## Erwartung: 2x PASS + RESULT: OK.

var _fails := 0
var _f := 0
var _d: Node3D
var _rig: Node3D
var _meshes: Array = []
var _rel0: Array = []


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		_fails += 1
		printerr("FAIL: ", label)


func _initialize() -> void:
	_d = (load("res://scenes/e_droid.tscn") as PackedScene).instantiate()
	root.add_child(_d)
	_d.set_physics_process(false) # KI einfrieren, nur Pivot messen
	_rig = _d.get_node("Rig") as Node3D
	var stack: Array = [_rig]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			_meshes.append(n)
		stack.append_array(n.get_children())


func _physics_process(_delta: float) -> bool:
	_f += 1
	if _f == 3:
		for m in _meshes:
			_rel0.append((m as Node3D).global_position - (_d as Node3D).global_position)
		_rig.rotation.y += PI
	if _f == 6:
		var worst := 0.0
		for i in _meshes.size():
			var rel: Vector3 = (_meshes[i] as Node3D).global_position - (_d as Node3D).global_position
			var want := Vector3(-_rel0[i].x, _rel0[i].y, -_rel0[i].z) # starre 180-Grad-Drehung
			worst = maxf(worst, rel.distance_to(want))
		print("  pivot maxerr: ", worst, " m (", _meshes.size(), " meshes)")
		_check(worst < 0.05, "yaw dreht Mesh starr um Koerperachse (kein Schwenken)")
		var ap: Node = _rig.find_child("AnimationPlayer", true, false)
		var eye: Node = _rig.find_child("ED_Eye_IDLE", true, false)
		_check(ap != null and eye != null, "AnimPlayer + Eye-Lookup via Rig intakt")
		print("RESULT: ", "FAIL" if _fails > 0 else "OK", " (", _fails, " Fehler)")
		return true
	return false
