extends CharacterBody3D
## Minimaler First-Person-Test-Player fuer Echo Cartographer 3D.
## WASD laufen, Leertaste springen, E = Sonar-Ping, Mausklick = Maus einfangen, ESC = freigeben.
## Traegt sich in die Gruppe "player" ein (fuer exit_trigger.gd).

@export var speed: float = 5.0
@export var accel: float = 20.0
@export var jump_velocity: float = 4.5
@export var mouse_sens: float = 0.0025
@export var ping_cooldown: float = 4.0 / 3.0

const PING_SCENE: PackedScene = preload("res://scenes/sonar_ping.tscn")
const RS: GDScript = preload("res://scenes/run_state.gd")
const BASE_PING_RMAX: float = 25.0
const BASE_PING_SPEED: float = 15.625

@onready var cam: Camera3D = $Camera3D
var _pitch: float = 0.0
var _ping_left: float = 0.0


func _ready() -> void:
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sens)
		_pitch = clampf(_pitch - event.relative.y * mouse_sens, -1.4, 1.4)
		cam.rotation.x = _pitch
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			try_ping()


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
	ping.global_position = global_position + Vector3(0.0, 0.15, 0.0)
	_ping_left = ping_cooldown
	return true


func get_ping_cooldown_frac() -> float:
	return clampf(1.0 - _ping_left / ping_cooldown, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	_ping_left = maxf(0.0, _ping_left - delta)
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
	var dir: Vector3 = global_transform.basis * Vector3(iv.x, 0.0, iv.y)
	velocity.x = move_toward(velocity.x, dir.x * speed, accel * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, accel * delta)
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	elif Input.is_physical_key_pressed(KEY_SPACE):
		velocity.y = jump_velocity
	move_and_slide()
