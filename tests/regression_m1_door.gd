extends SceneTree
## M1-Tuer-Chase + Through-Wall-Catch Regression (Plan §6 Fertig-Kriterien).
## Aufruf: console --headless --path . -s res://tests/regression_m1_door.gd
## Erwartung: 5x PASS + RESULT: OK.
## Godot (x,y,z) <-> Blender (x,-z,y): M1-Tuer Blender (28.5,-15) = Godot (28.5,15).

var _fails := 0
var _frame := 0
var _phase := 0
var _level: Node
var _droid: Node
var _player: Node3D
var _nav0 := 0
var _wall_player_pos := Vector3.ZERO


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		_fails += 1
		printerr("FAIL: ", label)


func _initialize() -> void:
	_level = (load("res://scenes/level_1.tscn") as PackedScene).instantiate()
	root.add_child(_level)
	_droid = _level.get_node("E_Droid")
	_player = _level.get_node("Player") as Node3D


func _physics_process(_delta: float) -> bool:
	_frame += 1
	if _phase == 0:
		# Tuer-Chase: Droid suedlich vor M1-Tuer, Spieler drin -> Ping.
		if _frame == 5:
			(_droid as Node3D).global_position = Vector3(28.5, 0.1, 13.0)
			_droid.call("reset_droid")
			(_droid as Node3D).global_position = Vector3(28.5, 0.1, 13.0)
			_player.global_position = Vector3(28.0, 0.1, 19.0)
			_nav0 = int((_droid.call("get_debug_stats") as Dictionary)["nav_steps"])
			(_player as Node).call("cast_ping")
		if _frame == 600:
			var dd: float = (_droid as Node3D).global_position.distance_to(_player.global_position)
			var st: Dictionary = _droid.call("get_debug_stats")
			print("  m1 metrik: ", st, " dist: ", dd)
			_check(_droid.get("alert") != 0, "m1 hearing durch Tuer (HEARD/SEEN)")
			_check(int(st["nav_steps"]) > _nav0, "m1 chase nutzt Navmesh-Pfad")
			_check(dd < 3.0, "m1 droid erreicht Spieler durch Tuer (dist < 3m)")
			_check(int(st["stucks"]) <= 5, "m1 stuck-resolves <= 5")
			paused = false
			_phase = 1
			_frame = 0
	elif _phase == 1:
		# Through-Wall-Catch: 1,2 m Abstand, M1-Suedwand dazwischen, SEEN erzwungen.
		if _frame == 5:
			(_droid as Node3D).global_position = Vector3(27.0, 0.1, 14.4)
			_droid.call("reset_droid")
			(_droid as Node3D).global_position = Vector3(27.0, 0.1, 14.4)
			_wall_player_pos = Vector3(27.0, 0.1, 15.6)
			_player.global_position = _wall_player_pos
			_droid.call("_set_aggro", _wall_player_pos, 5.0, true)
		if _frame == 120:
			var moved: float = _player.global_position.distance_to(_wall_player_pos)
			print("  catch metrik: alert=", _droid.call("get_alert"), " player_moved=", moved, " paused=", paused)
			_check(moved < 0.5 and not paused, "kein Catch durch Wand (kein Respawn/Menue)")
			print("RESULT: ", "FAIL" if _fails > 0 else "OK", " (", _fails, " Fehler)")
			return true
	return false
