Context for agents:
----
Architecture:
- Remake: Das Spiel existiert bereits als fertiges Java-2D-Original und wird
  hier verbessert + nach 3D portiert. Original (NICHT im Repo):
  `D:\Dev\IT Projekt RobertSchmauz Cartograph\` — Java-Quellcode als
  Gameplay-Referenz (EnemyAI, HearingModel, PowerUp-/PingManager-Verhalten),
  Sounds direkt wiederverwenden aus `src/assets/SFX/` (Ping, PingNotReady,
  Ping_Powerup_Pickup, EnemyAlertYellow/Red, GameOver, GameWon,
  LevelTransition, Walking_Idle) + `src/assets/Musik/` (MenuAmbiente).
  Zielpfad im Repo: `assets/audio/` (wav → LFS, s. `.gitattributes`).
- Godot 4.7 (Forward Plus, Jolt Physics, D3D12) + Blender 5.2 (`Cartograph 3D.blend`
  liegt NICHT im Repo, sondern auf dem Desktop). Main scenes `scenes/level_1|2.tscn`.
- Gameplay scripts (`scenes/`): `player.gd` (Third-Person + SpringArm + `E`-Ping),
  `droid_ai.gd` (Enemy-KI), `sonar_ping.gd` (`active_ping`), `ping_powerup.gd` +
  `run_state.gd` (max 7 Stacks, szenenübergreifend), `exit_trigger.gd`,
  `game_over.gd` / `victory.gd` (pausieren den Tree!), `sonar_hud.gd`, `menu_style.gd`.
- Droid-KI: Patrol = validierte Zufalls-Wegpunkte (`@export roam_radius`: L1 9 m,
  L2-A 4 m, L2-B 5 m) + 3 Wand-Fühler + Sampling-Stuck-Resolve; CHASE/HEARD =
  Navmesh-Pfad (`use_navmesh`, `get_next_path_position()`); Catch nur mit LOS +
  |dy| < 2 m + 1,2 s Grace. Debug via `get_debug_stats()` (stucks/rejects/
  feeler_turns/nav_steps). Gameplay-Details: README.
- Level-Geometrie: `assets/maps/EchoCart_L*.glb` (Blender-Export pro
  Level-Collection, ohne `L1_Volume`-Nebelbox). Naming steuert Kollision:
  `*-col` = sichtbar + trimesh-StaticBody, `*-colonly` = unsichtbarer Proxy,
  Rest = Deko ohne Kollision. `level_*.tscn` sind ~3 KB klein — alles Schwere
  steckt in GLB + `assets/nav/*.tres`.
- Navmesh: `NavigationRegion3D` pro Level + `assets/nav/L1|L2_navmesh.tres`
  (Agent H 2,4 / R 0,6 / Climb 0,3). Bake NUR headless:
  `tools/bake_navmesh.gd -- <level.tscn> <MapNode> <out.tres>`.
- `tools/` ist git-ignored (Verifier: `verify_stufe1.gd` erwartet 12× PASS +
  `RESULT: OK`; `bake_navmesh.gd`). Doku dazu in README. LFS: `*.glb/*.hdr/
  *.png/*.jpg`. Headless-Binary: `D:\Downloads\Godot_v4.7.2-stable_win64.exe\…_console.exe`.

#Gotchas:
-When told c p (with this syntax) -> commit and push everything including cohesive and unified msg in the grand scheme of things
-Be unfiltered and direct, guide the way if there is an objectively better one
-This is a private project, but open to the public
-Dont test unless really necessary
-SCENE SAFETY (hart gelernt, Session 2026-09-24): MCP-Szenen-Tools
 (add/move/setup_region/bake/…) und Editor-Save auf `level_*.tscn` /
 `e_droid.tscn` sind VERBOTEN — sie expandieren die GLB-Instanzen in die Datei
 (+20–34k Zeilen, Pfad-Konflikte `NavRegion/EchoCart…`, Format 3→4, rote
 Fehler-Nodes). Reparatur damals: `git checkout -- scenes/`. Regel: Szenen-Edits
 nur als Text-Edit bei GESCHLOSSENEN Editor-Tabs; vorher `git status`, nachher
 Dateigröße checken (~3 KB). Navmesh-Bakes nur headless (s. Architektur).
-test_move(t, motion) == true heisst BLOCKIERT (false = frei). Invertiert
 verbaut = ewiger Freeze (Bot bremst in Pause-Schleife, Metrik zeigt
 ~66 stucks/1200 Frames bei meanspeed 0). Bei Bewegungs-Bugs zuerst
 `get_debug_stats()` + Positionen samplen, dann Thesen testen.
-`game_over.gd` / `victory` pausieren den Tree (`paused = true`) — Headless-
 Verifier, die danach weiterlaufen, sehen eingefrorene Nodes. Nach Catch-Tests
 `paused = false` setzen.
-Godot-MCP-Brücke kann wegbrechen (ECONNREFUSED 6506) — dann headless per
 Binary weiterarbeiten, nichts blockiert. MCPRuntime-Autoload ist NICHT im
 Projekt (keine MCP-Screenshots/Inputs im Live-Run); visuelle Abnahme ersatz-
 weise via Blender-Viewport oder Editor.
-Blender-MCP: Node-Lookup per Typ statt Name (nicht-englische UI), keine
 Enum-Ids raten, `Cartograph 3D.blend` liegt unter `C:\Users\rober\Desktop\`.
 Godot↔Blender-Koordinaten: Godot (x,y,z) ↔ Blender (x,-z,y).
-Headless-Verify ist billig (~1–2 Min) und hat echte Bugs gefunden
 (invertierter Guard, Szenen-Bloat) — trotz "dont test" bei KI-/Physik-/
 Szenen-Änderungen immer laufen lassen.
