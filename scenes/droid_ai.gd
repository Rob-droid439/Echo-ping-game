extends CharacterBody3D
## Droiden-KI, Port aus dem Java-Original (EnemyAI + HearingModel + Enemy):
## Patrol (Zufalls-Wegpunkte + Pause), Hearing (Ping-Suspicion mit Latenz
## und Treffer-Unsteuerung), Vision (28-Grad-Kegel + Sichtlinie), Chase
## (SEEN exakt / HEARD mit Unschaerfe), Catch-Reset (Prototyp-Regel:
## Beruehrung im SEEN-Zustand setzt Spieler und Droiden zurueck).

enum Alert { IDLE, HEARD, SEEN }

const PATROL_SPEED := 3.5
const SVAR_PATROL_MIN := 0.8
const SVAR_PATROL_MAX := 1.15
const SVAR_AGGRO_MIN := 1.0
const SVAR_AGGRO_MAX := 1.45
const SVAR_INT_MIN := 0.2
const SVAR_INT_MAX := 0.65
const VISION_RANGE := 9.0
const VISION_DOT := 0.8829
const EYE_H := 1.2
const PLAYER_H := 1.0
const HEAR_RANGE := 18.0
const SUS_GAIN := 10.0
const SUS_DECAY := 0.12
const SUS_TH := 0.12
const SUS_CANCEL := 0.07
const MIN_SIG := 0.01
const ORIGIN_W := 0.48
const WAVE_W := 0.72
const WAVE_SIGMA := 4.6
const OCCLUDE_DAMP := 0.88
const LAT_MIN := 0.06
const LAT_MAX := 0.2
const SEARCH_MIN := 0.1
const SEARCH_MAX := 0.26
const UNC_MAX := 1.5
const UNC_MIN := 0.25
const AGGRO_MIN := 1.7
const AGGRO_MAX := 3.0
const SEEN_DUR := 1.7
const COOL_MIN := 0.14
const COOL_MAX := 0.48
const WP_TH := 0.6
const PAUSE_MIN := 0.12
const PAUSE_MAX := 0.45
const STRAFE_MAX := 0.3
const STRAFE_T_MIN := 0.15
const STRAFE_T_MAX := 0.35
const STUCK_TIME := 0.3
const CATCH_DIST := 1.6
const CATCH_GRACE := 1.2
# Stufe 1 (ohne Navmesh): Wand-Fuehler + Richtungs-Sampling.
const FEELER_LEN := 2.0
const FEELER_ANGLE := 0.61 # ~35 Grad
const FEELER_H := 1.0
const CLEAR_LEN := 4.0
const WP_TRIES := 8
const GROUND_DROP := 3.0
const GROUND_BAND := 1.5
const SFX_YELLOW: AudioStream = preload("res://assets/audio/EnemyAlertYellow.wav")
const SFX_RED: AudioStream = preload("res://assets/audio/EnemyAlertRed.wav")

## Patrol-Radius pro Droid (Blender-Vermessung 2026-09-24):
## offene Plaetze (L1-Plaza ~90 % frei) 9 m, enge Slots (L2 Blockriegel) 4-5 m.
@export var roam_radius := 9.0
## Stufe 2: Navmesh aus `-col`-Geometrie gebacken (assets/nav/*.tres) +
## NavigationAgent3D als Kindknoten -> CHASE/HEARD per Pfad, sonst
## Stufe-1-Fallback (Validierung + Fuehler). Patrol bleibt immer Waypoint.
@export var use_navmesh := false
## Debug-Metrik fuer Playtests (Stuck-Counter + Waypoint-Rejects).
@export var debug_log := false

var alert: int = Alert.IDLE
var facing: Vector3 = Vector3(0.0, 0.0, -1.0)
var suspicion: float = 0.0

var _spawn := Vector3.ZERO
var _target := Vector3.ZERO
var _has_target := false
var _aggro_t := 0.0
var _pause_t := 0.0
var _svar_t := 0.0
var _svar_mult := 1.0
var _strafe_t := 0.0
var _strafe := Vector2.ZERO
var _stuck_t := 0.0
var _cool := 0.0
var _pend := false
var _lat_t := 0.0
var _search_t := 0.0
var _pend_ox := 0.0
var _pend_oz := 0.0
var _pend_sig := 0.0
var _ap: AnimationPlayer
var _sfx_alert: AudioStreamPlayer3D
var _catch_grace := 0.0
var _nav_agent: NavigationAgent3D
var _dbg_rejects := 0
var _dbg_stucks := 0
var _dbg_feeler_turns := 0
var _dbg_nav_steps := 0
var _eye_nodes: Dictionary = {}
var _eye_mats: Dictionary = {}
var _eye_key := ""

@onready var _rig: Node3D = $Rig


func _ready() -> void:
	add_to_group("echo_receiver")
	_spawn = global_position
	_ap = _rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for a in ["E_Anim_Patrol", "E_Anim_Idle", "E_Anim_Alert"]:
		if _ap.has_animation(a):
			_ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_ap.play("E_Anim_Patrol")
	_sfx_alert = AudioStreamPlayer3D.new()
	_sfx_alert.max_distance = 40.0
	add_child(_sfx_alert)
	_nav_agent = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	_cache_eye()
	_update_eye(true)


func get_alert() -> String:
	match alert:
		Alert.HEARD:
			return "HEARD"
		Alert.SEEN:
			return "SEEN"
	return "IDLE"


func reset_droid() -> void:
	global_position = _spawn
	velocity = Vector3.ZERO
	alert = Alert.IDLE
	suspicion = 0.0
	_aggro_t = 0.0
	_pause_t = 0.2
	_has_target = false
	_pend = false
	_cool = 0.0
	_catch_grace = CATCH_GRACE
	if _nav_agent != null:
		_nav_agent.target_position = _spawn
	_update_eye(true)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	else:
		velocity.y = -0.5
	_cool = maxf(0.0, _cool - delta)
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		if _see_player(player):
			_set_aggro(player.global_position, SEEN_DUR, true)
			suspicion = 1.0
			_pend = false
			_cool = 0.0
		else:
			_hearing(delta)
	if alert != Alert.IDLE:
		_aggro_t -= delta
		if _aggro_t <= 0.0:
			alert = Alert.IDLE
			_has_target = false
	_catch_grace = maxf(0.0, _catch_grace - delta)
	_update_speed_var(delta)
	_update_move(delta)
	if player != null and alert == Alert.SEEN and _catch_grace <= 0.0:
		var d: Vector3 = player.global_position - global_position
		# Planar + Hoehe + Sichtlinie: kein Catch durch Waende/Etagen,
		# sonst Teleport-Reset-Schleife (Bot poppt zum Spawn).
		if Vector2(d.x, d.z).length() < CATCH_DIST and absf(d.y) < 2.0 and _has_los(player):
			_caught(player)
	_update_anim()
	_update_eye()


func _see_player(p: Node3D) -> bool:
	var to: Vector3 = p.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if dist > VISION_RANGE:
		return false
	if dist > 0.05 and facing.normalized().dot(to.normalized()) < VISION_DOT:
		return false
	var from: Vector3 = global_position + Vector3(0.0, EYE_H, 0.0)
	var dst: Vector3 = p.global_position + Vector3(0.0, PLAYER_H, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, dst, 1, [get_rid(), (p as CollisionObject3D).get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (hit["collider"] as Node) == p


func _has_los(p: Node3D) -> bool:
	# Reine Sichtlinie ohne Kegel/Distanz (fuer Catch): blockt Waende.
	var from: Vector3 = global_position + Vector3(0.0, EYE_H, 0.0)
	var dst: Vector3 = p.global_position + Vector3(0.0, PLAYER_H, 0.0)
	if not (p is CollisionObject3D):
		return false
	var query := PhysicsRayQueryParameters3D.create(from, dst, 1, [get_rid(), (p as CollisionObject3D).get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (hit["collider"] as Node) == p


func get_marker_height() -> float:
	return 3.0


func _hearing(delta: float) -> void:
	var sig := 0.0
	var ox := 0.0
	var oz := 0.0
	for ping in get_tree().get_nodes_in_group("active_ping"):
		var po: Vector3 = (ping as Node3D).global_position
		var dd: Vector3 = global_position - po
		dd.y = 0.0
		var dist := dd.length()
		if dist > HEAR_RANGE:
			continue
		var fall := 1.0 - dist / HEAR_RANGE
		fall *= fall
		var r := 12.5
		if ping.has_method("get_radius"):
			r = float(ping.get_radius())
		var wave: float = exp(-pow(absf(dist - r), 2.0) / (2.0 * WAVE_SIGMA * WAVE_SIGMA))
		var s: float = fall * (ORIGIN_W + WAVE_W * wave)
		var excl: Array = [get_rid()]
		var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
		if player != null and player is CollisionObject3D:
			excl.append((player as CollisionObject3D).get_rid())
		var q := PhysicsRayQueryParameters3D.create(
			global_position + Vector3(0.0, EYE_H, 0.0), po + Vector3(0.0, 0.5, 0.0), 1, excl)
		if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			s *= OCCLUDE_DAMP
		s *= randf_range(0.9, 1.1)
		s = clampf(s, 0.0, 1.0)
		if s > sig:
			sig = s
			ox = po.x
			oz = po.z
	suspicion = clampf(suspicion + sig * SUS_GAIN * delta - SUS_DECAY * delta, 0.0, 1.0)
	if alert != Alert.IDLE:
		suspicion = maxf(suspicion, SUS_TH)
		return
	if _pend and suspicion < SUS_CANCEL:
		_pend = false
		return
	if not _pend and _cool <= 0.0 and sig >= MIN_SIG and suspicion >= SUS_TH:
		_pend = true
		_pend_ox = ox
		_pend_oz = oz
		_pend_sig = sig
		_lat_t = randf_range(LAT_MIN, LAT_MAX)
		_search_t = randf_range(SEARCH_MIN, SEARCH_MAX)
	if not _pend:
		return
	_lat_t -= delta
	if _lat_t > 0.0:
		return
	_search_t -= delta
	if _search_t > 0.0:
		return
	var unc: float = lerpf(UNC_MAX, UNC_MIN, clampf(_pend_sig, 0.0, 1.0))
	var dur: float = lerpf(AGGRO_MIN, AGGRO_MAX, clampf(_pend_sig, 0.0, 1.0))
	_set_aggro(Vector3(_pend_ox + randf_range(-unc, unc), 0.0, _pend_oz + randf_range(-unc, unc)), dur, false)
	suspicion = maxf(suspicion, SUS_TH)
	_cool = randf_range(COOL_MIN, COOL_MAX)
	_pend = false


func _set_aggro(target: Vector3, dur: float, seen: bool) -> void:
	# Alert-Sting nur bei Flankenwechsel (2D-Original: Yellow=gehört, Rot=gesehen).
	if seen and alert != Alert.SEEN:
		_sfx_alert.stream = SFX_RED
		_sfx_alert.play()
	elif not seen and alert == Alert.IDLE:
		_sfx_alert.stream = SFX_YELLOW
		_sfx_alert.play()
	alert = Alert.SEEN if seen else Alert.HEARD
	_aggro_t = dur * randf_range(0.85, 1.25)
	var t := Vector3(target.x, _spawn.y, target.z)
	if not seen:
		# HEARD: nie gegen die Wand rennen, hinter der es gehoert wurde —
		# Ziel auf letzte freie Position vor dem Hindernis klemmen.
		t = _clamp_target_to_los(t)
	# SEEN braucht kein Klemmen: Sichtlinie ist per _see_player belegt.
	_target = t
	_has_target = true
	_pause_t = 0.0
	_svar_t = 0.0
	_strafe_t = 0.0
	_stuck_t = 0.0
	_push_nav_target()


## HEARD-Ziel an der Wand klemmen: Ray Bot->Ziel, bei Treffer kurz davor
## stoppen (1 m Puffer = Bot-Radius), damit kein Anrennen gegen Waende.
func _clamp_target_to_los(t: Vector3) -> Vector3:
	var from: Vector3 = global_position + Vector3(0.0, EYE_H, 0.0)
	var dst := Vector3(t.x, global_position.y + EYE_H, t.z)
	var to: Vector3 = dst - from
	var dist := to.length()
	if dist < 0.5:
		return t
	var query := PhysicsRayQueryParameters3D.create(from, dst, 1, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return t
	var hp: Vector3 = hit["position"]
	var back: Vector3 = hp - to.normalized() * 1.0
	return Vector3(back.x, _spawn.y, back.z)


func get_debug_stats() -> Dictionary:
	return {
		"stucks": _dbg_stucks,
		"waypoint_rejects": _dbg_rejects,
		"feeler_turns": _dbg_feeler_turns,
		"nav_steps": _dbg_nav_steps,
		"alert": get_alert(),
	}


func _dbg(msg: String) -> void:
	if debug_log:
		print("[droid %s] %s (stucks=%d rejects=%d feels=%d)" % [
			name, msg, _dbg_stucks, _dbg_rejects, _dbg_feeler_turns])


func _update_speed_var(delta: float) -> void:
	_svar_t -= delta
	if _svar_t > 0.0:
		return
	if alert == Alert.IDLE:
		_svar_mult = randf_range(SVAR_PATROL_MIN, SVAR_PATROL_MAX)
	else:
		_svar_mult = randf_range(SVAR_AGGRO_MIN, SVAR_AGGRO_MAX)
	_svar_t = randf_range(SVAR_INT_MIN, SVAR_INT_MAX)


func _pick_waypoint() -> void:
	# Wegpunkt-Validierung: Boden darunter + Luftlinie frei, sonst neu
	# wuerfeln (max. WP_TRIES). Verhindert Ziele in Waenden/Abgruenden.
	for _try in WP_TRIES:
		var cand: Vector3 = _spawn + Vector3(
			randf_range(-roam_radius, roam_radius), 0.0,
			randf_range(-roam_radius, roam_radius))
		cand.y = _spawn.y
		if _is_waypoint_valid(cand):
			_target = cand
			_has_target = true
			_pause_t = randf_range(PAUSE_MIN, PAUSE_MAX)
			_push_nav_target()
			return
		_dbg_rejects += 1
	# Alle Versuche verworfen (enge Zone): nahen Ausweichpunkt samplen,
	# damit der Bot nie ohne Ziel stehen bleibt.
	_dbg("alle Wegpunkte verworfen, sampling-resolve")
	_target = _sample_free_dir(3.0)
	_target.y = _spawn.y
	_has_target = true
	_pause_t = randf_range(PAUSE_MIN, PAUSE_MAX)
	_push_nav_target()


## Gueltig = Boden im Band +-GROUND_BAND unter dem Punkt (kein Abgrund,
## keine andere Etage) + Luftlinie vom Bot frei (kein Ziel in der Wand).
func _is_waypoint_valid(p: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var down := PhysicsRayQueryParameters3D.create(
		p + Vector3(0.0, 2.0, 0.0), p + Vector3(0.0, -GROUND_DROP, 0.0), 1, [get_rid()])
	var g: Dictionary = space.intersect_ray(down)
	if g.is_empty():
		return false
	var gy: float = (g["position"] as Vector3).y
	if absf(gy - _spawn.y) > GROUND_BAND:
		return false
	var eye: Vector3 = global_position + Vector3(0.0, EYE_H, 0.0)
	var dst := Vector3(p.x, global_position.y + EYE_H, p.z)
	var line := PhysicsRayQueryParameters3D.create(eye, dst, 1, [get_rid()])
	return space.intersect_ray(line).is_empty()


func _update_move(delta: float) -> void:
	if alert == Alert.IDLE and not _has_target:
		_pick_waypoint()
	if _pause_t > 0.0:
		_pause_t -= delta
		velocity.x = move_toward(velocity.x, 0.0, PATROL_SPEED * delta)
		velocity.z = move_toward(velocity.z, 0.0, PATROL_SPEED * delta)
		move_and_slide()
		return
	if alert != Alert.IDLE:
		_strafe_t -= delta
		if _strafe_t <= 0.0:
			_strafe = Vector2(randf_range(-STRAFE_MAX, STRAFE_MAX), randf_range(-STRAFE_MAX, STRAFE_MAX))
			_strafe_t = randf_range(STRAFE_T_MIN, STRAFE_T_MAX)
	var goal: Vector3 = _target + Vector3(_strafe.x, 0.0, _strafe.y)
	var to: Vector3 = goal - global_position
	to.y = 0.0
	if to.length() < WP_TH:
		_stuck_t = 0.0
		if alert == Alert.IDLE:
			_pick_waypoint()
		return
	var dir: Vector3 = to.normalized()
	# Stufe 2 (opt-in): Pfadposition statt Luftlinie, Fallback unten.
	# Patrol bleibt absichtlich Waypoint (billig, organisch) — _nav_active
	# gilt nur fuer HEARD/SEEN.
	if _nav_active():
		if _nav_agent.is_navigation_finished():
			# Pfadende erreicht, Ziel aber noch da (HEARD-Streu): frisch
			# anfordern statt auf der Stelle zu treten.
			_nav_agent.target_position = _target
		var next: Vector3 = _nav_agent.get_next_path_position()
		var nt: Vector3 = next - global_position
		nt.y = 0.0
		if nt.length() > 0.2:
			dir = nt.normalized()
			_dbg_nav_steps += 1
	# Wand-Fuehler: blockierte Richtung wegdrehen statt frontal wall-sliden.
	dir = _steer_feelers(dir)
	if dir.length() < 0.01:
		# Sackgasse: Resolve laeuft, Bot bremst ohne Facing zu verlieren.
		velocity.x = move_toward(velocity.x, 0.0, PATROL_SPEED * delta)
		velocity.z = move_toward(velocity.z, 0.0, PATROL_SPEED * delta)
		move_and_slide()
		return
	# Anti-Glitch-Gelaender: Kollision vorab testen (test_move = true heisst
	# BLOCKIERT); bei Wandkontakt Sampling-Resolve statt Clip.
	if test_move(global_transform, dir * 0.6):
		_resolve_stuck(dir)
		return
	var spd: float = PATROL_SPEED * _svar_mult
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	move_and_slide()
	facing = Vector3(dir.x, 0.0, dir.z)
	_rig.rotation.y = lerp_angle(_rig.rotation.y, atan2(-dir.x, -dir.z), 8.0 * delta)
	if get_real_velocity().length() < 0.3:
		_stuck_t += delta
		if _stuck_t >= STUCK_TIME:
			_stuck_t = 0.0
			_resolve_stuck(dir)
	else:
		_stuck_t = 0.0


func _nav_active() -> bool:
	return use_navmesh and _nav_agent != null and alert != Alert.IDLE and _has_target


func _push_nav_target() -> void:
	if _nav_agent != null and _has_target:
		_nav_agent.target_position = _target


## 3 kurze Raycasts (vorne/links/rechts, FEELER_LEN): freie Seite gewinnt,
## Sackgasse -> Sampling-Resolve. Zaehlt Fuehler-Drehungen fuer Playtests.
func _steer_feelers(dir: Vector3) -> Vector3:
	if _feeler_blocked(dir, 0.0, FEELER_LEN):
		var left_open := not _feeler_blocked(dir, FEELER_ANGLE, FEELER_LEN)
		var right_open := not _feeler_blocked(dir, -FEELER_ANGLE, FEELER_LEN)
		_dbg_feeler_turns += 1
		if left_open and not right_open:
			return dir.rotated(Vector3.UP, FEELER_ANGLE)
		if right_open and not left_open:
			return dir.rotated(Vector3.UP, -FEELER_ANGLE)
		if left_open and right_open:
			if _clearance(dir, FEELER_ANGLE) >= _clearance(dir, -FEELER_ANGLE):
				return dir.rotated(Vector3.UP, FEELER_ANGLE)
			return dir.rotated(Vector3.UP, -FEELER_ANGLE)
		_resolve_stuck(dir)
		return Vector3.ZERO
	return dir


func _feeler_blocked(dir: Vector3, angle: float, length: float) -> bool:
	var d: Vector3 = dir.rotated(Vector3.UP, angle)
	var from: Vector3 = global_position + Vector3(0.0, FEELER_H, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, from + d * length, 1, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Freiraum in einer Richtung (0..CLEAR_LEN) — entscheidet bei beidseitig
## offen, wohin der Bot ausweicht.
func _clearance(dir: Vector3, angle: float) -> float:
	var d: Vector3 = dir.rotated(Vector3.UP, angle)
	var from: Vector3 = global_position + Vector3(0.0, FEELER_H, 0.0)
	var query := PhysicsRayQueryParameters3D.create(
		from, from + d * CLEAR_LEN, 1, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return CLEAR_LEN
	return from.distance_to(hit["position"] as Vector3)


## Stuck-Resolve mit Richtungs-Sampling: 3 Kandidaten (+50/-50/+140 Grad),
## besten freien nehmen; Patrol bekommt validierten Ersatz-Wegpunkt.
func _resolve_stuck(dir: Vector3) -> void:
	_dbg_stucks += 1
	_stuck_t = 0.0
	_dbg("stuck-resolve")
	if alert == Alert.IDLE:
		_pick_waypoint()
		return
	_target = _sample_free_dir(3.0, dir)
	_target.y = _spawn.y
	_push_nav_target()


## Naechsten freien Punkt im Radius suchen (Winkelstaffel um Referenz).
func _sample_free_dir(radius: float, ref := Vector3.ZERO) -> Vector3:
	var base: Vector3 = ref if ref.length() > 0.01 else facing
	if base.length() < 0.01:
		base = Vector3(0.0, 0.0, -1.0)
	var best: Vector3 = global_position - base * radius
	var best_clear := -1.0
	for a in [0.87, -0.87, 2.44, -2.44, 3.14]:
		var cand: Vector3 = global_position + base.rotated(Vector3.UP, a) * radius
		cand.y = _spawn.y
		if _is_waypoint_valid(cand):
			return cand
		var c: float = _clearance(base, a)
		if c > best_clear:
			best_clear = c
			best = cand
	best.y = _spawn.y
	return best


func _caught(player: Node3D) -> void:
	# Fang-Regel: Menü zeigen (Game Over / Nochmal), Fallback ohne Menü
	# (z.B. Headless-Verifikation) = sofortiger Respawn wie bisher.
	var menu: Node = get_tree().get_first_node_in_group("game_over")
	if menu != null and menu.has_method("play_catch_animation"):
		menu.play_catch_animation()
		return
	if player.has_method("respawn"):
		player.respawn()
	for d in get_tree().get_nodes_in_group("echo_receiver"):
		if d.has_method("reset_droid"):
			d.reset_droid()


func _update_anim() -> void:
	var want := &"E_Anim_Patrol"
	if get_node_or_null("PingMarker") != null or alert != Alert.IDLE:
		want = &"E_Anim_Alert"
	elif Vector2(velocity.x, velocity.z).length() < 0.5 and _pause_t > 0.0:
		want = &"E_Anim_Idle"
	elif Vector2(velocity.x, velocity.z).length() < 0.5:
		want = &"E_Anim_Patrol"
	if _ap.current_animation != want:
		_ap.play(want, 0.2)


## Eye-/Beacon-Anzeige (Port aus dem 2D-Original, EnemyPalette):
## Mesh nach Alert-State (ED_Eye_IDLE/HEARD/SEEN + Beacon-Trio),
## Glow-Intensitaet nach Suspicion (smoothstep 0.05 -> 0.55 wie 2D),
## SEEN pulsiert rot. Farben kommen aus den Blender-Materialien.
const EYE_STATES := ["IDLE", "HEARD", "SEEN"]


func _cache_eye() -> void:
	for s in EYE_STATES:
		for prefix in ["ED_Eye_", "ED_Beacon_"]:
			var mi := _rig.find_child(prefix + s, true, false) as MeshInstance3D
			if mi == null:
				continue
			_eye_nodes[prefix + s] = mi
			var src := mi.get_active_material(0) as StandardMaterial3D
			if src != null:
				var dup := src.duplicate() as StandardMaterial3D
				mi.set_surface_override_material(0, dup)
				_eye_mats[prefix + s] = dup


static func _sus_blend(s: float) -> float:
	var t := clampf((s - 0.05) / 0.5, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _update_eye(force: bool = false) -> void:
	var key := "IDLE"
	if alert == Alert.SEEN:
		key = "SEEN"
	elif alert == Alert.HEARD:
		key = "HEARD"
	if not force and key == _eye_key:
		_apply_eye_energy(key)
		return
	_eye_key = key
	for s: String in EYE_STATES:
		var on: bool = s == key
		for prefix in ["ED_Eye_", "ED_Beacon_"]:
			var n: String = prefix + s
			if _eye_nodes.has(n):
				(_eye_nodes[n] as MeshInstance3D).visible = on
	_apply_eye_energy(key)


func _apply_eye_energy(key: String) -> void:
	var e := 5.0 + _sus_blend(suspicion) * 3.0
	if key == "SEEN":
		e += sin(Time.get_ticks_msec() * 0.012) * 1.5
	for prefix in ["ED_Eye_", "ED_Beacon_"]:
		var n: String = prefix + key
		if _eye_mats.has(n):
			(_eye_mats[n] as StandardMaterial3D).emission_energy_multiplier = e
