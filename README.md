# Echo-ping-game — 3D Cartograph Game

Description:
------------
3D Cyberpunk-esque future dystopia third person game,
where the no-named protagonist has to escape his city,
which has been taken over by AI.
Whilst trying to exit the city, he also has to avoid and escape the evil robot droids, that try to chase him.
Since he was a future-robot-mechanic (obviously), he has an echogun, which sends out ping waves that allow him to detect the droids to help his exit.

So, your standard dystopian social media-terminator cliché in which there is an AI that destroys humanity,
packaged in a game with many levels and great graphics.

## Gameplay

- 3rd-person controller (D-Rig: `D_Anim_Idle` / `D_Anim_Walk` / `D_Anim_PingCast`) + SpringArm camera.
- Sonar-ping (`E`): expanding double-ring + light flash, base radius 25 m, base expand speed 15.625 m/s (~1.6 s), cooldown 1.33 s.
  - Reveal through walls (X-ray): everything in group `echo_receiver` hit by the wavefront gets a `PingMarker` + `E_Anim_Alert` + HUD contact.
  - Droids hear the ping (see AI below) via group `active_ping` + `get_radius()`.
- Ping powerups (port from 2D/Java `PowerUp.java` + `PingManager`): green diamonds, max 7 stacks run-wide (`run_state.gd`, survives scene change), each +7.5 % radius / +15 % speed. HUD shows `PING +n/7`.
  - Level 1: 3 pickups, Level 2: 3 pickups.
- Droid AI (port from Java `EnemyAI` + `HearingModel` + `Enemy`, `scenes/droid_ai.gd` / `e_droid.tscn`):
  - Patrol: random waypoints in 9 m roam radius + pause, speed 3.5 m/s with variance.
  - Hearing: ping suspicion with latency (0.06–0.2 s), falloff², wavefront gaussian, 0.88 occlude damping, threshold 0.12 → `HEARD` with position uncertainty (1.5 m → 0.25 m by signal strength).
  - Vision: 28° cone (`DOT 0.8829`), 9 m range, line-of-sight raycast → `SEEN` exact.
  - Chase: `SEEN` exact / `HEARD` with scatter, strafe jitter, stuck-resolve.
  - Catch-reset (prototype rule): touch in `SEEN` (<1.2 m) respawns player at spawn + resets all droids.
  - Level 1: 1 droid, Level 2: 2 droids (`E_Droid_A/B`), all in `echo_receiver`.
- Exit: `Area3D` at tunnel mouth → `change_scene_to_file` (L1 → L2).
- HUD (`sonar_hud.tscn`): `SONAR [E]` cooldown bar, `KONTAKTE: n`, `PING +n/7`.

## Controls

- `WASD`: move camera-relative
- Mouse: look (captured, `ESC` releases, click re-captures)
- `Space`: jump
- `E`: sonar ping

## Project layout

- `scenes/level_1.tscn`, `level_2.tscn` — main scenes (`run/main_scene = level_1`)
- `scenes/player.tscn` / `player.gd` — protagonist, group `player`, `respawn()`
- `scenes/sonar_ping.tscn` / `sonar_ping.gd` — ping, groups `active_ping`, `echo_receiver` scan
- `scenes/e_droid.tscn` / `droid_ai.gd` — droid, group `echo_receiver`
- `scenes/ping_powerup.tscn` / `ping_powerup.gd`, `run_state.gd` — powerup stacks
- `scenes/sonar_hud.tscn`, `ping_marker.gd`, `exit_trigger.gd`, `night_env.tres`
- `assets/maps/`: `EchoCart_L1.glb`, `EchoCart_L2.glb`, `D_Protagonist.glb`, `E_Droid.glb`, `FX_SonarPing_Ring.glb`
- `assets/sky/echo_night.hdr` — night env
- `tools/` — git-ignored headless verifiers (`verify_droid.gd`: patrol/hearing/vision/catch/L2)

## Run / verify

- Godot 4.7, Forward Plus, Jolt Physics, D3D12, MSAA 3D 2x. Open folder in editor and press Play (main scene L1).
- Headless AI check:
  `Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tools/verify_droid.gd`
  expects 8× `PASS` (`patrol bewegt/idle-alert/anim`, `hearing HEARD`, `vision SEEN`, `catch respawn/reset`, `l2 patrol`).

Tech:
------------
Visual design: Blender 5.2
GameEngine: Godot 4.7
