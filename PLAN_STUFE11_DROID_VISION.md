# PLAN Stufe 11 — Droid-Visier als Flashlight-Feld + stärkeres Tracing

Stand: 2026-11-12 · Auftrag: „enemy tracing stronger“; das Sichtfeld wird
sichtbar als schwaches, taschenlampenartiges Licht (Zylinder-/Kegel-
Silhouette): am Droid-Kopf Radius 0, weiter vorn dicker, Radius ≈
Protagonisten-Höhe bei ca. 10 m, ab ca. 30 m fades das Licht (und damit
das Sichtfeld) weiter aus. Planung VOR Implementierung, Repo-Doku.

## 1) Recherche (Web, 2026-11-12) — Kernbefunde

| Quelle | Befund für uns |
|---|---|
| UE5 `UAISenseConfig_Sight` (Epic-Doku + community-Guides): https://dev.epicgames.com/documentation/en-us/unreal-engine/API/Runtime/AIModule/UAISenseConfig_Sight , https://uhiyama-lab.com/en/notes/ue/ai-perception-sight-hearing/ , https://cosindra.ai/guides/ue5-ai-perception | **Zwei Radien statt einem**: `SightRadius` (Erst-Erkennung) < `LoseSightRadius` (Gefunden-Bleiben) — Hysterese verhindert Flackern an der Kante (Lose ≈ Sight × 1.2–1.5). `PeripheralVisionAngle` ist **Halbwinkel** (klassische Falle). `AutoSuccessRangeFromLastSeenLocation`: wer einmal gesehen war, bleibt solange „gesehen“, wie er nahe der Last-Known-Position bleibt — starkes Tracing ohne Magie. LOS-Test = Raycast Eye→Ziel. |
| „Modeling Perception and Awareness in Splinter Cell: Blacklist“, GameAIPro 2 Ch. 28: http://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter28_Modeling_Perception_and_Awareness_in_Tom_Clancy's_Splinter_Cell_Blacklist.pdf + https://www.gamedeveloper.com/design/bringing-balance-to-stealth-ai-in-splinter-cell-blacklist | **Perception ≠ Awareness**: Kegel trifft → Awareness-Timer läuft, skaliert nach Distanz/Licht/Stance; erst bei vollem Timer gilt „gesehen“. Reiner Kegel modelliert Fermsicht schlecht → Blacklist nutzt „coffin“-Form (expandiert bis Punkt, kontrahiert/fadet dahinter) — genau die Logik hinter unserem Fade-Tail. 8-Bone-Exposure-Raycast: mehr sichtbare Knochen = schnellerer Fill. Awareness-States mit klarer Player-Lesbarkeit (Feedback!). |
| „Evaluating a Gradual Detection Meter …“ (Shadow Protocol), IcUSI 2026: https://rochi.utcluj.ro/icusi/proceedings/articles/3/30_1.pdf | Detection-Meter ∈ [0,1]: `dA/dt = r` sichtbar, `−decay` unsichtbar; SUSPICIOUS bei 0.4, CHASE bei 1.0; decay 0.3/s; **Proximity-Failsafe** (Nähe = sofort). Fill-Rate ist messbar der Schwierigkeitsregler (detektionszeit = 1/r). Unter kritischem Rate-Wert (0.40/s) füllt das Meter nie →UNUSED. |
| Doppelerkennung focused/peripheral: https://xesoft.dev/guides/unity-enemy-vision-line-of-sight/ + Godot-Skill-Beispiele (github.com/thedivergentai/gd-agentic-skills, vision_cone_3d.gd) | Check-Reihenfolge **billig → teuer**: Distanz → Winkel (dot, kein acos) → Raycast nur für Überlebende. `dist_factor = 1 − d/R` skaliert die Fill-Rate. Focused (schnell) vs. Peripheral (langsam) als zwei Zonen statt harte Kante. |
| Variable-angle cone (The Last of Us): https://gdad.wiki/wiki/programming/game-ai/npc-perception-systems | Kegelwinkel als Funktion der Distanz — Gegenteil unseres Flashlights (wir: r wächst mit d); belegt aber: Kegelform darf Design-getrieben sein, nicht nur „physisch“. |
| GMTK „School of Stealth Pt. 1“: https://www.youtube.com/watch?v=Ay-5g36oFfc | Lesbarkeit macht Stealth fair: sichtbare Kegel/Taschenlampen-Pools (Sly Cooper), Awareness-Feedback (Timer/Balken), Player-Favoring (offscreen-Hearing halbiert). **Unser sichtbares Feld ist zugleich Feedback** — Marker of the Ninja/Shadow-Tactics-Prinzip in 3D. |
| Beam-Visuals (Godot): „Spatial Light Shaft“ https://godotshaders.com/shader/spatial-light-shaft/ (Forward+ getestet), Baltor „Fake volumetric light cone“ https://baltor.ai/gallery/light-shaft-cone (**Godot 4.7.2** verifiziert), Fake Godrays https://godotshaders.com/shader/fake-godrays-godot-4-2/ (CSGCylinder + SpotLight3D), godot-proposals #4557 https://github.com/godotengine/godot-proposals/discussions/4557 | Standardrezept: **offener Kegel-/CylinderMesh + SpotLight3D**; Shader `unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled`, Emission mit **Apex-Fade** (pow(1−UV.y)), **Far-Fade** (smoothstep far_fade_start→far_fade_end) und **Depth-Contact-Fade** über DEPTH_TEXTURE, Kanten-Feather über N·V. FogVolume wäre „echt“, aber teuer; Billboard-Quads sind billig, wirken aber flach. → Beam-Mesh + SpotLight gewinnt (unsere Nacht-Szene, 2 Droiden = Budget ok). |

## 2) Geometrie des Feldes (User-Vorgabe → Zahlen)

- Apex am **Auge** des Droids (Rig-Eye, ~1.6 m; Rig 1.62, Eye-Node existiert).
- r(d) linear: r=0 bei d=0; **r ≈ 1.8 m bei d = 10 m** (Player-Kapselhöhe 1.9 →
  Körper füllt Kegelscheibe) → **Halbwinkel θ = atan(1.8/10) ≈ 10.2°**.
  (UE-Falle beachtet: 10.2° ist HALBwinkel, nicht FOV.)
- Sicht-/Fade-Tail: voll wahrnehmbar bis 30 m, **30→40 m fadet** die
  Erkennungsstärke linear auf ~0 (Visual-Fade identisch zum Perception-Fade —
  eine Quelle der Wahrheit, s. §4).
- Wirksam ersetzt der Flashlight-Kegel den heutigen 28°/9 m-Kegel:
  **enger, aber 4× weiter** — „tracing stärker“ ohne Rundum-X-Ray.

## 3) Wahrnehmungsmodell (droid_ai.gd)

Zustände: IDLE → **SUSPICIOUS** (neu) → CHASE (SEEN) → SEARCH (LKP) → IDLE.
HEARD-System (Stufe 9: Latenz, Falloff, Klemmung, Callouts, Patrol-Memory)
bleibt unverändert bestehen und füttert SUSPICIOUS.

- **Sichtbarkeitstest** (Reihenfolge billig→teuer, 10-Hz-Throttle pro Droid):
  1. `d ≤ SIGHT_MAX (40 m)` (quadriert vergleichen),
  2. `dot(head_forward, dir_to_target) ≥ cos(10.2°)`,
  3. LOS-Raycast Eye→Brust (Player-Body-Mitte); bei Meter > 0.5 zusätzlich
     Eye→Kopf (2. Raycast, „Exposure“-Analog Blacklist, Budget 2/frame).
- **Detection-Meter `A`** (pro Droid, persistiert über States):
  - sichtbar: `dA/dt = FILL_BASE × dist_factor × angle_factor × exposure`
    - `dist_factor`: 1.0 bei d ≤ 10 m, linear fallend auf ~0.25 bei 30 m,
      danach Tail 30→40 m auf 0 (identisch zur Visual-Fade-Kurve).
    - `angle_factor`: cos²(Abweichung) — Rand des Kegels füllt langsamer.
    - `exposure` (User-Entscheid 2026-11-12, „ganz leicht"): Standlicht-Bonus
      `1 + LIGHT_BONUS_MAX (0.08) × (1 − offangle/θ)` nur bei bestehendem LOS
      — Strahlmitte +8 % Fill-Rate, Kegelrand +0 %. **Null Zusatzkosten:**
      nutzt ausschließlich den bereits berechneten Dot-Wert (kein zusätzliches
      Licht-Sampling, keine Shadow-Abfragen; „im Strahl“ ≙ sichtbar-im-Kegel,
      deshalb ist die BELIEBTUNG schon die Sichtbarkeitsrechnung selbst).
      Stance/Motion-Extras → Stufe 12, NICHT hier.
  - unsichtbar: `dA/dt = −0.3/s` (Paper-Decay).
- **Schwellen** (Shadow-Protocol-Paper): `A ≥ 0.4` → SUSPICIOUS (investigiert
  LKP/letzte Sichtposition, wie HEARD heute); `A ≥ 1.0` → SEEN/CHASE.
- **Hysterese + AutoSuccess (UE-Modell)**: einmal SEEN bleibt SEEN, solange
  `d ≤ LOSE_SIGHT (52 m = 40 × 1.3)`; bei LOS-Verlust gilt SEEN weiter, wenn
  `dist(target, LKP) ≤ AUTO_SUCCESS (6 m)` — sonst SEARCH mit LKP-Ziel.
- **Callouts**: SUSPICIOUS sagt Richtung ±3 m weiter (weit), SEEN exakt
  (bestehendes `receive_callout`, Empfänger ≥ SUSPICIOUS).
- Catch-Regel (Nähe-Failsafe, Paper 2.5-Einheiten-Analog) bleibt exakt wie
  heute: SEEN + <1.6 m + LOS + |dy| < 2 m.

## 4) Visuelles Feld (e_droid.tscn + 1 Shader)

Eine Quelle der Wahrheit: **alle Konstanten als `@export`s an `droid_ai.gd`**
(SIGHT_MAX, HALF_ANGLE, FADE_START/END …); Beam-Mesh wird **per Code aus
denselben Exports gebaut** (ArrayMesh, Hüllkegel r=0→d·tan θ, Länge
SIGHT_MAX) — Visual und Perception können nie auseinanderlaufen.

- **SpotLight3D** am Eye-Node: „normale“ schwache Taschenlampe (warmweiß,
  energy ~0.8, `spot_angle = 10.2°`, range 40 m, **shadow on**) — Wände
  schneiden das echte Licht, das Feld respektiert Geometrie.
- **Beam-Mesh** (CylinderMesh-Frustum, open, no caps) mit Shader nach dem
  recherchierten Pattern (Spatial Light Shaft / Baltor): `unshaded,
  blend_add, cull_disabled, shadows_disabled`; Apex-Fade `pow(1−uv.y, k)`,
  Far-Fade `smoothstep(30, 40, d)` **mit denselben Werten wie dist_factor**,
  Depth-Contact-Fade via DEPTH_TEXTURE, Kanten-Feather via N·V. Kein Dust,
  kein Neon — „subtle, normal light“ (User-Vorgabe).
- **Lesbarkeits-Kopplung (GMTK-Prinzip), User-Entscheid: SEHR SUBTIL** —
  kein Farbsprung, sondern sanfter Tint-Lerp am geteilten Farb-Export:
  IDLE kaltweiß (0.82, 0.88, 1.0) → SUSPICIOUS leicht Richtung amber
  (0.92, 0.86, 0.72) → SEEN leicht Richtung rot (1.0, 0.78, 0.72); Beam-
  Emission bleibt konstant niedrig, SpotLight-Tint zieht mit (eine Quelle:
  `@export var beam_tint_idle/susp/seen` an droid_ai.gd, Lerp über ~1 s).
  Kein HUD-Balken (User: nein — Stufe 11b entfällt).

## 5) Datei-für-Datei

- `scenes/droid_ai.gd`: Sicht-Stack ersetzen (Meter, States, Hysterese,
  AutoSuccess), Exports + `get_debug_stats()` erweitert (meter, state).
- `scenes/e_droid.tscn`: SpotLight3D unter Eye + MeshInstance3D Beam —
  **nur als Text-Edit bei geschlossenen Editor-Tabs** (SCENE SAFETY,
  claude.md; Dateigröße danach prüfen — e_droid.tscn ist klein).
- `assets/shaders/droid_beam.gdshader`: neu (ein File, ~80 Zeilen).
- `sonar_hud.tscn/gd`: unverändert (User: kein Awareness-Balken).

## 6) Tests / Abnahme

- `tests/regression_droid_awareness.gd` erweitern (6 → ~10 PASS):
  Kegelrand ±1.8 m bei 10 m (in/out), Fade 30→40 m (Meter-Rate → 0),
  Hysterese 40/52, AutoSuccess um LKP, SUSPICIOUS-Einstieg bei Meter 0.4,
  Callout-Ketten unverändert, Lichtbonus: Fill Strahlmitte vs Kegelrand
  Δ ≈ +8 % (± Toleranz), Tint-Lerp erreicht Ziel-Farbe ~1 s nach State-Wechsel.
- Bestand müssen weiter laufen: verify_stufe1 (13 PASS — vision-Expectation
  an neue Geometrie anpassen), m1_door (Tür-SEEN via Navmesh), sprint,
  droid_pivot.
- Visuelle Abnahme: Live-Run (MCP), Screenshots Beam von vorn/seitlich,
  Fade-Zone, Wand-Schnitt des SpotLights; Meter-Debug via `get_debug_stats()`.

## 7) Performance & Budget

- Raycasts: Early-out (d → angle → LOS), Throttle 10 Hz/Droid → ≤ 4
  Raycasts/s/Droid normal, Spitze 20/s im Kandidatfall.
- 2 SpotLights mit Shadow (L2) in Forward+ @ Nacht: ok (Szene hat schon
  OmniLights); Beam-Mesh 2× ~64 Verts, additive = billiger als FogVolume.
- MSAA 3D 2x + D3D12 bleibt; Beam blend_add verträgt sich mit MSAA.

## 8) Risiken / Gotchas

- **Visual-Perception-Mismatch** (größtes Projekt-Risiko): Gegenmittel §4
  (Mesh aus Exports gebaut, Fade-Kurve geteilt).
- Editor-Szenen-Tools auf `e_droid.tscn` VERBOTEN (bloatet GLB-Instanzen) —
  Text-Edit only (claude.md).
- `blend_add` unsichtbar auf hellem Grund — unsere Nachtszene macht das
  harmless; beim Tag-Test im Auge behalten.
- SpotLight-Shadow + 40-m-Mesh: Beam darf NICHT von seinem eigenen Licht
  geschattet werden (`shadows_disabled` im Beam-Material).
- Kegel-Apex im Droid-Kopf → Near-Clip: Mesh ab d ≥ 0.4 m beginnen, damit
  kein „Punkt-Strahl“ am Kopf klebt (Baltor-Limit: „seen from inside looks
  flat“ — Apex-Aussparung mildert).

## 9) Entscheidungen (User, 2026-11-12) — final

1. **Farbkopplung: JA, sehr subtil** → Tint-Lerp (§4), kein Farbsprung.
2. **HUD-Balken: NEIN** → §5 angepasst, Stufe 11b entfällt.
3. **Lichtlevel-Modell: JA, aber leicht & nur wenn billig** → Implementiert
   als Standlicht-Bonus +8 % Fill-Rate in Strahlmitte, linear auf 0 am
   Kegelrand (§3 `exposure`) — null zusätzliche Queries, weil „im Strahl“
   exakt die bereits berechnete Sichtbarkeitsbedingung ist und der Dot-Wert
   schon vorliegt. Teureres Thief/Dishonored-Lichtlevel (echtes Licht-
   Sampling am Player) bleibt bewusst UNGEBAUT.

— Umsetzung nach diesem Plan: Datei-für-Datei, Tests, c p „Stufe 11“.
