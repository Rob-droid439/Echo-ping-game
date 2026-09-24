# Plan: Level-Design (Blender) + Enemy-KI — nächste Session

Stand: 2026-09-23. Kontext: Commits bis `4f4d99a` (Endmenü + Alert-State).

## 0. Ausgangslage

- Droid: Kapsel r0,5/h2,4, Speed ~3,5–5 m/s, Roam-Radius fix **9 m**
  (`scenes/droid_ai.gd`), Bewegung = Zufalls-Wegpunkt + Wall-Slide,
  **kein Navmesh** (bekanntes Prototyp-Limit, siehe README).
- Kamera braucht Platz: SpringArm 3 m hinter dem Spieler.
- Türen: Lintel-Unterkante 2,6 m, Bot-Top 2,4 m — passt gerade so.
- Konvention bleibt: `*-col` = sichtbar + Kollision, `*-colonly` = unsichtbarer
  Proxy, Rest = Deko. Export pro Level-Collection aus `Cartograph 3D.blend`
  nach `assets/maps/EchoCart_L1.glb` / `EchoCart_L2.glb`.
- Catch-Regel (bereits drin): nur mit Sichtlinie (`_has_los`), |dy| < 2 m,
  1,2 s Spawn-Grace — kein Catch/Teleport mehr durch Wände.

## 1. Vermessung (Session-Start, ~20 Min, Blender)

- Durchgangsbreiten messen: alles **< 2,5 m frei** markieren
  (1 m Bot + 3-m-Kamera + Spielraum). Skript-Idee wie bisher: AABB aller
  `-col`/`-colonly` gegen Weg-Polygone prüfen.
- Prop-Dichte in Durchgängen zählen (Poller, Bikes, Crates, Lampenfüße,
  Curbs) → das ist die Stau-Liste.
- Droid-Spawns prüfen: Freiraum ≥ 3 m um Spawn + Roam-Kreis 9 m.
  Liegt der Kreis halb in Wänden, ist Dauer-Stuck garantiert.

## 2. Blender-Layout-Pass (L1 zuerst, dann auf L2 übertragen)

**Regeln:**

- **Transit freihalten:** Durchgänge/Türen/Tunnel bekommen ~3 m freie
  Schneise. Content (Crates, Barrels, Bikes, Trümmer, Lampenmasten) wandert
  **an Wände und Ränder** — als Deckung für den Ping, nicht in die Laufwege.
- **Zonen statt Freifläche:** pro Droid eine Patrol-Zone (Platz, Ruine,
  Werkstatt) mit 4–6 m Freifläche in der Mitte; Engstellen nur als bewusste
  Chokepoints.
- **Spawn-Sicherheit:** Spieler-Spawn und Droid-Spawn mind. 12 m auseinander
  + Sichtblocker dazwischen, damit SEEN nicht sofort triggert.
- **Kollisions-Disziplin:** nach jedem Verschieben prüfen, dass Visual und
  `-colonly`-Proxy noch deckungsgleich sind (zuletzt 1-cm-Genauigkeit —
  halten). Danach Re-Export L1/L2-GLB + Dateigröße sanity-checken.
- **Türhöhen im Blick:** nichts unter 2,6 m lichte Höhe in Droid-Routen
  stellen (Bot-Top 2,4 m).

**Abnahme pro Level:** Screenshot-Runde in Godot (Spawn, jede Engstelle,
jede Patrol-Zone) + einmal Ping zünden.

## 3. Enemy-KI, Stufe 1 — ohne Navmesh (direkt danach)

Ziel: Wandkontakt nur noch als Ausnahme, kein Durch-Wand-Glitchen.

- `ROAM_RADIUS` als `@export` pro Droid (kleine Räume 4–5 m, Plätze 9 m)
  statt global 9 m.
- **Wegpunkt-Validierung:** vor Übernahme prüfen — Ziel auf Boden?
  (`intersect_ray` nach unten) und Luftlinie frei? (Ray auf Mask 1 wie
  `_has_los`). Sonst neu würfeln (max. ~8 Versuche).
- **Wand-Fühler:** 3 kurze Raycasts (vorne/links/rechts, ~2 m) pro Frame;
  blockierte Richtung → Zielvektor wegdrehen statt frontal wall-sliden.
- **Stuck-Logik straffen:** `STUCK_TIME` 0,3 s lassen, aber Resolve mit
  Richtungs-Sampling (3 Kandidaten, besten freien nehmen) statt fixem
  Seitwärtssprung.
- **Chase trennen:** im CHASE nur Ziele mit freier Linie annehmen;
  HEARD-Positionen erst per Fühler-Ray validieren (kein Anrennen gegen die
  Wand, hinter der es gehört wurde).
- **Anti-Glitch-Geländer:** `test_move` vor großen Richtungswechseln;
  Catch-Regel (LOS + Höhe + Grace) als Regressionstest behalten.
- **Debug-Metrik (temporär):** Stuck-Counter + Waypoint-Rejects loggen,
  damit der Playtest Zahlen statt Gefühl liefert.

## 4. Enemy-KI, Stufe 2 — Navmesh (eigene Session, wenn Stufe 1 sitzt)

- `NavigationRegion3D` pro Level, Bake aus der `-col`-Geometrie (Godot 4.7).
- `droid_ai` bekommt Pfad via `NavigationAgent3D` für CHASE/HEARD,
  Patrol bleibt Waypoint (billig, organisch).
- Fallback: kein Pfad → altes Verhalten. Erwartung: Droiden nutzen Türen
  statt Wände.

## 5. Session-Ablauf (Vorschlag, ~2–3 h)

1. Vermessung + Stau-Liste (Blender).
2. L1 umräumen → Re-Export → Godot-Screenshots.
3. KI Stufe 1 einbauen (Validierung, Fühler, Export-Vars).
4. Playtest je Level 5 Min mit Stuck-Metrik; Tuning nur wenn nötig.
5. Commit + Push (Blender-Save + GLBs + Szenen).

## 6. Fertig-Kriterien

- Bot läuft 60 s Patrol ohne einen Stuck-Resolve; keine Wand-Clips auf
  Screenshots.
- Alle Durchgänge ≥ 2,5 m frei vermessen; Content steht an Rändern.
- Catch nur mit Sichtlinie (Regressionstest: durch Wand kein Menü).
- L1 + L2 je einmal durchgespielt (Ping, Powerups, Exit/Victory).
