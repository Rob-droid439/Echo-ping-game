extends CanvasLayer
## Mini-HUD: Sonar-Cooldown + aufgedeckte Kontakte.

var contacts: int = 0

@onready var _bar: ProgressBar = $Top/Cooldown
@onready var _lab: Label = $Top/Contacts


func _ready() -> void:
	add_to_group("sonar_hud")


func _process(_delta: float) -> void:
	var p: Node = get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("get_ping_cooldown_frac"):
		_bar.value = float(p.get_ping_cooldown_frac()) * 100.0


func add_contact() -> void:
	contacts += 1
	_lab.text = "KONTAKTE: %d" % contacts
