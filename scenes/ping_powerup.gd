extends Area3D
## Ping-Powerup (Port aus dem Java-Original, PowerUp.java + PingManager):
## Einsammeln = +1 Stapel (max 7 global, je +7.5 % Radius / +15 % Speed),
## danach verschwindet das Pickup. Schwebt und rotiert als Signal.

const RS := preload("res://scenes/run_state.gd")
const SFXH := preload("res://scenes/sfx.gd")
const SFX_PICKUP: AudioStream = preload("res://assets/audio/Ping_Powerup_Pickup.wav")

var _t: float = 0.0

@onready var _mesh: MeshInstance3D = $Diamond


func _ready() -> void:
	add_to_group("ping_pickup")
	body_entered.connect(_collect)
	_t = randf() * TAU


func _process(delta: float) -> void:
	_t += delta
	rotate_y(delta * 1.5)
	_mesh.position.y = 0.9 + sin(_t * 2.5) * 0.15


func _collect(body: Node3D) -> void:
	if body.is_in_group("player"):
		var rs = RS.inst(get_tree())
		rs.add_powerup()
		# One-Shot an der Szene: Pickup ist nach queue_free() schon weg.
		SFXH.play(get_tree(), SFX_PICKUP)
		queue_free()
