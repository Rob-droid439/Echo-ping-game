extends CanvasLayer
## Game-Over-Menü: erscheint, sobald ein Droid den Spieler kriegt
## (siehe droid_ai._caught -> play_catch_animation).
## Pausiert den Tree, gibt die Maus frei. "Nochmal" = Quick-Respawn im
## aktuellen Stand, "Level neu laden" = reload_current_scene.

@onready var _retry: Button = $Center/Panel/Margin/VBox/Retry
@onready var _reload: Button = $Center/Panel/Margin/VBox/Reload


func _ready() -> void:
	add_to_group("game_over")
	visible = false
	_retry.pressed.connect(_on_retry)
	_reload.pressed.connect(_on_reload)


func play_catch_animation() -> void:
	# TODO: Fang-Sequenz (z.B. Droid zoomt heran / Screen-Flash),
	# danach show_game_over() aufrufen. Bis dahin direkt Menü.
	show_game_over()


func show_game_over() -> void:
	if visible:
		return
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_retry.grab_focus()


func _on_retry() -> void:
	_restart_quick()


func _on_reload() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().reload_current_scene()


func _restart_quick() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("respawn"):
		player.respawn()
	for d in get_tree().get_nodes_in_group("echo_receiver"):
		if d.has_method("reset_droid"):
			d.reset_droid()
	var hud: Node = get_tree().get_first_node_in_group("sonar_hud")
	if hud != null and hud.has_method("reset_contacts"):
		hud.reset_contacts()
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
