extends Area3D
## Exit-Trigger fuer Echo Cartographer 3D.
## Wird in level_1.tscn / level_2.tscn an der Tunnelmuendung platziert.
## Der Spieler-Character muss in der Gruppe "player" sein
## (im Player-Skript oder in der Player-Szene: Add to Group).

@export_file("*.tscn") var target_scene: String = ""

const SFXH := preload("res://scenes/sfx.gd")
const SFX_EXIT: AudioStream = preload("res://assets/audio/LevelTransition.wav")


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if target_scene.is_empty():
		# Level 2 hat kein Folge-Level: Victory-Menü statt nichts.
		var menu: Node = get_tree().get_first_node_in_group("victory")
		if menu != null and menu.has_method("show_victory"):
			menu.show_victory()
		return
	# One-Shot am Root: überlebt den Szenenwechsel (Victory-Pfad spielt
	# stattdessen GameWon uebers Menü — kein Doppel-Sound).
	SFXH.play(get_tree(), SFX_EXIT, true)
	# Deferred: direkt im Physics-Callback crasht der Szenenwechsel.
	get_tree().call_deferred("change_scene_to_file", target_scene)
