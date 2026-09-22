extends CanvasLayer
## Mini-HUD: Sonar-Cooldown + aufgedeckte Kontakte + Ping-Powerup-Stapel.

const RS := preload("res://scenes/run_state.gd")

var contacts: int = 0
var _rs = null

@onready var _bar: ProgressBar = $Top/Cooldown
@onready var _lab: Label = $Top/Contacts
@onready var _pow: Label = $Top/Power


func _ready() -> void:
	add_to_group("sonar_hud")


func _process(_delta: float) -> void:
	if _rs == null or not is_instance_valid(_rs):
		_rs = RS.inst(get_tree())
	var p: Node = get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("get_ping_cooldown_frac"):
		_bar.value = float(p.get_ping_cooldown_frac()) * 100.0
	if _rs != null:
		_pow.text = "PING +%d/7" % int(_rs.get("ping_powerups"))


func add_contact() -> void:
	contacts += 1
	_lab.text = "KONTAKTE: %d" % contacts


func reset_contacts() -> void:
	contacts = 0
	_lab.text = "KONTAKTE: 0"
