extends Node
## Globaler Run-State: Ping-Powerup-Stapel, lebt leveluebergreifend als
## Root-Kind (ueberlebt change_scene_to_file wie ein Autoload, braucht aber
## keinen [autoload]-Eintrag). Pfadbasiert via preload nutzbar, daher auch
## in Headless--s-Runs verifizierbar.
## Port aus dem Java-Original (PingManager): max 7 Stapel,
## je +7.5 % Ping-Radius und +15 % Expansions-Speed.

const MAX_PING_POWERUPS: int = 7
const RADIUS_PER_POWERUP: float = 0.075
const SPEED_PER_POWERUP: float = 0.15

var ping_powerups: int = 0


static func inst(tree: SceneTree):
	var rs: Node = tree.root.get_node_or_null("RunState")
	if rs == null:
		rs = (load("res://scenes/run_state.gd") as GDScript).new()
		rs.name = "RunState"
		tree.root.add_child(rs)
	return rs


func add_powerup() -> bool:
	if ping_powerups >= MAX_PING_POWERUPS:
		return false
	ping_powerups += 1
	return true


func radius_mult() -> float:
	return 1.0 + RADIUS_PER_POWERUP * ping_powerups


func speed_mult() -> float:
	return 1.0 + SPEED_PER_POWERUP * ping_powerups


func reset_run() -> void:
	ping_powerups = 0
