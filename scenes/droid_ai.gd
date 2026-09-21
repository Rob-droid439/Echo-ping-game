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
const ROAM_RADIUS := 9.0
const WP_TH := 0.6
const PAUSE_MIN := 0.12
const PAUSE_MAX := 0.45
const STRAFE_MAX := 0.5
const STRAFE_T_MIN := 0.08
const STRAFE_T_MAX := 0.24
const STUCK_TIME := 0.1
const CATCH_DIST := 1.2

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

@onready var _rig: Node3D = $Rig


func _ready() -> void:
	add_to_group("echo_receiver")
	_spawn = global_position
	_ap = _rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for a in ["E_Anim_Patrol", "E_Anim_Idle", "E_Anim_Alert"]:
		if _ap.has_animation(a):
			_ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_ap.play("E_Anim_Patrol")


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
	_update_speed_var(delta)
	_update_move(delta)
	if player != null and alert == Alert.SEEN:
		var d: Vector3 = player.global_position - global_position
		if Vector2(d.x, d.z).length() < CATCH_DIST:
			_caught(player)
	_update_anim()


func _see_player(p: Node3D) -> bool:
	var to: Vector3 = p.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if dist > VISION_RANGE:
		return false
	if dist > 0.05 and facing.normalized().dot(to.normalized()) < VISION_DOT:
		return false
	var from: Vector3 = global_position + Vector3(0.0, 0.5, 0.0)
	var dst: Vector3 = p.global_position + Vector3(0.0, 1.0, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, dst, 1, [get_rid(), (p as CollisionObject3D).get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (hit["collider"] as Node) == p


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
		var q := PhysicsRayQueryParameters3D.create(
			global_position + Vector3(0.0, 0.5, 0.0), po + Vector3(0.0, 0.5, 0.0), 1, [get_rid()])
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
	alert = Alert.SEEN if seen else Alert.HEARD
	_aggro_t = dur * randf_range(0.85, 1.25)
	_target = Vector3(target.x, _spawn.y, target.z)
	_has_target = true
	_pause_t = 0.0
	_svar_t = 0.0
	_strafe_t = 0.0
	_stuck_t = 0.0


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
	_target = _spawn + Vector3(randf_range(-ROAM_RADIUS, ROAM_RADIUS), 0.0, randf_range(-ROAM_RADIUS, ROAM_RADIUS))
	_target.y = _spawn.y
	_has_target = true
	_pause_t = randf_range(PAUSE_MIN, PAUSE_MAX)


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
			if alert == Alert.IDLE:
				_pick_waypoint()
			else:
				_target = global_position + Vector3(-dir.z, 0.0, dir.x) * 2.0
	else:
		_stuck_t = 0.0


func _caught(player: Node3D) -> void:
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
