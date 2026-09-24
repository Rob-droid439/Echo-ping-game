extends CharacterBody3D
## Third-Person-Protagonist fuer Echo Cartographer 3D.
## D-Rig (Idle/Walk/PingCast) + SpringArm-Kamera. WASD kamerarelativ,
## Leertaste springen, E = Sonar-Ping (mit Wurf-Animation).
## Gruppe "player" (Exit-Trigger, HUD, Pickups).

@export var speed: float = 5.0
@export var accel: float = 20.0
@export var jump_velocity: float = 4.5
@export var mouse_sens: float = 0.0025
@export var turn_speed: float = 10.0
@export var rig_yaw_offset: float = 0.0
@export var cam_arm_length: float = 3.0
@export var cam_head_fade_dist: float = 0.7
@export var ping_cooldown: float = 4.0 / 3.0
@export var cam_pitch_min: float = -1.2
@export var cam_pitch_max: float = 0.25

const PING_SCENE: PackedScene = preload("res://scenes/sonar_ping.tscn")
const RS: GDScript = preload("res://scenes/run_state.gd")
const BASE_PING_RMAX: float = 25.0
const BASE_PING_SPEED: float = 15.625
const SFX_PING: AudioStream = preload("res://assets/audio/Ping.wav")
const SFX_DENIED: AudioStream = preload("res://assets/audio/PingNotReady.wav")

@onready var _rig: Node3D = $Rig
@onready var _arm: SpringArm3D = $CamArm
@onready var _cam: Camera3D = $CamArm/Camera3D
var _ap: AnimationPlayer
var _sfx_ping: AudioStreamPlayer
var _sfx_denied: AudioStreamPlayer
var _pitch: float = -0.18
var _ping_left: float = 0.0
var _ping_anim: float = 0.0
var _spawn_pos := Vector3.ZERO
var _spawn_yaw := 0.0
var _excluded: Array = []


func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_spawn_pos = global_position
	_spawn_yaw = rotation.y
	rotation.x = 0.0
	rotation.z = 0.0
	# Stabile Third-Person-Kamera: eigene Kapsel + Droiden ignorieren (sonst snappt
	# der Arm auf ~0 und poppt raus), nur Welt (Mask 1), Shape=Sphere aus tscn.
	_arm.collision_mask = 1
	_arm.add_excluded_object(get_rid())
	_excluded.append(get_rid())
	_exclude_actors()
	call_deferred("_exclude_actors")
	_arm.rotation = Vector3(_pitch, 0.0, 0.0)
	_ap = _rig.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for a in ["D_Anim_Idle", "D_Anim_Walk"]:
		if _ap.has_animation(a):
			_ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_ap.play("D_Anim_Idle")
	_arm.spring_length = cam_arm_length
	_arm.rotation.x = _pitch
	_sfx_ping = AudioStreamPlayer.new()
	_sfx_ping.stream = SFX_PING
	add_child(_sfx_ping)
	_sfx_denied = AudioStreamPlayer.new()
	_sfx_denied.stream = SFX_DENIED
	add_child(_sfx_denied)


func _exclude_actors() -> void:
	# SpringArm soll nur an der Welt (Layer 1 Statics) kuerzen, nicht an
	# Droiden-CharacterBodies (Gruppe echo_receiver) – sonst Zoom-Popping,
	# sobald ein Droid hinter dem Spieler durchlaeuft. Spieler selbst auch.
	if _arm == null or get_tree() == null:
		return
	for n in get_tree().get_nodes_in_group("echo_receiver"):
		if n is CollisionObject3D:
			var rid: RID = (n as CollisionObject3D).get_rid()
			if not _excluded.has(rid):
				_arm.add_excluded_object(rid)
				_excluded.append(rid)


func respawn() -> void:
	global_position = _spawn_pos
	rotation = Vector3(0.0, _spawn_yaw, 0.0)
	velocity = Vector3.ZERO
	_ping_left = 0.0
	_ping_anim = 0.0
	_pitch = -0.18
	_arm.rotation = Vector3(_pitch, 0.0, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sens)
		rotation.x = 0.0
		rotation.z = 0.0
		_pitch = clampf(_pitch - event.relative.y * mouse_sens, cam_pitch_min, cam_pitch_max)
		_arm.rotation = Vector3(_pitch, 0.0, 0.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			cast_ping()


func cast_ping() -> bool:
	if not try_ping():
		_sfx_denied.play()
		return false
	_sfx_ping.play()
	if _ap.has_animation("D_Anim_PingCast"):
		_ap.play("D_Anim_PingCast", 0.1)
		_ping_anim = _ap.get_animation("D_Anim_PingCast").length
	return true


func try_ping() -> bool:
	if _ping_left > 0.0:
		return false
	var ping: Node3D = PING_SCENE.instantiate()
	var rs = RS.inst(get_tree())
	ping.set("rmax", BASE_PING_RMAX * rs.radius_mult())
	ping.set("expand_speed", BASE_PING_SPEED * rs.speed_mult())
	var host: Node = get_tree().current_scene
	if host == null:
		host = get_parent()
	host.add_child(ping)
	ping.global_position = global_position + Vector3(0.0, 1.0, 0.0)
	_ping_left = ping_cooldown
	return true


func get_ping_cooldown_frac() -> float:
	return clampf(1.0 - _ping_left / ping_cooldown, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	_exclude_actors()
	_ping_left = maxf(0.0, _ping_left - delta)
	_ping_anim = maxf(0.0, _ping_anim - delta)
	var iv := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		iv.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		iv.y += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		iv.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		iv.x += 1.0
	if iv.length() > 1.0:
		iv = iv.normalized()
	# Kamerarelativ auf Boden projiziert: nur Yaw zahlt, kein Pitch-Rest.
	var yaw_basis: Basis = Basis(Vector3.UP, rotation.y)
	var dir: Vector3 = yaw_basis * Vector3(iv.x, 0.0, iv.y)
	if dir.length() > 0.001:
		dir = dir.normalized()
	velocity.x = move_toward(velocity.x, dir.x * speed, accel * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, accel * delta)
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	elif Input.is_physical_key_pressed(KEY_SPACE):
		velocity.y = jump_velocity
	else:
		velocity.y = minf(velocity.y, 0.0)
	move_and_slide()
	# Kamera: Arm ein-/ausfahren lassen, bei Wandnaehe Kopf ausblenden
	# statt Kamera in den Schaedel zu fahren (First-Person-Fallback).
	if _arm != null and _rig != null:
		_rig.visible = _arm.get_hit_length() > cam_head_fade_dist
	# Upright-Lock: verhindert schleichendes Verkippen -> inkonsistente Cam.
	rotation.x = 0.0
	rotation.z = 0.0
	_update_anim(delta)


func _update_anim(delta: float) -> void:
	if _ping_anim > 0.0:
		return
	if not is_on_floor():
		return
	var planar := Vector2(velocity.x, velocity.z).length()
	var want := &"D_Anim_Walk" if planar > 0.5 else &"D_Anim_Idle"
	if _ap.current_animation != want:
		_ap.play(want, 0.15)
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() > 0.5:
		# Rig ist Kind des Bodies: Welt-Yaw in Body-lokal umrechnen.
		# Sonst steht das Mesh bei gedrehter Kamera (Body-Yaw != 0) schief.
		var target_world := atan2(-flat.x, -flat.z) + rig_yaw_offset
		_rig.rotation.y = lerp_angle(_rig.rotation.y, target_world - rotation.y, turn_speed * delta)
