extends SceneTree
## Stufe-4 Knie-Audit: Walk vs Sprint je Bein, 24 Frames, signierter
## Sagittal-Knie-Winkel via Lateral-Achse der Hips (Cross-Produkt).
## Semantik (Betroffenheit): Walk bleibt Kontakt +sign (bestehender sanfter
## Fold), Sprint nach Fix spiegelt -> sign negativ = natuerliche Beugung
## (Ferse nach hinten/hoch; +sign waere Rueckwaerts-Knie). PASS:
## je Bein genau ein Vorzeichen; Sprint-Vorzeichen gespiegelt zu Walk
## und Beugungen plausibel (< 2.2 rad). Aufruf:
##   console --headless --path . -s res://tools/audit_knee.gd

const SAMPLES := 24
const ANG_TOL := 1.0e-3

var _fails := 0
var _phase := 0
var _ap: AnimationPlayer
var _skel: Skeleton3D
var _hips := -1
var _leg: Dictionary = {0: {}, 1: {}}


func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		_fails += 1
		printerr("FAIL: ", label)


func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_ap(c)
		if r != null:
			return r
	return null


func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skel(c)
		if r != null:
			return r
	return null


func _sample(clip: String, leg_idx: int) -> Dictionary:
	_ap.play(clip)
	_ap.pause()
	var t0: float = _ap.get_animation(clip).length
	var ref: float = t0 if clip == "D_Anim_Sprint" else _ap.get_animation("D_Anim_Walk").length
	var out := []
	for i in range(SAMPLES):
		var t := 1.0 + ref * (float(i) / float(SAMPLES - 1))
		_ap.seek(t, true)
		var thigh_dir: Vector3 = (_skel.get_bone_global_pose(_skel.find_bone("Thigh_L" if leg_idx == 0 else "Thigh_R")).basis * Vector3.UP)
		var shin_dir: Vector3 = (_skel.get_bone_global_pose(_skel.find_bone("Shin_L" if leg_idx == 0 else "Shin_R")).basis * Vector3.UP)
		var lat: Vector3 = _skel.get_bone_global_pose(_hips).basis.x
		var cross := lat.dot(thigh_dir.cross(shin_dir))
		var ang := thigh_dir.angle_to(shin_dir)
		out.append({"t": t, "ang": ang, "sign": 0 if absf(cross) < ANG_TOL else (1 if cross > 0.0 else -1)})
	var signs := {}
	var negs := 0
	var poss := 0
	var mx := -1.0e9
	var mn := 1.0e9
	for s in out:
		signs[s["sign"]] = true
		mx = maxf(mx, s["ang"])
		mn = minf(mn, s["ang"])
		if s["sign"] > 0: poss += 1
		elif s["sign"] < 0: negs += 1
	return {"frames": out, "signs": signs, "pos": poss, "neg": negs, "max": mx, "min": mn}


func _initialize() -> void:
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	root.add_child(player)
	_ap = _find_ap(player)
	_skel = _find_skel(player)
	_hips = _skel.find_bone("Hips")


func _physics_process(_d: float) -> bool:
	if Engine.get_physics_frames() < 5:
		return false
	if _phase == 0:
		var ok := true
		var res := {}
		for clip in ["D_Anim_Walk", "D_Anim_Sprint"]:
			for leg in [0, 1]:
				res[clip + "_" + str(leg)] = _sample(clip, leg)
				var r: Dictionary = res[clip + "_" + str(leg)]
				var label: String = (clip + " leg" + ("L" if leg == 0 else "R")
					+ " sign(s)=" + str(r["signs"].keys()) + " flex " + str(snappedf(r["min"], 0.1)) + ".." + str(snappedf(r["max"], 0.1)) + " rad")
				print("  ", label)
				if r["signs"].keys().size() > 1:
					ok = false
					printerr("  VERSCHIEDENE SIGNs in ", label)
		_phase = 1
		_fails += 0 if ok else 1
		_check(ok, "knie walk+sprint: jeweils 1 Vorzeichen pro Bein (keine Rueckwaerts-Knie)")
		# Sprint == gespiegeltes Walk-Vorzeichen (Fix), Walk unveraendert als Kontrolle
		for leg in [0, 1]:
			var w: Dictionary = res["D_Anim_Walk_" + str(leg)]
			var s: Dictionary = res["D_Anim_Sprint_" + str(leg)]
			var wsign: int = int(w["signs"].keys()[0])
			var lname := ("L" if leg == 0 else "R")
			_check(wsign == 1, "knie-kontrolle leg" + lname + " Walk bleibt +Vorzeichen")
			_check(ArraysEqual(s["signs"].keys(), [-wsign]), "knie-fix leg" + lname
				+ " Sprint-Vorzeichen gespiegelt zu Walk")
			_check(absf(s["max"]) < 2.2 and absf(s["min"]) < 2.2, "knie-range leg"
				+ lname + " plausibel (<2.2 rad)")
		print("RESULT: ", "FAIL" if _fails > 0 else "OK", " (", _fails, " Fehler)")
		return true
	return false


func ArraysEqual(a: Array, b: Array) -> bool:
	return a.size() == b.size() and all_same(a, b)


func all_same(a: Array, b: Array) -> bool:
	for i in range(a.size()):
		if a[i] != b[i]:
			return false
	return true
