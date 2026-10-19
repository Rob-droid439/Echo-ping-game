# Plan: Map-Hitbox-Audit Â· 30 %-Skalierung Â· Sprint-Knie-Fix

**Stand:** 2026-10-19 Â· **Repo:** `3d-cartograph-game` Â· **Scope:** L1 + L2 (Maps) + `D_Protagonist` (Sprint-Clip)
**Status-Legende:** `[ ]` offen Â· `[~]` in Arbeit Â· `[x]` fertig

---

## 0. Zusammenfassung

Drei Probleme, eine Kampagne:

| # | Problem | Verdacht / Ursache | LÃ¶sungsweg |
|---|---------|--------------------|------------|
| 1 | Unsichtbare Barriere beim Auto auf der StraÃŸe (L1); Hitboxen der Kartengeometrie teils uneben/fehlerhaft | Kollisions-Meshes (`*_col` / Trimesh) weichen von der sichtbaren Geometrie ab und ragen Ã¼ber physische Objekte hinaus | Systematischer Hitbox-Audit (Skript) + gezielte Reparatur in Blender + Re-Export + Navmesh-Neubake |
| 2 | Maps zu klein/eng | â€” | Beide Karten-GLBs um **+30 % (linear, uniform)** vergrÃ¶ÃŸern â€” **nur die Map** â€” in Blender, dann Re-Export + Gameplay-Objekte/Navmesh-Tests nachziehen |
| 3 | Sprint-Knie biegt rÃ¼ckwÃ¤rts (Beine laufen spiegelverkehrt) | `D_Anim_Sprint` im `D_Protagonist.glb`: Thigh/Shank-Keyframes mit invertiertem Beuge-Vorzeichen | Sprint-Clip in Blender reparieren, Re-Export, Audit + Regression |

Grundregel Ã¼ber allem: **Hitbox â‰™ Sichtgeometrie ("wasserfest").** Nach jedem Re-Export wird der Zustand als Ganzes geprÃ¼ft (Audit + Tests), nicht punktweise geraten.

---

## 1. Kernprinzipien (wasserfeste Hitboxen)

1. **Ein Ursprung pro Objekt:** Sicht-Mesh und Kollisions-Mesh stammen in Blender aus derselben Objekt-Abstammung (`_col`-Duplikat desselben Objekts, gleicher Parent-Transform). Kollisions-Meshes werden nie "freihÃ¤ndig daneben" gebaut.
2. **Toleranz:** Abweichung Sicht â†” Hitbox max. **2 cm** in XZ und max. **2 cm** in Y (glatter Ãœbergang auf Bodengeometrie; verhindert Stolperkanten und unsichtbare VersprÃ¼nge). GrÃ¶ÃŸere Abweichung = Finding.
3. **Kein Collider ragt aus seiner Sichtgeometrie:** Eine Hitbox, die Ã¼ber die sichtbare Wand/StraÃŸe hinausragt, ist immer ein P0-Finding (unsichtbare WÃ¤nde). Eine Hitbox, die enger als die Sichtgeometrie ist, ist ein P1-Finding ab 5 cm.
4. **Systeme folgen der Karte:** Navmesh wird nach jeder GeometrieÃ¤nderung neu gebacken; alles, was Kartenkoordinaten kennt (Tests, Exits, Pickups, Spawns, Droiden-Positionen), wird mit transformiert.
5. **Messen statt vermuten:** Jede Ã„nderung wird durch Audit-Berichte (`reports/*.md` + `.json`) belegt â€” Vorher-/Nachher-Vergleich je Stufe.

---

## 2. Stufe 1 â€” Hitbox-Audit (Vorher-Befund sichern)

**Ziel:** Maschinell sichtbar machen, wo Sichtgeometrie und Hitbox auseinanderlaufen â€” inkl. der Auto-/StraÃŸen-Barriere â€” bevor irgendetwas geÃ¤ndert wird.

### 2.1 Audit-Skript `tools/audit_hitbox.gd` (Godot, headless)

Neues SceneTree-Skript (Muster: `tools/bake_navmesh.gd`):

- Instanziert das Level (`level_1.tscn` / `level_2.tscn`) und durchlÃ¤uft alle `CollisionShape3D`.
- FÃ¼r jeden Collider: Welt-AABB bilden; Partner-Sicht-Mesh finden (Heuristik 1: nÃ¤chstliegendes `MeshInstance3D` per AABB-Distanz; Heuristik 2: Namens-Matching `X_col` <=> `X`).
- Findings, wenn:
  - Collider ragt **auÃŸerhalb** des Sicht-AABBs um mehr als 2 cm (unsichtbare Wand),
  - Collider ist **enger** als das Sicht-AABB um mehr als 5 cm (Blockade deckt Geometrie nicht),
  - Collider-Oberkante liegt Ã¼ber der Sicht-Oberkante um mehr als 2 cm (glatter Aufstieg zerstÃ¶rt).
- **Walkability-Sweep am Auto ("Killbox-Probe"):** Raster 0,25 m im Radius 3,5 m rund um das Auto (Position aus dem Welt-AABB des Auto-Meshes); an jedem Rasterpunkt Player-Kapsel (r 0.35 / h 1.9) per `test_move` prÃ¼fen:
  - pro Punkt: blockiert ja/nein + kollidierendes Objekt + Kollisions-Normal,
  - Auswertung: %-blockierte FlÃ¤che + Liste schuldiger Collider-Namen (z. B. `road_col` â†’ konkreter Verursacher).
- Bericht: `reports/level_X_hitbox_report.md` (lesbar) + `reports/level_X_findings.json` (maschinell).

**Abnahme Stufe 1:** Berichte fÃ¼r beide Levels existieren, Findings inkl. Auto-Schuldobjekt sind benannt und priorisiert â€” **ohne** Ã„nderungen an der Map.

### 2.2 Bericht-Review (Mensch + AI)

- Priorisierung: **P0** = unsichtbare WÃ¤nde/Spielerentwicklung blockiert (Auto-Fall), **P1** = Abweichung > 5 cm, **P2** = Kosmetik.
- Beweisfoto fÃ¼r den Auto-Fall: `run_scene(debug_collisions=true)` + `take_screenshot` an der betroffenen Zone.

---

## 3. Stufe 2 â€” Hitbox-Reparaturen (Blender, gezielt)

**Ziel:** Jeden P0/P1-Finding in Blender am Original sehenden-/Sicht-Mesh beheben. **Niemals** berÃ¼hren die importiertenNodes direkt in Godot (verlorene Ã„nderungen beim nÃ¤chsten Re-Export).

Vorgehen je Finding:
1. In Blender Ã¼ber den Objektnamen identifizieren (Godot-Import-Namen = Blender-Objektnamen).
2. Reparaturtypen:
   - `_col`-Duplikat ist verschoben/zu groÃŸ => **aus dem Sicht-Mesh neu erzeugen** (Prinzip "Ein Ursprung"), verschieben/skalieren bis Audit grÃ¼n.
   - Trimesh aus zu grober Geometrie => Decimate/Retopo des `_col`-Duplikats (Ziel < 12k Tris pro StÃ¼ck; KantenlÃ¤nge auf StraÃŸen â‰¤ 1 m).
   - Unebene Kanten zwischen BodenbelÃ¤gen (StraÃŸe <-> Boden): Merge-by-Distance (0.001) oder saubere Kante; "HÃ¼gel-/Bogen-Hitbox"-Findings aus dem Audit.
3. Re-Export beider Karten (EchoCart_L1, EchoCart_L2) als GLB â€” gleiche Export-Einstellungen, Node-Anzahl zÃ¤hlen (wie beimase `167 Nodes`-Check in `f283668`), Bone-/Shader-Objekte unangetastet.
4. Godot: Reimport prÃ¼fen, Navmesh neu backen (Â§6), Audit erneut â€” Bericht Vorher/Nachher.
5. Tests: `regression_droid_pivot`, `regression_m1_door`, `regression_sprint`alle PASS. Playtest am Auto: gehen + sprinten aus 8 Richtungen.

**Abnahme:** Killbox-Sweep hat 0 blockierte Samples innerhalb der begehbaren Zone; Spieler bewegt sich um das Auto in alle Richtungen ohne unsichtbare RÃ¼ckzhr-Wall/HÃ¤uer.

---

## 4. Stufe 3 â€” Maps +30 % skalieren (Blender, NUR die Map)

**Ziel:** Beide Karten linear uniform **x1.3** vergrÃ¶ÃŸern. FlÃ¤che x1.69, DeckenhÃ¶he x1.3, TÃ¼ren x1.3 â€” wahrnehmbaren mehrshÑ€Ð¸Ñ Raumsensor.

### 4.1 Skalierungs-Regeln

- Nur die Map-Root/Collection in Blender skaliern â€” **unberÃ¼hrt bleiben**:
  - Spieler (`D_Protagonist`) Skalierung 1.0 bleibt;
  - Droiden (`E_Droid`) Skalierung 1.0 bleibt (Rig-/Timings bleiben);
  - Reichweiten bleiben 1:1 (HEAR_RANGE 18 m, VISION_RANGE 9 m): Tuning spÃ¤ter in Playtest-Session, nicht hier.
- Skalierung um den Welt-Ursprung (0,0,0) = Boden ist Boden: Terrain bleibt liegen, keine Bounding-Box-Mitte als Pivot.
- `_col`-Meshes skalierten mit (angenommen: `_col`-Duplikate an denselben Objekt-Parents) â€” das Audit im Nachher beweist es.
- Keine Umbenennungen/Reorganizationen; Re-Export erhÃ¤lt die Importstruktur.

### 4.2 Godot-Nachziehen (Pflichtliste)

| # | Aktion | Werkzeug |
|---|--------|----------|
| 1 | GLB L1/L2 reimportieren; Map-Node-Normalizing bleibt Scale = 1.0 | Godot Editor/MCP |
| 2 | Navmesh L1/L2 neu backen (`tools/bake_navmesh.gd`), agent_radius 0.3, agent_height 2.2 unverÃ¤ndert | headless |
| 3 | Gameplay-Knoten x1.3 verschieben (Liste unten) | batch_scene_edit |
| 4 | Test-Koordinaten x1.3 (M1-TÃ¼r u. a.) | edit tests |
| 5 | Audits + Killbox-Sweep erneut laufen lassen | headless |
| 6 | Playtest + Screenshots (Auto, TÃ¼ren, Exits, Plaza) | run_scene/look |

**Gameplay-Objekte x1.3 (Positions-Werte):**

| Level | Knoten | Anmerkung |
|-------|--------|-----------|
| L1 | ExitTrigger (+Shape), Player-Spawn, E_Droid (+ `roam_radius` x1.3), PingPowerup_* | aktuelle Positionen vor der Transformation aus der .tscn lesen |
| L2 | ExitTrigger(+Shape), Player-Spawn, E_Droid_A/B (+ `roam_radius` x1.3), PingPowerup_*, Victory | dieselbe Arbeitsweise |

**Abnahme:** TÃ¼ren x1.3 breiter/hÃ¶her, Killbox frei, alle Tests PASS, Audits grÃ¼n.

---

## 5. Stufe 4 â€” Sprint-Knie (Blender, nur Sprint-Clip)

**Befund:** `D_Anim_Sprint` beugt die Knie rÃ¼ckwÃ¤rts (Fersen laufen zur falschen Richtung; wirkt wie RÃ¼ckwÃ¤rtsrennen).

**Diagnose (Blender MCP):**
1. Bein-Knochen identifizieren (Thigh.Shin./...)und Skelettwurzel ansehen.
2. Zwei mÃ¶gliche Ursachen, nacheinander prÃ¼fen:
   - **Bone-Roll invertiert**: dann laufen ALLE Clips gespiegelt â†’ Walk/Idle kontrollieren (Fall vermutlich untypisch).
   - **Nur die SprintKeyframes** haben invertiertes Pitch (typisch): Pitch-Keys der Thighs + Shins im Sprint-Clip spiegeln (Takt, in-place), Pelvis/HÃ¤nde/Lean bleiben.
3. Re-Export `D_Protagonist.glb` mit **allen** Animationen (PrÃ¼fung wie `167 Nodes identisch`), D_Anim_PingCast bleibt gelÃ¶scht.
4. Godot-PrÃ¼fung:
   - Neues Script `tools/audit_knee.gd`: Sample 24 Frames pro Bein (Hip->Knee->Ankle): Beugung Vorzeichen konsistent, Sprint und Walk als Gegenprobe (Walk korrekt, Sprint nach Fix korrekt).
   - `regression_sprint.gd` PASS (Clip existiert, Timing, Blowback).
   - Visual check: Screenshots der Extrem-Pose der Schritte.

**Abnahme:** Keine Kniiehung rÃ¼ckwÃ¤rts in einem 24-Frames-Sample; Sprint wirkt wie richtig gerichtetes Laufen; Walk/Idle bleibt unverÃ¤ndert korrekt.

---

## 6. Nachzieh-Regel nach JEDER GeometrieÃ¤nderung

1. **Navmesh-Neubake** (headless):
   `godot --headless --path . -s res://tools/bake_navmesh.gd -- res://scenes/level_X.tscn EchoCart_LX res://assets/nav/LX_navmesh.tres`
2. **Route-Sanity**: Killbox-Probe + Testpfade an TÃ¼ren/Exits im Audit.
3. **Alle 3 Regressions** an PASS: `droid_pivot`, `m1_door`, `sprint`.
4. **Audit-Bericht grÃ¼n**: 0 P0, 0 P1.
5. **Screenshot-Abnahme** (Kamera an Auto, TÃ¼ren, Exit, Plaza).

---

## 7. Commitplan

| Reihenfolge | Commit | Content |
|-------------|--------|---------|
| C1 | Audit | `tools/audit_hitbox.gd`, `tools/audit_knee.gd`, `reports/*` (vorherzustands findings) |
| C2 | Hitbox-Fixes | Blender/Fixes per Re-Export L1+L2, Navmesh-Neubake, Berichte nachher |
| C3 | Map x1.3 | Re-Export + Gameplay-Nachziehen + Test-Koordinaten + Neubake + Audits |
| C4 | Sprint-Knie | Re-Export `D_Protagonist.glb`, `audit_knee` PASS, `regression_sprint` PASS |
| C5 | Finalisierung | Regressions gesamt, Playtest-Screenshots, README-Anpassung |

---

## 8. Definition of Done global

- `[ ]` Wasserfest: `reports/*_hitbox_report.md` zeigt 0 P0 / 0 P1 Findings in beiden Levels.
- `[ ]` Auto-Fall: Killbox-Sweep am Auto liefert 0 blockierte Samples; Spieler kann in alle 8 Richtungen laufen und sprinten.
- `[ ]` 30 %: beide Karten einheitlich x1.3 (Ursprung am Boden); Gameplay-Objekte folgen (Exits/Spawns/Powerups/Droiden); Navmesh und alle Test-Regeln grÃ¼n.
- `[ ]` Knie: `audit_knee` beweist korrekte Beugung in beiden ZustÃ¤nden (Walk korrekt und Sprint nach Fix korrekt), keine RÃ¼ckwÃ¤rts-Knie-Ausreisser.
- `[ ]` Keine Regression: alle drei Tests PASS; README-Abschnitt mit Abnahmefotos.

---

## 9. Risiken `->` GegenmaÃŸnahmen

| Risiko | Wahrscheinlichkeit | GegenmaÃŸnahme |
|--------|-------------------|----------------|
|
Blender-Export Richtlinien (Node-Reihenfolge) nichtå‡ºçŽ°äº† | mittel | Export-Log mit Node-/Bone-ZÃ¤hlern, Vergleich mit `f283668` Referenz |
| Plattform-Meshes/Skelett-Quaternionen Blenders-Kopplung irritiert Importeur | niedrig | Audit-/visuelle Checks vor/nach jedem Re-Export |
| 30 %-Skalierung Ã¤ndert SpielgefÃ¼hl (Reichweiten relativ kÃ¼rzer) | mittel | Werte unverÃ¤ndert lassen; Playtest-Tuning als separater Schritt |
| Skelett-Bones im Sprint-Clip vererben ihren Pitch auf andere Clips | niedrig | audit_knee vergleicht Walk gegen Sprint in jedem Export |
| Gameplay-Objekte beim Skalieren vergessen | niedrig | Pflichtliste Â§4.2 + zwei-Auge-Review |

