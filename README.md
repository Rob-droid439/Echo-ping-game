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

Port des Java-2D-Originals (`IT Projekt RobertSchmauz Cratgograph`):
Sonar-Ping als Kernmechanik, Droiden als Gegner, Powerups als Progression.
Stand: lauffähiger Gameplay-Prototyp, kein Content-Lock.

## Gameplay

- 3rd-person controller (D-Rig: `D_Anim_Idle` / `D_Anim_Walk` / `D_Anim_PingCast`) + SpringArm camera.
- Sonar-ping (`E`): expanding double-ring + light flash, base radius 25 m, base expand speed 15.625 m/s (~1.6 s), cooldown 1.33 s.
  - Reveal through walls (X-ray): everything in group `echo_receiver` hit by the wavefront gets a `PingMarker` + `E_Anim_Alert` + HUD contact.
  - Droids hear the ping (see AI below) via group `active_ping` + `get_radius()`.
- Ping powerups (port from 2D/Java `PowerUp.java` + `PingManager`): green diamonds, max 7 stacks run-wide (`run_state.gd`, survives scene change), each +7.5 % radius / +15 % speed. HUD shows `PING +n/7`.
  - Level 1: 3 pickups, Level 2: 3 pickups.
- Droid AI (port from Java `EnemyAI` + `HearingModel` + `Enemy`, `scenes/droid_ai.gd` / `e_droid.tscn`):
  - Patrol: random waypoints in per-droid roam radius (`@export roam_radius`: L1 9 m open plaza, L2-A 4 m / L2-B 5 m tight slots) + pause, speed 3.5 m/s with variance.
  - Waypoint validation (no navmesh, stage 1): ground ray below + free line-of-sight from bot, else re-roll (max 8 tries, then direction sampling). Rejects counted in debug stats.
  - Wall feelers: 3 short raycasts (front/left/right, 2 m) steer the heading away instead of frontal wall-sliding; dead ends trigger sampling resolve.
  - Stuck-resolve with direction sampling (3 candidates, freest wins) instead of fixed sidestep; `test_move` guard before moves (anti wall-clip); `STUCK_TIME` 0.3 s kept.
  - Hearing: ping suspicion with latency (0.06–0.2 s), falloff², wavefront gaussian, 0.88 occlude damping, threshold 0.12 → `HEARD` with position uncertainty (1.5 m → 0.25 m by signal strength). `HEARD` targets are clamped to last free position before walls (no charging at walls that hid the ping).
  - Vision: 28° cone (`DOT 0.8829`), 9 m range, line-of-sight raycast → `SEEN` exact.
  - Chase: `SEEN` exact / `HEARD` clamped with scatter, strafe jitter, sampling stuck-resolve.
  - Catch-reset (prototype rule): touch in `SEEN` (<1.6 m + LOS + |dy| < 2 m, 1.2 s spawn grace) shows game-over menu, fallback respawn headless.
  - Debug metrics: `get_debug_stats()` → stucks / waypoint_rejects / feeler_turns (`@export debug_log` prints resolves).
  - Navmesh (stage 2, active): `NavigationRegion3D` per level with headless-baked mesh (`assets/nav/L1_navmesh.tres` 365 polys from 286 `-col` bodies, `L2_navmesh.tres` 434 polys from 145; `tools/bake_navmesh.gd`, agent H 2.4 / R 0.6 / climb 0.3). `NavigationAgent3D` child (r 0.5 / h 2.4) drives CHASE/HEARD via `get_next_path_position()` (`use_navmesh = true` on all droids); patrol stays waypoint (`nav_steps` metric proves the split). Fallback = stage-1 behavior. Agent workflow rules: `claude.md`.
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

## Collision (Blender → Godot)

Naming in Blender drives the glTF import, no manual work in Godot:

- `*-col` on meshes → concave/trimesh static bodies (walls, terrain, borders).
- `*-colonly` on proxy boxes → invisible colliders (bollards, barrels, wrecks,
  curbs etc.). Empty `-col` nodes do **not** survive glTF export (Blender writes
  no display type) — hence mesh proxies.
- No suffix = no collision (deco, lights, sensors).

Export from `Cartograph 3D.blend` (selection per level collection, minus
`L1_Volume` fog helper which must stay out) to `assets/maps/EchoCart_L1.glb` /
`EchoCart_L2.glb`. L1 buildings walkable (hollow ground floor), L2 buildings
backdrop (2 m slabs), ruins walkable.
Layout pass 2026-09-24 (Blender-measured): L1 spawn→M1 corridor cleared —
`BrokenSlab_0` cluster (24,-19)→(24,-23.5), `DebrisPile_0` (20,-20)→(18,-25),
visual+`-colonly` proxy moved together (location offset, still aligned).
L1 doors kept as deliberate chokepoints (M1 1.6 m / S1 1.9 m free, lintels
2.6–2.7 m ≥ bot top 2.4 m); L2 needs no moves (0.19 m lamp poles are
feeler-handled). Spawn distances already safe (L1 36 m, L2 25 m, rule ≥12 m);
tight L2 slots fixed via small roam radii instead of moving spawns.

## Run / verify

- Godot 4.7, Forward Plus, Jolt Physics, D3D12, MSAA 3D 2x. Open folder in editor and press Play (main scene L1).
- Headless AI check:
  `Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tools/verify_stufe1.gd`
  expects 12× `PASS` + `RESULT: OK` (`patrol bewegt`, `stuck-resolves ≤ 3`,
  `patrol ohne Navmesh`, `roam_radius` per droid, `hearing`, `chase nutzt
  Navmesh-Pfad`, `vision SEEN`, `catch mit LOS`, `l2 patrol`,
  `l2 hearing`, `l2 chase nutzt Navmesh`). Prints patrol metrics
  (stucks/rejects/feeler_turns/nav_steps) per level.
  (Legacy `tools/verify_droid.gd` with 9× `PASS` superseded.)

## Development

- Git with LFS (`*.glb`, `*.hdr`, `*.png`, `*.jpg`). `.godot/` and `tools/` ignored.
- Parallel-work rule: don't save editor scenes while the agent touches files
  (editor state would overwrite disk) — reconcile via commits instead.
- `addons/godot_mcp` installed (editor ↔ AI bridge; wiring open).

## Known prototype limits

- Navmesh baked (stage 2): CHASE/HEARD pathfind around walls and through
  1.6 m doors; patrol stays waypoint-based by design. Stairs/upper floors
  are in the mesh — chase up steps can grind (stuck-resolve catches it).
  Catch = menu + respawn rules, no full game-over flow, no audio.
- Catch = respawn, no game over, no menu, no audio.
- L2 buildings have no interiors.

Tech:
------------
Visual design: Blender 5.2
GameEngine: Godot 4.7
