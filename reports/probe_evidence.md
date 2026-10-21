# Walkproof: Wreck-Auto-Hitbox (L1) nach Winding-Fix

Empirischer Beleg nach dem Collider-Winding-Fix (38 `colonly`- + 92 `col`-Proxies,
Faces nach außen gedreht, GLB-Neuexport beider Karten).

Alle Messungen **headless** (Godot 4.7.2, Jolt, echte level_1.tscn + echte
player.gd-Bewegungslogik) über `tools/probe_gate.gd` / `tools/probe_around.gd` /
`tools/probe_scan.gd` / `tools/probe_c.gd` (git-ignored Verifier).
Input-Driver: rohe physikalische Tasten-Events (keycode + physical_keycode),
weil `player.gd` `Input.is_physical_key_pressed()` liest und das Projekt keine
InputMap-Aktionen definiert.

## 1) Korridor-Raster (test_move, Kapsel r 0.45 / h 2.0, y 0.6, z = 33)

- x = 33.00 … 35.50 **komplett frei** (0 Blocks).
- Erster Block ab x = 35.75: `L1_Wreck_0/EchoCart_L1`, Kontakt bei **x = 36.0946**,
  Normale (−1, 0, 0) = Westface des Autos. Kein weiterer Blocker im Korridor.

## 2) Echter Walk (Input über phys. Tasten W, walk 3,5 m/s)

- Start (34.2, 0.9, 33) → läuft 34.205 → 34.564 → 35.147 →
  **stopp bei (35.672, 0.104, 33.0)** (Westface 36.095 − Kapselradius ≈ 0.42).
- Vor dem Fix endete dieselbe Strecke mitten **im** Auto (x ≈ 37.2).

## 3) Um das Auto herum (deterministisch, 3 Segmente, alle PASS)

| Segment | Strecke | Ergebnis |
|---------|---------|----------|
| A: West-Zulauf | (34.2, 0.9, 33) → +X | **Stop x = 35.672** — Westface blockt ✅ |
| B: Nordflanke | (34.2, 0.6, 36.2) → +X | **läuft frei bis x = 36.839** — keine unsichtbare Wand ✅ |
| C: Ost-Zulauf | (44.2, 0.6, 33) → −X | **Stop x = 42.319** — Ostface blockt ✅ |

→ `RESULT: A=true B=true C=true  CHECK: PASS - Westface blockt, Nordflanke frei, Ostface blockt`

## 4) Feindiagnose Segment C (Telemetrie alle 2 Frames)

- Freier Fall von y 0.6 auf Boden (y 0.10) zwischen f006–f024.
- Danach konstantes 3,5 m/s-Gehen bis **x = 42.319**, dann velocity = 0
  (Kontakt Auto-Ostface 41.905 + r). Kein Zwischenblocker zwischen 44.6 und 42.4.

## 5) Statischer Raster-Scan (test_move −X, r 0.4, x 44.6 → 41.9, z 33)

- x = 44.6 … 42.4: frei.
- x = 42.3 … 42.0: geklemmt an `L1_Wreck_0/EchoCart_L1` bei **x = 41.9054**,
  Normale (+1, 0, 0) = Ostface.

## Abnahmefotos (godot_reports, Stand Anbau = ×1.3-Layout + West-Anbau)

- `reports/proof_l1_car_stop.png` — Spieler am Stop-Punkt (35.67, 33) vor der
  Westface 36.095 (Auto/Wracks als dunkle Silhouette vorn links).
- `reports/proof_l1_spawn.png` — Spawn/Plaza-Übersicht L1.
- `reports/proof_l1_exit.png` — Spieler (58, 33), Blick SE aufs ExitTrigger
  (81.25, 44.2).
- `reports/proof_l1_bollard_ping.png` — Bollard (Poller-Linie z = 30.55) mit
  Pink-Band leuchtend direkt neben dem Spieler nach `cast_ping`.
- `reports/proof_l1_annex.png` — Spieler (5, 33), Blick nach Westen in den
  neuen Anbau-Streifen.
- `reports/proof_l2_spawn.png` — Spawn-Übersicht L2 (Player 7.045, 0.452,
  97.751).
- `reports/proof_l2_exit.png` — Spieler (58, 100), Blick SE aufs ExitTrigger
  (81.9, 110.5).
- `reports/proof_l2_annex.png` — Spieler (5, 88), Blick nach Westen in den
  Anbau-Streifen.

## Kontext

- Report-Grundlage: `reports/level_1_hitbox_report.md` / `level_2_hitbox_report.md`
  (nach Fix: 0 P0 / 0 P1, Killbox-Sweep L1 613 Punkte, 0 illegitime Blocks).
- GLBs: `EchoCart_L1.glb` (20.208.216 B, 916 Nodes), `EchoCart_L2.glb`
  (15.272.576 B, 567 Nodes) — Node-Namensmengen identisch mit HEAD vor Fix
  (nur Index/Winding geändert; `L1_Volume`-Fog-Helper aus dem Exportbaum in
  die Root-Collection `FX_Volumes` verschoben, damit er als Principled-Volume
  nicht als opakes Box-Mesh landet).

## 5) Poller L1_Bollard_6 versetzt (2026-10-21)

- User-Befund: der Poller stand mitten im Nordflanken-Laufweg zum Auto
  ((41.6, 30.55) liegt direkt im Korridor zwischen Plaza und Ost-Zulauf).
- Fix in der .blend: Bollard_6 + BollardBand_6 + Bollard_6-colonly um +7.8 X
  nach (49.4, 30.55) versetzt (auf der Poller-Linie, Freiflache gepruft).
- Nach-Justage verifiziert: Re-Export L1 (20.208.252 B, 916 Nodes), Audit
  colliders=275 / meshes=887 / unpaired=0 / P0=0 / P1=0 / Killbox 613 / 0,
  Navmesh-Rebake 885 Polys / 1018 Verts, probe_around A=true B=true C=true
  (STOP 35.672 / frei 36.839 / STOP 42.319 unveraendert), Regressionen
  sprint (13 PASS), m1_door (7 PASS), droid_pivot (2 PASS).
- Beweisfoto reports/proof_l1_bollard_moved.png (Poller mit Pink-Band neben
  der Strasse, Auto-Wrack separat im Bild).

## 6) West-Anbau +34 m, Layout ×1.3 (2026-10-21)

User-Ziel: mehr Fläche über einen bebauten Anbau-Streifen statt linearer
Skalierung. Stufe 8 ersetzt Stufe 7 (linear ×1.4, verworfen): beide Karten
um einen **34 m langen West-Anbau** (x ≈ −34..0) erweitert, sonst Layout auf
dem verifizierten ×1.3-Stand (`scenes/level_*.tscn` +
`tests/regression_m1_door.gd` von e4d0cd3 revertiert, GLBs ersetzt).

- GLBs neu importiert: `EchoCart_L1.glb` **1002 Nodes**, `EchoCart_L2.glb`
  **657 Nodes** (vorher 916 / 567). Anbau-Namen `*_Anx` verifiziert, u. a.
  Annex-Node-Scales FugeY 0.53125, Curb 1.214286, Rail 1.230769;
  `-colonly`-Mesh-Verts × Node-Scale 1.3 = Weltposition (Auto-Barriere:
  Verts x 27.765..32.235 → Faces 36.095 / 41.906, unverändert zum
  ×1.3-Walkproof).
- Audits (`tools/audit_hitbox.gd`): L1 colliders 309 / meshes 966 /
  unpaired 0 / P0 0 / **P1 2**(FX-Deko-Gruppen „L1_Barrel_Flame (+3 Teile)“
  und „L1_B_S1_InBarrel“, bewusst ohne Collider) / Killbox-Sweep 613
  Punkte, 0 illegitime Blocks / kb_offzone_blocked 0; L2 colliders 186 /
  meshes 643 / unpaired 0 / P0 0 / P1 0. Berichte neu geschrieben
  (reports/level_*_hitbox_report.md).
- Navmesh (`tools/bake_navmesh.gd`, agent climb 0.45) im sauberen Szenen-
  Stand neu gebacken: **L1 1037 Polys / 1146 Verts, L2 1014 Polys /
  1162 Verts**, Fehler 0. (Ältere Bakes 972/856 waren mit Stale-Cache
  gebacken und ungültig.)
- Walkproof `tools/probe_around.gd` (Fenster ×1.3):
  SEG-A (West-Zulauf) Stop best_x = 35.672, Fenster 35.400–35.900,
  Westface 36.095 — PASS.
  SEG-B (Nordflanke) frei bis x = 36.839, Schwelle 36.800 — PASS.
  SEG-C (Ost-Zulauf) Stop min_x = 42.319, Fenster 42.000–42.600 — PASS.
- Regressionen: sprint PASS, m1_door 5/5 PASS (Tür-Durchgang SEEN,
  nav_steps 84, Distanz 1.02 m, 0 stucks, 0 waypoint_rejects, kein Catch
  durch Wand — paused=false, player_moved 0.0535), droid_pivot 2/2 PASS.
- **Ops-Lektion (Stale-Cache):** Nach GLB-Austausch müssen
  `.godot/imported/EchoCart_L*.glb-*` und `assets/maps/*.glb.import`
  gelöscht und der Godot-Import neu laufen — sonst lädt Godot weiter
  veraltete Cache-Szenen (hier: September-Import mit ×1.4-Skalierung,
  916 statt 1002 Nodes; alle Tests sind dann falsch). Diagnose:
  Instanz-Kindzahl (916 = stale / 1002 = frisch). Die Warnung
  „Unrecognized UID: uid://ccweiit44ig06“ nach Reimport ist benign
  (Loader fällt auf Pfad zurück).
- Abnahmefotos: s. Abschnitt "Abnahmefotos" oben (8 PNG: L1
  Spawn/Stop/Poller-Ping/Exit/Anbau, L2 Spawn/Exit/Anbau).
