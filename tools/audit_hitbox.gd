extends SceneTree
## Hitbox-Audit (Plan Stufe 1): Sicht vs. Kollision maschinell vergleichen +
## Killbox-Sweep am Auto. Aufruf (headless):
##   console --headless --path . -s res://tools/audit_hitbox.gd -- \
##     <level.tscn> <MapNode> <report.md> <findings.json> [CarPrefix]
## Bsp: ... -- res://scenes/level_1.tscn EchoCart_L1 \
##      res://reports/level_1_hitbox_report.md \
##      res://reports/level_1_findings.json L1_Wreck_0
##
## Regeln (Plan §1): Toleranz max. 2 cm Überstand (P0, unsichtbare Wand /
## Stolperkante), ab 5 cm Abdeckungsdefizit (P1, Blockade deckt Geometrie
## nicht). Killbox (Plan §2.1): Raster 0,25 m im Radius 3,5 m um Auto-Mitte
## (aus Welt-AABB des Auto-Meshes), Spieler-Kapsel r 0,35 / h 1,9, je Punkt
## 8 Richtungen à 6 cm per test_move; weg vom Auto blockiert außerhalb des
## Autokennfelds = Befund ("unsichtbare Barriere"). test_move()==true
## heisst BLOCKIERT (claude.md).

const TOL_OVER := 0.02
const TOL_NARROW := 0.05
const KB_RADIUS := 3.5
const KB_STEP := 0.25
const KB_PROBE := 0.06
const CAP_RADIUS := 0.35
const CAP_HEIGHT := 1.9
const CAP_CLEAR := 0.04
const CAR_MARGIN := 0.1
const MAX_REPORT_ROWS := 60
const MAX_SAMPLE_ROWS := 40
const REACH_GROW := 0.42  # Kapselradius 0,35 + Probe 0,06 + Sicherheit

var _f := 0
var _done := false
var _args: Array = []
var _body_vis: Dictionary = {}  # StaticBody3D instance_id -> world-AABB des Partner-Sicht-Mesh


func _xform_aabb(node: Node3D, aabb: AABB) -> AABB:
	var xf := node.global_transform
	var out := AABB(xf * aabb.get_center(), Vector3.ZERO)
	for i in 8:
		var p := Vector3(
			lerpf(aabb.position.x, aabb.end.x, (i & 1) as float),
			lerpf(aabb.position.y, aabb.end.y, ((i >> 1) & 1) as float),
			lerpf(aabb.position.z, aabb.end.z, ((i >> 2) & 1) as float))
		out = out.merge(AABB(xf * p, Vector3.ZERO))
	return out


func _col_shape_aabb(cs: CollisionShape3D) -> AABB:
	var sh: Shape3D = cs.get_shape()
	var dm: Mesh = sh.get_debug_mesh()
	return _xform_aabb(cs, dm.get_aabb())


func _body_label(body: Node) -> String:
	var par := body.get_parent()
	if par is MeshInstance3D:
		return String(par.name) + "/col"
	return String(body.name)


func _col_label(col: Node) -> String:
	var out := String(col.name)
	if out.contains("StaticBody") or out.begins_with("@"):
		var p := col.get_parent()
		if p is MeshInstance3D:
			out = String(p.name)
	return out


func _merge_visual(list: Array) -> AABB:
	var first := list[0] as Node3D
	var out := _xform_aabb(first, (list[0] as MeshInstance3D).get_aabb())
	for i in range(1, list.size()):
		var m: Node3D = list[i]
		out = out.merge(_xform_aabb(m, (m as MeshInstance3D).get_aabb()))
	return out


func _fmtv(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]


func _initialize() -> void:
	_args = OS.get_cmdline_user_args()
	if _args.size() < 4:
		printerr("usage: -s audit_hitbox.gd -- <level.tscn> <MapNode> <report.md> <findings.json> [CarPrefix]")
		quit(2)
		return
	root.add_child((load(_args[0]) as PackedScene).instantiate())


func _physics_process(_d: float) -> bool:
	_f += 1
	if _f < 4 or _done:
		return _done
	_done = true
	_run()
	return true


func _run() -> void:
	var lvl := root.get_child(root.get_child_count() - 1) as Node3D
	var map := lvl.get_node(_args[1]) as Node3D

	# Inventar
	var meshes: Array = []
	var cols: Array = []
	var stack: Array = [map]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			meshes.append(n)
		if n is CollisionShape3D:
			cols.append(n)
		stack.append_array(n.get_children())

	# Je Collider: Partner finden, AABBs vergleichen
	var findings: Array = []
	var catalog: Array = []
	var unpaired := 0
	for cs in cols:
		var body := cs.get_parent() as StaticBody3D
		var sh: Shape3D = cs.get_shape()
		var col_aabb := _col_shape_aabb(cs)
		var partner_mis: Array = []
		var mode := ""
		if body.get_parent() is MeshInstance3D:
			partner_mis.append(body.get_parent())
			mode = "col"
		else:
			var bn := String(body.name)
			if not bn.is_empty() and bn.find("StaticBody") < 0:
				for m in meshes:
					var mn := String(m.name)
					if mn == bn or mn.begins_with(bn + "_"):
						partner_mis.append(m)
				if not partner_mis.is_empty():
					mode = "colonly-name"
			if partner_mis.is_empty():
				var best: Node = null
				var bestd := INF
				for m in meshes:
					var va := _xform_aabb(m, (m as MeshInstance3D).get_aabb())
					var dd := va.get_center().distance_to(col_aabb.get_center())
					if dd < bestd:
						bestd = dd
						best = m
				if best != null and bestd < 3.0:
					partner_mis.append(best)
					mode = "proximity-%.2fm" % bestd
		var tris := 0
		if sh is ConcavePolygonShape3D:
			tris = (sh as ConcavePolygonShape3D).get_faces().size() / 3
		if partner_mis.is_empty():
			unpaired += 1
			findings.append({
				"severity": "P2", "type": "unpaired",
				"collider": _body_label(body), "visual": "<kein Partner>",
				"mode": "", "shape": sh.get_class(), "tris": tris,
				"note": "CollisionShape ohne Partner (AABB-Size %s, Center %s)" % [
					_fmtv(col_aabb.size), _fmtv(col_aabb.get_center())],
			})
			continue
		var vis_aabb := _merge_visual(partner_mis)
		_body_vis[body.get_instance_id()] = vis_aabb
		var vis_name := String(partner_mis[0].name)
		if partner_mis.size() > 1:
			vis_name += " (+%d Teile)" % (partner_mis.size() - 1)
		var over_x := maxf(0.0, col_aabb.end.x - vis_aabb.end.x)
		var over_y := maxf(0.0, col_aabb.end.y - vis_aabb.end.y)
		var over_z := maxf(0.0, col_aabb.end.z - vis_aabb.end.z)
		var under_x := maxf(0.0, vis_aabb.position.x - col_aabb.position.x)
		var under_y := maxf(0.0, vis_aabb.position.y - col_aabb.position.y)
		var under_z := maxf(0.0, vis_aabb.position.z - col_aabb.position.z)
		var narrow_x := maxf(0.0, vis_aabb.size.x - col_aabb.size.x)
		var narrow_y := maxf(0.0, vis_aabb.size.y - col_aabb.size.y)
		var narrow_z := maxf(0.0, vis_aabb.size.z - col_aabb.size.z)
		catalog.append({
			"mode": mode, "label": _body_label(body), "visual": vis_name,
			"shape": sh.get_class(), "tris": tris,
			"col_size": _fmtv(col_aabb.size), "vis_size": _fmtv(vis_aabb.size),
		})
		var notes_over := ""
		if over_x > TOL_OVER or over_z > TOL_OVER:
			notes_over = "Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +%.3f/%.3f X, +%.3f/%.3f Z (über/unter)" % [
				over_x, under_x, over_z, under_z]
		elif over_y > TOL_OVER:
			notes_over = "Collider-Oberkante %.3f m über Sicht-Oberkante (Bogen-/Stolper-Hitbox)" % over_y
		elif under_y > TOL_OVER:
			notes_over = "Collider-Unterkante %.3f m unter Sicht-Unterkante" % under_y
		if notes_over != "":
			findings.append({
				"severity": "P0", "type": "aabb_over",
				"collider": _body_label(body), "visual": vis_name,
				"mode": mode, "shape": sh.get_class(), "tris": tris,
				"col_aabb": var_to_str(col_aabb), "vis_aabb": var_to_str(vis_aabb),
				"over": _fmtv(Vector3(over_x, over_y, over_z)),
				"under": _fmtv(Vector3(under_x, under_y, under_z)),
				"narrow": _fmtv(Vector3(narrow_x, narrow_y, narrow_z)),
				"note": notes_over,
			})
		if narrow_x > TOL_NARROW or narrow_y > TOL_NARROW or narrow_z > TOL_NARROW:
			findings.append({
				"severity": "P1", "type": "aabb_narrow",
				"collider": _body_label(body), "visual": vis_name,
				"mode": mode, "shape": sh.get_class(), "tris": tris,
				"col_aabb": var_to_str(col_aabb), "vis_aabb": var_to_str(vis_aabb),
				"over": _fmtv(Vector3(over_x, over_y, over_z)),
				"under": _fmtv(Vector3(under_x, under_y, under_z)),
				"narrow": _fmtv(Vector3(narrow_x, narrow_y, narrow_z)),
				"note": "Collider enger als Sichtgeometrie um (%.3f, %.3f, %.3f)" % [
					narrow_x, narrow_y, narrow_z],
			})

	# Killbox-Sweep (nur mit CarPrefix)
	var car_prefix: String = _args[4] if _args.size() > 4 else ""
	var kb := {}
	if car_prefix != "":
		var car_mis: Array = []
		for m in meshes:
			if String(m.name).begins_with(car_prefix):
				car_mis.append(m)
		if car_mis.is_empty():
			findings.append({
				"severity": "P2", "type": "car-not-found",
				"collider": car_prefix, "visual": "<kein Partner>",
				"note": "kein Sicht-Mesh mit Prefix %s" % car_prefix,
			})
		else:
			kb = _killbox(lvl, _merge_visual(car_mis))

	_write_reports(lvl, map, cols, meshes, findings, catalog, unpaired, kb, car_prefix)


func _killbox(lvl: Node3D, car_aabb: AABB) -> Dictionary:
	var center := car_aabb.get_center()
	var space := lvl.get_world_3d().direct_space_state
	var body := CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = CAP_RADIUS
	cap.height = CAP_HEIGHT
	cs.position = Vector3(0, CAP_HEIGHT * 0.5, 0)
	cs.shape = cap
	body.add_child(cs)
	root.add_child(body)

	# Raster 0,25 m im Radius 3,5 m (Plan §2.1)
	var points: Array = []
	var steps := int(ceilf(KB_RADIUS / KB_STEP + 0.001))
	for ix in range(-steps, steps + 1):
		for iz in range(-steps, steps + 1):
			var px := ix * KB_STEP
			var pz := iz * KB_STEP
			if Vector2(px, pz).length() <= KB_RADIUS + 1e-6:
				points.append(Vector2(px, pz))

	# Autokennfeld (XZ-Area des Auto-Meshes + Rand); Samples darinn sind legitim
	var car_xz := Rect2(
		center.x - car_aabb.size.x * 0.5 - CAR_MARGIN,
		center.z - car_aabb.size.z * 0.5 - CAR_MARGIN,
		car_aabb.size.x + 2.0 * CAR_MARGIN,
		car_aabb.size.z + 2.0 * CAR_MARGIN)

	var q := PhysicsRayQueryParameters3D.new()
	q.collision_mask = 1
	var probe_dirs: Array = []
	for k in 8:
		probe_dirs.append(Vector3(cos(k * PI * 0.25), 0, sin(k * PI * 0.25)))
	var sqp := PhysicsShapeQueryParameters3D.new()
	sqp.shape = cap
	sqp.collision_mask = 1

	var n_points := 0
	var n_block := 0
	var n_car := 0
	var n_off := 0
	var n_touch := 0
	var n_overlap_skip := 0
	var guilt := {}
	var samples: Array = []
	for pt_v in points:
		n_points += 1
		var pt: Vector2 = pt_v
		var wx: float = center.x + pt.x
		var wz: float = center.z + pt.y
		var radial := Vector3(pt.x, 0.0, pt.y)
		var in_car: bool = car_xz.has_point(Vector2(wx, wz))
		# Bodenlevel unterm Punkt suchen; Dach- oder Absperr-Treffer verwerfen
		var ground_y := car_aabb.position.y
		q.from = Vector3(wx, car_aabb.end.y + 2.5, wz)
		q.to = Vector3(wx, car_aabb.position.y - 2.0, wz)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			var hpos: Vector3 = hit["position"]
			var hnor: Vector3 = hit["normal"]
			if hnor.y > 0.7 and hpos.y >= car_aabb.position.y - 0.8 \
					and hpos.y <= car_aabb.position.y + 1.2:
				ground_y = hpos.y
		var samp_y := ground_y + CAP_HEIGHT * 0.5 + CAP_CLEAR
		body.global_position = Vector3(wx, samp_y, wz)
		# Rest-Pruefung: Kapsel darf an der Stelle NICHT schon in Geometrie
		# stehen (sonst ist der Punkt eh nicht begehbar → Skip)
		sqp.transform = Transform3D(Basis(), Vector3(wx, samp_y, wz))
		if space.intersect_shape(sqp, 16).size() > 0:
			n_overlap_skip += 1
			continue

		# 8-Richtungs-Sweep (Dokumentation je Punkt)
		var per_dir: Array = []
		for k in probe_dirs.size():
			var kc := KinematicCollision3D.new()
			if body.test_move(body.global_transform, probe_dirs[k] * KB_PROBE, kc):
				per_dir.append({
					"dir": k, "collider": _col_label(kc.get_collider()),
					"normal": kc.get_normal(), "dist": kc.get_travel(),
				})
		if per_dir.size() > 0:
			n_block += 1

		# Bewertung: radialer Auslauf (0, ±45°), weg vom Auto. Nicht legitim
		# = (a) nicht im Autokennfeld UND (b) der Blockierer ist nicht so
		# dicht, dass die Kapsel ihn ohnehin berührt (Sicht-AABB + REACH_GROW)
		var away := {}
		if radial.length() > 0.05:
			var radial_n := radial.normalized()
			for dd in [0.0, PI * 0.25, -PI * 0.25]:
				var aw := radial_n.rotated(Vector3.UP, dd) * KB_PROBE
				var kc2 := KinematicCollision3D.new()
				if body.test_move(body.global_transform, aw, kc2):
					away[dd] = {
						"collider": _col_label(kc2.get_collider()),
						"body_id": kc2.get_collider().get_instance_id(),
						"normal": kc2.get_normal(), "dist": kc2.get_travel(),
					}
		if away.is_empty():
			continue
		if in_car:
			n_car += 1
			samples.append({"x": wx, "z": wz, "in_car": true,
				"r": radial.length(), "ground": ground_y,
				"away": away, "dirs": per_dir, "legit": true})
			continue
		var bad := {}
		var touch := {}
		var sxz := Vector2(wx, wz)
		for e in away.values():
			var bvis: AABB = _body_vis.get(e["body_id"], AABB())
			var reach := Rect2(
				bvis.position.x - REACH_GROW, bvis.position.z - REACH_GROW,
				(bvis.size.x + 2.0 * REACH_GROW), (bvis.size.z + 2.0 * REACH_GROW))
			if reach.has_point(sxz):
				touch[e["collider"]] = e
			else:
				bad[e["collider"]] = e
		if bad.is_empty():
			n_touch += 1
			samples.append({"x": wx, "z": wz, "in_car": false,
				"r": radial.length(), "ground": ground_y,
				"away": away, "dirs": per_dir, "legit": true})
			continue
		n_off += 1
		for cname in bad:
			guilt[cname] = int(guilt.get(cname, 0)) + 1
		samples.append({"x": wx, "z": wz, "in_car": false,
			"r": radial.length(), "ground": ground_y,
			"away": away, "dirs": per_dir, "legit": false})
	body.queue_free()
	return {
		"n_points": n_points,
		"blocked_any": n_block,
		"blocked_carzone": n_car,
		"overlap_skipped": n_overlap_skip,
		"touch_contact": n_touch,
		"blocked_offzone": n_off,
		"blocked_pct": 100.0 * (n_car + n_off) / maxf(1.0, n_points),
		"guilt": guilt,
		"samples": samples,
	}


func _write_reports(lvl: Node3D, map: Node3D, cols: Array, meshes: Array,
		findings: Array, catalog: Array, unpaired: int, kb: Dictionary,
		car_prefix: String) -> void:
	var p0 := 0
	var p1 := 0
	for fd in findings:
		if fd["severity"] == "P0":
			p0 += 1
		elif fd["severity"] == "P1":
			p1 += 1
	var md := "# Hitbox-Report %s · %s\n\n" % [_args[1], String(_args[0]).get_file()]
	md += "Toleranzen: Überstand > %.2f m → P0 (unsichtbare Wand); Abdeckungsdefizit > %.2f m → P1 (Blockade deckt Geometrie nicht). Killbox: Raster %.2f m, Radius %.2f m, Probe %.2f m, Kapsel r %.2f / h %.2f.\n\n" % [
		TOL_OVER, TOL_NARROW, KB_STEP, KB_RADIUS, KB_PROBE, CAP_RADIUS, CAP_HEIGHT]
	md += "**Zusammenfassung**: Collider %d, Meshes %d, unpaired %d — Findings **P0 %d**, **P1 %d**\n\n" % [
		cols.size(), meshes.size(), unpaired, p0, p1]
	if kb.has("n_points"):
		md += "**Killbox '%s'**: Punkte %d, blocked-any %d (%.1f %% der Punkte), im Autokennfeld %d (legitim), Kapselkontakt-an-Soliden %d, Rest-Overlap skipped %d — weg-geblockt ohne Legitimation: **%d** — Schuldverteilung: %s\n\n" % [
			car_prefix, int(kb["n_points"]), int(kb["blocked_any"]),
			float(kb["blocked_pct"]), int(kb["blocked_carzone"]),
			int(kb.get("touch_contact", 0)), int(kb.get("overlap_skipped", 0)),
			int(kb["blocked_offzone"]), str(kb.get("guilt", {}))]
	md += "## Findings\n\n| P | Collider | Partner | Modus | Befund |\n|---|---|---|---|---|\n"
	var rows := mini(findings.size(), MAX_REPORT_ROWS)
	for i in rows:
		var fd2: Dictionary = findings[i]
		md += "| %s | `%s` | `%s` | %s | %s |\n" % [
			fd2["severity"], fd2.get("collider", ""), fd2.get("visual", ""),
			fd2.get("mode", ""), fd2.get("note", "")]
	if findings.size() > rows:
		md += "... (%d weitere laut JSON)\n" % (findings.size() - rows)
	if kb.has("samples"):
		md += "\n## Killbox-Details (weg-blockierte Samples)\n\n| Punkt XZ | Radius | Collider | NormalY | im Kennfeld |\n|---|---|---|---|---|\n"
		var shown := 0
		for s in kb["samples"]:
			shown += 1
			if shown > MAX_SAMPLE_ROWS:
				break
			var ab: Dictionary = s["away"]
			var first: Dictionary = ab.values()[0]
			md += "| (%.2f, %.2f) | %.2f | `%s` | %.2f | %s |\n" % [
				float(s["x"]), float(s["z"]), float(s["r"]), first["collider"],
				(first["normal"] as Vector3).y, str(s["in_car"])]
		if int(kb["blocked_offzone"]) > MAX_SAMPLE_ROWS:
			md += "... (%d weitere laut JSON)\n" % (int(kb["blocked_offzone"]) - MAX_SAMPLE_ROWS)
	else:
		md += "\n## Killbox-Details\n\n(kein CarPrefix übergeben — kein Sweep)\n"
	var f_md := FileAccess.open(_args[2], FileAccess.WRITE)
	f_md.store_string(md)
	f_md.close()
	var f_j := FileAccess.open(_args[3], FileAccess.WRITE)
	f_j.store_string(JSON.stringify({
		"meta": {
			"level": _args[0], "map_node": _args[1], "car_prefix": car_prefix,
			"tolerance_over": TOL_OVER, "tolerance_narrow": TOL_NARROW,
			"killbox": {"radius": KB_RADIUS, "step": KB_STEP, "probe": KB_PROBE,
				"capsule_radius": CAP_RADIUS, "capsule_height": CAP_HEIGHT},
		},
		"summary": {"colliders": cols.size(), "meshes": meshes.size(),
			"unpaired": unpaired, "p0": p0, "p1": p1},
		"catalog": catalog, "findings": findings, "killbox": kb,
	}))
	f_j.close()
	print("AUDIT: ", _args[1], " colliders=", cols.size(), " meshes=", meshes.size(),
		" unpaired=", unpaired, " P0=", p0, " P1=", p1,
		" kb_points=", int(kb.get("n_points", 0)),
		" kb_offzone_blocked=", int(kb.get("blocked_offzone", 0)),
		" report=", _args[2])
	print("RESULT: OK (Berichte geschrieben)")
