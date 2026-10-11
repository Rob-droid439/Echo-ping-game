extends SceneTree
## Sprint-Regression (Spec: Shift = 1,5x, Gehen = 0,7x Basis 5,0):
## Speeds, D_Anim_Sprint (Clip+Loop), Walk-Rate, FOV/Lean, Ping waehrend
## Sprint, Release->Idle. Aufruf: console --headless --path . -s res://tests/regression_sprint.gd
## Erwartung: 9x PASS + RESULT: OK.

var _fails := 0
var _f := 0
var _level: Node
var _player: CharacterBody3D
var _ap: AnimationPlayer
var _cam: Camera3D
var _w := InputEventKey.new()
var _sh := InputEventKey.new()


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		_fails += 1
		printerr("FAIL: ", label)


func _vel() -> float:
	return Vector2(_player.velocity.x, _player.velocity.z).length()


func _initialize() -> void:
	_level = (load("res://scenes/level_1.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_player = _level.get_node("Player")
	_ap = _player.get_node("Rig").find_child("AnimationPlayer", true, false)
	_cam = _level.get_node("Player/CamArm/Camera3D")
	_w.physical_keycode = KEY_W
	_sh.physical_keycode = KEY_SHIFT


func _physics_process(_d: float) -> bool:
	_f += 1
	if _f == 5:
		_w.pressed = true
		Input.parse_input_event(_w)
	if _f == 60:
		_check(absf(_vel() - 3.5) < 0.15, "gehen 3,5 m/s (0,7x)")
		_check(_ap.current_animation == "D_Anim_Walk", "walk-anim beim gehen")
		_check(absf(_ap.speed_scale - 0.7) < 0.05, "walk-rate 0,7 (foot-slide)")
		_sh.pressed = true
		Input.parse_input_event(_sh)
	if _f == 120:
		_check(absf(_vel() - 7.5) < 0.15, "sprint 7,5 m/s (1,5x)")
		_check(_ap.current_animation == "D_Anim_Sprint", "sprint-clip aktiv")
		_check(_cam.fov > 75.0, "fov-kick aktiv")
		_check(bool(_player.call("is_sprinting")), "sprint-flag")
		_check(_player.call("cast_ping"), "ping waehrend sprint moeglich")
	if _f == 130:
		_check(absf(_vel() - 7.5) < 0.3, "tempo bleibt nach ping")
		_w.pressed = false
		_sh.pressed = false
		Input.parse_input_event(_w)
		Input.parse_input_event(_sh)
	if _f == 260:
		_check(_vel() < 0.5 and _ap.current_animation == "D_Anim_Idle", "release -> idle")
		print("RESULT: ", "FAIL" if _fails > 0 else "OK", " (", _fails, " Fehler)")
		return true
	return false
