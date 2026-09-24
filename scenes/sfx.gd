class_name SFX
extends Node
## Minimaler One-Shot-Helfer fuer SFX an kurzlebigen Nodes (Pickup, Exit):
## Player an die Szene hängen, nach `finished` automatisch freigeben.
## `at_root = true` überlebt den Szenenwechsel (LevelTransition).


static func play(tree: SceneTree, stream: AudioStream, at_root := false) -> void:
	if tree == null or stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.finished.connect(p.queue_free)
	if at_root or tree.current_scene == null:
		tree.root.add_child(p)
	else:
		tree.current_scene.add_child(p)
	p.play()
