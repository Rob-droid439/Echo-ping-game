extends CanvasLayer
## Victory-Menü: erscheint am Exit von Level 2 (ExitTrigger ohne
## target_scene -> show_victory). Zeigt Run-Stats (Zeit, Kontakte,
## Ping-Powerups). "Nochmal spielen" startet den Run neu in Level 1,
## "Level 2 wiederholen" lädt die aktuelle Szene neu.
## Look via menu_style.gd (geteilt mit Game-Over-Menü).

const MS := preload("res://scenes/menu_style.gd")
const RS := preload("res://scenes/run_state.gd")
const SFX_WON: AudioStream = preload("res://assets/audio/GameWon.wav")

var _sfx: AudioStreamPlayer

@onready var _panel: PanelContainer = $Center/Panel
@onready var _title: Label = $Center/Panel/Margin/VBox/Title
@onready var _sub: Label = $Center/Panel/Margin/VBox/Sub
@onready var _stats: Label = $Center/Panel/Margin/VBox/Stats
@onready var _restart: Button = $Center/Panel/Margin/VBox/Restart
@onready var _replay: Button = $Center/Panel/Margin/VBox/Replay


func _ready() -> void:
	add_to_group("victory")
	visible = false
	MS.apply_panel(_panel)
	MS.style_title(_title, MS.CYAN, 46)
	MS.style_text(_sub, 18)
	MS.style_text(_stats, 16)
	MS.style_button(_restart, true)
	MS.style_button(_replay, false)
	_restart.pressed.connect(_on_restart)
	_replay.pressed.connect(_on_replay)
	_sfx = AudioStreamPlayer.new()
	_sfx.stream = SFX_WON
	add_child(_sfx)


func show_victory() -> void:
	if visible:
		return
	_sfx.play()
	var secs := 0
	var powers := 0
	var rs = RS.inst(get_tree())
	if rs != null:
		secs = int(rs.run_seconds())
		powers = int(rs.get("ping_powerups"))
	var contacts := 0
	var hud: Node = get_tree().get_first_node_in_group("sonar_hud")
	if hud != null:
		contacts = int(hud.get("contacts"))
	_stats.text = "Zeit: %d:%02d   •   Kontakte: %d   •   Ping +%d/7" % [secs / 60, secs % 60, contacts, powers]
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_restart.grab_focus()


func _on_restart() -> void:
	var rs = RS.inst(get_tree())
	if rs != null and rs.has_method("reset_run"):
		rs.reset_run()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().change_scene_to_file("res://scenes/level_1.tscn")


func _on_replay() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().reload_current_scene()
