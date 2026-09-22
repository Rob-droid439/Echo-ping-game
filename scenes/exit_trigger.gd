extends Area3D
## Exit-Trigger fuer Echo Cartographer 3D.
## Wird in level_1.tscn / level_2.tscn an der Tunnelmuendung platziert.
## Der Spieler-Character muss in der Gruppe "player" sein
## (im Player-Skript oder in der Player-Szene: Add to Group).

@export_file("*.tscn") var target_scene: String = ""


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if target_scene.is_empty():
		return
	if body.is_in_group("player"):
		# Deferred: direkt im Physics-Callback crasht der Szenenwechsel.
		get_tree().call_deferred("change_scene_to_file", target_scene)
