extends SceneTree
## Droiden-Awareness-Regression (Stufe 9, 2026-10-21):
## SA1 Callout: eine HEARD-Drohne weitersagt; Empfaenger im 16-m-Radius geht
##   auf HEARD Richtung Callout, Droiden ausserhalb bleiben IDLE.
## SA2 Vorhalt: compute_lead_target = Live-Pos + Planarvel x 0.45 s,
##   Null nahe am Bot, Klemmung LEAD_MAX.
## Aufruf: console --headless --path . -s res://tests/regression_droid_awareness.gd
## Erwartung: 6x PASS + RESULT: OK.

var _fails := 0
var _f := 0
var _a: Node
var _b: Node
var _c: Node


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		_fails += 1
		printerr("FAIL: ", label)


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/e_droid.tscn")
	_a = scene.instantiate()
	_b = scene.instantiate()
	_c = scene.instantiate()
	_a.position = Vector3.ZERO
	_b.position = Vector3(10.0, 0.0, 5.0)   # 11.2 m von A -> im Callout-Radius
	_c.position = Vector3(24.0, 0.0, 9.0)   # 25.6 m von A -> ausserhalb
	root.add_child(_a)
	root.add_child(_b)
	root.add_child(_c)


func _physics_process(_delta: float) -> bool:
	_f += 1
	if _f == 5:
		_a.notice_heard_target(6.0, 2.0, 1.2, 2.0)
	if _f == 95:
		var b_alert: int = _b.get("alert")
		_check(b_alert == 1, "SA1 Callout: Empfaenger B auf HEARD (1.5 s nach Callout)")
		var at: Vector3 = _a.get("_target")
		var bt: Vector3 = _b.get("_target")
		var err := (bt - at).length()
		_check(err <= 4.5, "SA1 Callout: B-Ziel nah an A-Callout (%.2f m)" % err)
		var c_alert: int = _c.get("alert")
		_check(c_alert == 0, "SA1 Callout: Droid C (>16 m) bleibt IDLE")
		# SA2: statische Vorhalt-Mathematik
		var lead_far: Vector3 = _lead_math(Vector3(6, 0, 0), Vector3(4, 0, 0), Vector3.ZERO)
		_check(absf(lead_far.x - 7.8) <= 0.01, "SA2 Vorhalt: 6 m weg, 4 m/s -> Ziel 7.8 (%.3f)" % lead_far.x)
		var lead_near: Vector3 = _lead_math(Vector3(2, 0, 0), Vector3(4, 0, 0), Vector3.ZERO)
		_check(lead_near.distance_to(Vector3(2, 0, 0)) <= 0.01, "SA2 Vorhalt: 2 m weg -> Live-Position (%.3f)" % lead_near.x)
		var lead_clamp: Vector3 = _lead_math(Vector3(6, 0, 0), Vector3(12, 0, 0), Vector3.ZERO)
		_check(absf(lead_clamp.x - 8.2) <= 0.01, "SA2 Vorhalt: 12 m/s -> LEAD_MAX-Klemme (%.3f)" % lead_clamp.x)
		print("RESULT: ", "FAIL" if _fails > 0 else "OK", " (", _fails, " Fehler)")
		return true
	return false


func _lead_math(p_pos: Vector3, p_vel: Vector3, d_pos: Vector3) -> Vector3:
	var scr: GDScript = load("res://scenes/droid_ai.gd")
	return scr.compute_lead_target(p_pos, p_vel, d_pos, 0.0)
