extends CharacterBody3D
## Droiden-KI v2 (2026-10-18, kompletter Rebuild):
##   Vision mit Aufbau (Heat 0..1): 28-Grad-Kernkegel + 60-Grad-Peripherie,
##   Distanz- und Move-Faktor. heat 0.4 -> HEARD (Neugier: untersucht mit
##   Sting), heat 1.0 -> SEEN (Jagd: Chase auf Live-Position + Catch).
##   Sichtverlust: SEEN faellt in HEARD zur letztgesehenen Position mit
##   Kopf-Scan (Suchverhalten), nicht direkt zurueck in Frieden.
##   Omni-Naehe: 1,6 m rundum (auch Rueckseite). Hearing wie 2D-Original
##   (Wellenfront + Occlusion + Latenz) + Sprint-Fusstapsen als kleines
##   Hinweissignal. Catch: kleine Drohne (magnitude 0.45 + Player 0.35).
## Mesh: Rig 1.05 / Offset (-1.8,-0.61,-0.05) spannt GLB-Body [0..0.99]
## ueber Kapsel [0..1.0] (Messung 2026-10-18: Live-Eval + GLB-JSON:
## authored X 1.2..2.2 / Y 0.53..1.47 / Z +-0.37).
## Tests: regression_droid_pivot, regression_m1_door (API bleibt).

enum Alert { IDLE, HEARD, SEEN }

const PATROL_SPEED := 3.5
const AGGRO_SPEED := 4.6
const SVAR_PATROL_MIN := 0.8
const SVAR_PATROL_MAX := 1.15
const SVAR_AGGRO_MIN := 0.95
const SVAR_AGGRO_MAX := 1.25
const SVAR_INT_MIN := 0.2
const SVAR_INT_MAX := 0.65

const VISION_RANGE := 9.0
const VISION_DOT := 0.8829
const VISION_DOT_WIDE := 0.5
const WIDE_F := 0.4
const OMNI_R := 1.6
const VISION_GAIN := 2.6
const VISION_COOL := 0.5
const HEAT_NOTICE := 0.4
const HEAT_SPOT := 1.0
const REMONITOR_INT := 1.2
const EYE_H := 0.55
const PLAYER_H := 1.0
const HEARD_GLOW := 0.35
const SPRINT_MOD := 1.5
const MOVE_MOD := 1.3

const HEAR_RANGE := 18.0
const SUS_GAIN := 12.0
const SUS_DECAY := 0.14
const SUS_TH := 0.12
const SUS_CANCEL := 0.07
const MIN_SIG := 0.01
const ORIGIN_W := 0.48
const WAVE_W := 0.72
const WAVE_SIGMA := 4.6
const OCCLUDE_DAMP := 0.88
const FOOT_SPRINT_R := 7.0
const FOOT_SPRINT_W := 0.09
const LAT_MIN := 0.06
const LAT_MAX := 0.2
const SEARCH_MIN := 0.1
const SEARCH_MAX := 0.26
const UNC_MAX := 1.5
const UNC_MIN := 0.25
const AGGRO_MIN := 1.7
const AGGRO_MAX := 3.0
const COOL_MIN := 0.14
const COOL_MAX := 0.48

const SEEN_DUR := 6.0
const SEARCH_DUR := 5.0
const SCAN_DUR := 1.8
const SCAN_ARC := 1.15
const SCAN_RATE := 1.6
const FACE_LERP_PATROL := 6.0
const FACE_LERP_ALERT := 10.0
const NAV_PUSH_INT := 0.25

const CATCH_DIST := 1.05
const CATCH_H := 1.4
const CATCH_GRACE := 1.2

const WP_TH := 0.6
const PAUSE_MIN := 0.12
const PAUSE_MAX := 0.45
const STRAFE_MAX := 0.3
const STRAFE_T_MIN := 0.15
const STRAFE_T_MAX := 0.35
const STUCK_TIME := 0.3

const FEELER_LEN := 2.0
const FEELER_ANGLE := 0.61
const FEELER_H := 0.55
const CLEAR_LEN := 4.0
const WP_TRIES := 8
const GROUND_DROP := 3.0
const GROUND_BAND := 1.5

const SFX_YELLOW: AudioStream = preload("res://assets/audio/EnemyAlertYellow.wav")
const SFX_RED: AudioStream = preload("res://assets/audio/EnemyAlertRed.wav")

## Patrol-Radius pro Droid (Blender-Vermessung 2026-09-24):
## offene Plaetze (L1 90 Prozent frei) 9 m, enge Slots (L2 Blockriegel) 4-5 m.
@export var roam_radius := 9.0
## Navmesh-Bake + NavigationAgent3D fuer HEARD/SEEN; sonst Stufe-1-Fallback.
@export var use_navmesh := false
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
var _heat := 0.0
var _hec_t := 0.0
var _scan_t := 0.0
var _scan_yaw := 0.0
var _nav_push_t := 0.0
var _last_p_pos := Vector3.ZERO
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
	_last_p_pos = _spawn
	_fix_rig_pivot()
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


func is_scanning() -> bool:
	return _scan_t > 0.0


## Rig-Pivot: GLB-Body-Vertexe authored um (X+1.7 | Y+1.0); das Rig-Mapping
## (Scale + Offset) hebt sie ueber den Koerper-Ursprung. Yaw laeuft auf dem
## achszentrierten Rig, Offset sitzt auf Kind "Model" -> Rotation pendelt
## nicht mehr auf einem Arm (Fix 2026-10-11, Verteilung bleibt aktiv).
func _fix_rig_pivot() -> void:
	if _rig.get_node_or_null("Model") != null:
		return
	var off: Transform3D = _rig.transform
	if off == Transform3D.IDENTITY:
		return
	var kids := _rig.get_children()
	for k in kids:
		_rig.remove_child(k)
	_rig.transform = Transform3D.IDENTITY
	var inner := Node3D.new()
	inner.name = "Model"
	inner.transform = off
	_rig.add_child(inner)
	for k in kids:
		inner.add_child(k)


func reset_droid() -> void:
	global_position = _spawn
	velocity = Vector3.ZERO
	alert = Alert.IDLE
	suspicion = 0.0
	_heat = 0.0
	_aggro_t = 0.0
	_pause_t = 0.2
	_has_target = false
	_pend = false
	_cool = 0.0
	_scan_t = 0.0
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
		_update_vision(player, delta)
		if alert == Alert.SEEN:
			_track_player(player, delta)
	_hearing(delta)
	if alert == Alert.SEEN:
		_aggro_t -= delta
		if _aggro_t <= 0.0:
			alert = Alert.HEARD
			_aggro_t = SEARCH_DUR * randf_range(0.85, 1.25)
			_target += Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
			_strafe_t = 0.0
			_push_nav_target()
	elif alert == Alert.HEARD:
		_aggro_t -= delta
		if _aggro_t <= 0.0:
			alert = Alert.IDLE
			_has_target = false
			_heat = minf(_heat, HEAT_NOTICE * 0.5)
	_catch_grace = maxf(0.0, _catch_grace - delta)
	_update_speed_var(delta)
	_update_move(delta)
	if player != null and alert == Alert.SEEN and _catch_grace <= 0.0:
		var d: Vector3 = player.global_position - global_position
		if Vector2(d.x, d.z).length() < CATCH_DIST and absf(d.y) < CATCH_H and _has_los(player):
			_caught(player)
	var disp := maxf(_heat, suspicion)
	if alert == Alert.SEEN:
		disp = 1.0
	elif alert == Alert.HEARD:
		disp = maxf(disp, HEARD_GLOW)
	suspicion = lerpf(suspicion, disp, 6.0 * delta)
	_update_anim()
	_update_eye()

## Vision mit Aufbau: rate = Kegel * Distanz * Bewegung; heat merkt sich.
func _update_vision(p: Node3D, delta: float) -> void:
	var rate := 0.0
	var to: Vector3 = p.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	var sprinting := false
	if p.has_method("is_sprinting"):
		sprinting = bool(p.call("is_sprinting"))
	# Bewegungsform (Positionsdelta zwischen Frames, Input-agnostisch).
	var moved := (p.global_position - _last_p_pos).length() > 0.03
	if dist <= OMNI_R:
		rate = 1.0
	elif dist <= VISION_RANGE:
		var cone_f := 0.0
		if dist > 0.05:
			var dn: float = facing.normalized().dot(to / dist)
			if dn >= VISION_DOT:
				cone_f = 1.0
			elif dn >= VISION_DOT_WIDE:
				cone_f = WIDE_F
		if cone_f > 0.0:
			var dist_f: float = clampf(1.0 - dist / VISION_RANGE * 0.8, 0.15, 1.0)
			var move_f := 1.0
			if sprinting:
				move_f = SPRINT_MOD
			elif moved:
				move_f = MOVE_MOD
			rate = cone_f * dist_f * move_f
	if rate > 0.0 and _see_line(p):
		_heat = clampf(_heat + rate * VISION_GAIN * delta, 0.0, HEAT_SPOT)
		if _heat >= HEAT_SPOT:
			if alert != Alert.SEEN:
				_spot_player(p)
		elif _heat >= HEAT_NOTICE and alert == Alert.HEARD:
			_hec_t -= delta
			if _hec_t <= 0.0:
				_notice_player(p)
	elif alert != Alert.SEEN:
		_heat = maxf(0.0, _heat - VISION_COOL * delta)
	_last_p_pos = p.global_position


## Reine Sichtlinie (ohne Kegel/Distanz, fuer Rate + Catch).
func _see_line(p: Node3D) -> bool:
	if not (p is CollisionObject3D):
		return false
	var from: Vector3 = global_position + Vector3(0.0, EYE_H, 0.0)
	var dst: Vector3 = p.global_position + Vector3(0.0, PLAYER_H, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, dst, 1, [get_rid(), (p as CollisionObject3D).get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (hit["collider"] as Node) == p


func _has_los(p: Node3D) -> bool:
	return _see_line(p)


func get_marker_height() -> float:
	return 1.5


## SEEN eingetreten: Jagd-Sting, Ziel = Live-Position, Timersatz.
func _spot_player(p: Node3D) -> void:
	alert = Alert.SEEN
	_aggro_t = SEEN_DUR * randf_range(0.9, 1.1)
	_heat = HEAT_SPOT
	_target = Vector3(p.global_position.x, _spawn.y, p.global_position.z)
	_has_target = true
	_pause_t = 0.0
	_strafe_t = 0.0
	_stuck_t = 0.0
	_scan_t = 0.0
	_svar_t = 0.0
	_pend = false
	_cool = 0.0
	_hec_t = REMONITOR_INT
	_sfx_alert.stream = SFX_RED
	_sfx_alert.play()
	_push_nav_target()


## HEARD (Notiz): Untersuchung auf verwaschene Position; Sting nur beim
## Uebergang von IDLE. Wird im Aufbau wiederholt (Ziel gedaempft neu gesenkt).
func _notice_player(p: Node3D) -> void:
	var was_idle := alert == Alert.IDLE
	alert = Alert.HEARD
	_aggro_t = lerpf(AGGRO_MIN, AGGRO_MAX, _heat) * randf_range(0.9, 1.15)
	var noise := lerpf(UNC_MAX, UNC_MIN, _heat)
	_target = Vector3(
		p.global_position.x + randf_range(-noise, noise),
		_spawn.y,
		p.global_position.z + randf_range(-noise, noise))
	_has_target = true
	_pause_t = 0.0
	_strafe_t = 0.0
	_stuck_t = 0.0
	_scan_t = 0.0
	_hec_t = REMONITOR_INT
	_pend = false
	_cool = randf_range(COOL_MIN, COOL_MAX)
	if was_idle:
		_sfx_alert.stream = SFX_YELLOW
		_sfx_alert.play()
	_push_nav_target()


## SEEN folgt live: Ziel gesetzt + NavPush gedrosselt.
func _track_player(p: Node3D, delta: float) -> void:
	_target = Vector3(p.global_position.x, _spawn.y, p.global_position.z)
	_has_target = true
	_scan_t = 0.0
	_nav_push_t -= delta
	if _nav_push_t <= 0.0:
		_nav_push_t = NAV_PUSH_INT
		_push_nav_target()


## Kompatibilitaets-API (Tests, 2D-Port): setzt alert direkt.
func _set_aggro(target: Vector3, dur: float, seen: bool) -> void:
	if seen:
		if alert != Alert.SEEN:
			_sfx_alert.stream = SFX_RED
			_sfx_alert.play()
		alert = Alert.SEEN
		_heat = HEAT_SPOT
	else:
		if alert == Alert.IDLE:
			_sfx_alert.stream = SFX_YELLOW
			_sfx_alert.play()
		alert = Alert.HEARD
	_aggro_t = dur * randf_range(0.85, 1.25)
	var t := Vector3(target.x, _spawn.y, target.z)
	if not seen and not _nav_usable():
		t = _clamp_target_to_los(t)
	_target = t
	_has_target = true
	_pause_t = 0.0
	_svar_t = 0.0
	_strafe_t = 0.0
	_stuck_t = 0.0
	_scan_t = 0.0
	_hec_t = REMONITOR_INT
	_pend = false
	_push_nav_target()


## HEARD-Ziel an freier Luftlinie klemmen (ohne Navmesh): kein Anrennen.
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
		"heat": snappedf(_heat, 0.001),
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
	# Wegpunkt-Validierung: Boden unter dem Punkt + Luftlinie frei.
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
	_dbg("alle Wegpunkte verworfen, sampling-resolve")
	_target = _sample_free_dir(3.0)
	_target.y = _spawn.y
	_has_target = true
	_pause_t = randf_range(PAUSE_MIN, PAUSE_MAX)
	_push_nav_target()


## Gueltig = Boden im Band +-GROUND_BAND + Luftlinie vom Bot frei.
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
	# Kopf-Scan am Punkt: stehen, langsame Bogendrehung, dann Relax.
	if _scan_t > 0.0:
		_scan_t -= delta
		_rig.rotation.y = _scan_yaw + sin((SCAN_DUR - _scan_t) * SCAN_RATE) * SCAN_ARC
		facing = Vector3(-sin(_rig.rotation.y), 0.0, -cos(_rig.rotation.y))
		velocity.x = move_toward(velocity.x, 0.0, PATROL_SPEED * delta)
		velocity.z = move_toward(velocity.z, 0.0, PATROL_SPEED * delta)
		move_and_slide()
		return
	if alert == Alert.IDLE and not _has_target:
		_pick_waypoint()
	if _pause_t > 0.0:
		_pause_t -= delta
		velocity.x = move_toward(velocity.x, 0.0, PATROL_SPEED * delta)
		velocity.z = move_toward(velocity.z, 0.0, PATROL_SPEED * delta)
		move_and_slide()
		if alert == Alert.HEARD and _cool <= 0.0:
			var tpos: Vector3 = _target - global_position
			tpos.y = 0.0
			if tpos.length() < WP_TH + 0.2:
				_start_scan()
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
		elif alert == Alert.HEARD and _cool <= 0.0:
			_start_scan()
		return
	var dir: Vector3 = to.normalized()
	# Stufe 2: Pfadposition statt Luftlinie (HEARD/SEEN), Patrol bleibt Waypoint.
	if _nav_active():
		if _nav_agent.is_navigation_finished():
			if alert != Alert.IDLE:
				_nav_agent.target_position = _target
		var next: Vector3 = _nav_agent.get_next_path_position()
		var nt: Vector3 = next - global_position
		nt.y = 0.0
		if nt.length() > 0.2:
			dir = nt.normalized()
			_dbg_nav_steps += 1
	dir = _steer_feelers(dir)
	if dir.length() < 0.01:
		velocity.x = move_toward(velocity.x, 0.0, PATROL_SPEED * delta)
		velocity.z = move_toward(velocity.z, 0.0, PATROL_SPEED * delta)
		move_and_slide()
		return
	# Anti-Glitch: test_move + Fuehler doppelbestaetigt (Tuerkanten-Margin).
	if test_move(global_transform, dir * 0.6) and _feeler_blocked(dir, 0.0, FEELER_LEN):
		_resolve_stuck(dir)
		return
	var base := PATROL_SPEED if alert == Alert.IDLE else AGGRO_SPEED
	var spd: float = base * _svar_mult
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	move_and_slide()
	facing = Vector3(dir.x, 0.0, dir.z)
	var fl := FACE_LERP_PATROL
	if alert != Alert.IDLE:
		fl = FACE_LERP_ALERT
	_rig.rotation.y = lerp_angle(_rig.rotation.y, atan2(-dir.x, -dir.z), fl * delta)
	if get_real_velocity().length() < 0.3:
		_stuck_t += delta
		if _stuck_t >= STUCK_TIME:
			_stuck_t = 0.0
			_resolve_stuck(dir)
	else:
		_stuck_t = 0.0


## Suchstand: stehen bleiben, langsame Bogendrehung um den Startwinkel.
func _start_scan() -> void:
	_scan_t = SCAN_DUR
	_scan_yaw = _rig.rotation.y
	velocity.x = 0.0
	velocity.z = 0.0


func _nav_usable() -> bool:
	return use_navmesh and _nav_agent != null


func _nav_active() -> bool:
	return _nav_usable() and alert != Alert.IDLE and _has_target


func _push_nav_target() -> void:
	if _nav_agent != null and _has_target:
		_nav_agent.target_position = _target


## 3 Kurze-Raycast Fuehler (vorn/links/rechts): freie Seite gewinnt.
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


## Freiraum in einer Richtung (0..CLEAR_LEN), entscheidet Ausweichseite.
func _clearance(dir: Vector3, angle: float) -> float:
	var d: Vector3 = dir.rotated(Vector3.UP, angle)
	var from: Vector3 = global_position + Vector3(0.0, FEELER_H, 0.0)
	var query := PhysicsRayQueryParameters3D.create(
		from, from + d * CLEAR_LEN, 1, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return CLEAR_LEN
	return from.distance_to(hit["position"] as Vector3)


## Stuck-Resolve: Richtungs-Sampling; Patrol bekommt Ersatz-Wegpunkt.
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
	# Fang-Regel: Menue zeigen (Game Over); Fallback = Respawn.
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


## Eye-/Beacon-Anzeige (2D-Original-Port): Mesh nach Alert-State,
## Glow nach Heat/Suspicion, SEEN pulsiert rot. Farben aus Blender.
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


## Hearing (2D-Port): Ping-Wellenfront + Occlusion-Fall,speed-translation:
## Naehere Quelle = staerker, Ring-Resonanz vom Ping-Radius, Wand daempft.
## Fussgeraeuche bei Sprint-Naehe als kleines Vorsignal (origin = Spieler).
func _hearing(delta: float) -> void:
	var sig := 0.0
	var ox := 0.0
	var oz := 0.0
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	# Fussgeraeuche: Sprint in Naehe = amortisiertes Vorsignal.
	if player != null and player.has_method("is_sprinting"):
		var sp: bool = bool(player.call("is_sprinting"))
		if sp:
			var fp: Vector3 = global_position - player.global_position
			fp.y = 0.0
			var fd := fp.length()
			if fd <= FOOT_SPRINT_R:
				var fs: float = FOOT_SPRINT_W * (1.0 - fd / FOOT_SPRINT_R)
				fs *= randf_range(0.9, 1.1)
				if fs > sig:
					sig = fs
					ox = player.global_position.x
					oz = player.global_position.z
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
	_suspicion_hearing_accumulate(delta, sig, ox, oz)


## Suspicion-Akkumulator aus Hearing (Kernloop des 2D-Ports: Latenz +
## Suchverzoegerung mit minimalem Chatter) - Ergebnis ist pend mit Ziel.
var _hearing_accum := 0.0


func _suspicion_hearing_accumulate(delta: float, sig: float, ox: float, oz: float) -> void:
	# Anzeige-Anteil: _hearing akumuliert nur, wenn nicht schon SEEN jagd.
	_hearing_accum = clampf(_hearing_accum + sig * SUS_GAIN * delta - SUS_DECAY * delta, 0.0, 1.0)
	if alert != Alert.IDLE:
		return
	if _pend and _hearing_accum < SUS_CANCEL:
		_pend = false
		return
	if not _pend and _cool <= 0.0 and sig >= MIN_SIG and _hearing_accum >= SUS_TH:
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
	notice_heard_target(_pend_ox, _pend_oz, unc, dur)
	_pend = false


## HEARD-Ausgang aus Hearing: Ziel = Pseudo-Position mit Unschaerfe.
func notice_heard_target(ox: float, oz: float, unc: float, dur: float) -> void:
	# Anzeige-Suspicion auf den Hearing-Anteil bringen (kein Doppelfluss).
	var old_heard := alert == Alert.HEARD
	alert = Alert.HEARD
	_aggro_t = dur * randf_range(0.85, 1.25)
	var t := Vector3(ox + randf_range(-unc, unc), _spawn.y, oz + randf_range(-unc, unc))
	if not _nav_usable():
		t = _clamp_target_to_los(t)
	_target = t
	_has_target = true
	_pause_t = 0.0
	_strafe_t = 0.0
	_stuck_t = 0.0
	_scan_t = 0.0
	_cool = randf_range(COOL_MIN, COOL_MAX)
	_hec_t = REMONITOR_INT
	if not old_heard:
		_sfx_alert.stream = SFX_YELLOW
		_sfx_alert.play()
	_push_nav_target()
