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

## Abnahmefotos (godot_reports, Stand nach ×1.4)

- `reports/proof_l1_car_stop.png` — Spieler am Stop-Punkt (37.9, 35.54) vor der
  Westface (Auto/EchoCart_L1 als dunkle Silhouette).
- `reports/proof_l1_spawn.png` — Spawn/Plaza-Übersicht L1.
- `reports/proof_l1_exit.png` — ExitTrigger-Bereich L1 (Spieler (82, 42),
  Blick NE auf (87.5, 47.6)).
- `reports/proof_l1_bollard_moved.png` — Poller mit Pink-Band nahe am Spieler,
  neue Poller-Linie z = 32.9 (Poller-Beweisdaten: Bollard_6-Translation
  (53.2, 0.63, 32.9), s. Abschnitt 6).
- `reports/proof_l2_spawn.png` — Spawn-Übersicht L2 (Player 7.59, 105.27).
- `reports/proof_l2_exit.png` — Spieler (84, 112), Blick NE aufs ExitTrigger
  (88.2, 119).

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

## 6) Map linear ×1.4 total (2026-10-21)

User-Ziel: 40 % mehr Quadratmeter in beiden Maps, Verfahren wie im
×1.3-Pass (`map_hitbox_30_prozent_sprint_plan.md`, nach Fertigstellung
aus dem Repo entfernt). Gewählte Umsetzung: **linear ×1.4 total**
(Strecken ×1.4 → Fläche ×1.96), damit alle Abstände/Sperrfenster aus
dem verifizierten ×1.3-Stand exakt mit dem Faktor 14/13 weiterrechnen.

- Blender: alle Objekte beider Karten um `alt × 14/13 = 1.0769231`
  versetzt (Pole x = 0, z = 0) — Models, `col`/`colonly`-Proxies,
  Bänder, Lampen, FX-Helfer bleiben gemeinsam ausgerichtet. Re-Export:
  `EchoCart_L1.glb` 20.205.916 B / 916 Nodes, `EchoCart_L2.glb`
  15.273.392 B / 567 Nodes (Node-Mengen identisch).
- Beweisdaten im GLB (Headless-Glättung `py glbcheck.py`):
  `L1_Bollard_6` Translation exakt (53.2, 0.63, 32.9) bei Scale 1.4,
  Proxy `colonly` (8.4, 0, 0) · 1.4, Bollard_5 x = 28.0, Bollard_7
  x = 61.6 — Poller-Linie z = 32.9 (vorher 30.55).
- Audits (`tools/audit_hitbox.gd`): L1 colliders 275 / meshes 887 /
  unpaired 0 / P0 0 / P1 0 / Killbox-Sweep 613 Punkte, 0 illegitime
  Blocks; L2 colliders 141 / meshes 558 / unpaired 0 / P0 0 / P1 0.
  Berichte neu geschrieben (reports/level_*_hitbox_report.md).
- Navmesh (`tools/bake_navmesh.gd`, agent climb 0.45): L1 972 Polys /
  1130 Verts, L2 856 Polys / 1012 Verts, Fehler 0 (Backtrace-Warning
  benign; Rebakes ohne Kollision-Fehler). M1-Tür-Check: Schwelle
  ~0.42 < climb 0.45 — Tür bleibt passierbar.
- Walkproof `tools/probe_around.gd` (Fenster ×14/13):
  SEG-A (West-Zulauf) Stop best_x = 38.478, Fenster 38.123–38.662,
  Westface 38.87 — PASS.
  SEG-B (Nordflanke) frei bis x = 39.645, Schwelle 39.631 — PASS.
  SEG-C (Ost-Zulauf) Stop min_x = 45.544, Fenster 45.231–45.877,
  Ostface 45.13 — PASS.
- Regressionen: sprint 14/14 PASS, m1_door 5/5 PASS (Tuer-Durchgang
  SEEN, nav_steps 91, Distanz 1.038 m, 0 stucks), droid_pivot 2/2 PASS
  (Pivot-Maxfehler 1.79e-7).
- `.tscn`-Gameplay-Knoten per Formel `alt × 14/13` nachgesetzt und
  verifiziert — L1: Player (20.583, 0.864, 34.216), ExitTrigger
  (87.5, 2.8, 47.6), E_Droid (63.447, 0, 7.639) Roam 12.6, Sonar-Ring
  (64.981, 0, 8.628), Powerups M1/S1/W2 (39.2, 25.2 / 14, 42 /
  21, 14.7); L2: Player (7.590, 0.487, 105.270), ExitTrigger
  (88.2, 2.8, 119), E_Droid_A/B (42, 95.2 / 53.2, 98) Roam 5.6/7.0,
  RuinA/B (44.8, 82.6 / 44.8, 119), Plaza-Ruine (35, 95.2).
- Abnahmefotos: s. Abschnitt "Abnahmefotos" oben (6 PNG nach ×1.4,
  L1 Spawn/Stop/Poller/Exit, L2 Spawn/Exit).
