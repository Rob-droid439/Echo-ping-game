# Echo Ping Game (Echo Cartographer 3D)

3D-Prototyp in **Godot 4.7** (Forward Plus, Jolt Physics). Port des Java-2D-Originals
(`IT Projekt RobertSchmauz Cratgograph`): Sonar-Ping als Kernmechanik, Droiden als
Gegner, Powerups als Progression. Stand: lauffähiger Gameplay-Prototyp, kein Content-Lock.

## Starten

1. Projekt in Godot 4.7 öffnen (Import läuft automatisch).
2. F5 (Main Scene: `scenes/level_1.tscn`).

## Steuerung

| Eingabe | Aktion |
|---|---|
| WASD | Laufen (kamerarelativ) |
| Maus | Umsehen (Klick fängt die Maus ein) |
| Leertaste | Springen |
| E | Sonar-Ping |
| ESC | Maus freigeben |

## Systeme

- **Sonar-Ping** (`scenes/sonar_ping.gd`): expandierender Doppel-Ring, Basis 25 m,
  Cooldown 1,33 s. Gegner im Radius werden revealed (Marker, durch Wände sichtbar,
  6 s) und reagieren darauf.
- **Powerups** (`scenes/ping_powerup.gd`, Port aus `PowerUp.java`/`PingManager.java`):
  je Level 3 Pickups (L1 in Gebäuden, L2 in Ruinen/Plaza), global max. 7 Stapel,
  je Stapel +7,5 % Radius / +15 % Speed. Stand in `RunState` (szenenübergreifend),
  Anzeige im HUD (`PING +n/7`).
- **Droiden-KI** (`scenes/droid_ai.gd`, Port aus `EnemyAI`/`HearingModel`/`Enemy`):
  Patrol (Zufalls-Wegpunkte), Hearing (Ping-Suspicion mit Latenz und
  Treffer-Unschärfe), Vision (28°-Kegel, 9 m, Sichtlinie), Chase (SEEN exakt,
  HEARD mit Unschärfe). Berührung im SEEN-Zustand = Catch: Spieler und Droiden
  werden zurückgesetzt (Prototyp-Regel).
- **Protagonist** (`scenes/player.tscn`): D-Rig mit Idle/Walk/PingCast,
  Third-Person mit SpringArm-Kamera, Kapsel-Hitbox.
- **Levelwechsel**: `Area3D`-Trigger am Exit-Tunnel (`scenes/exit_trigger.gd`).
- **Umgebung**: Nacht-Env mit Glow/Fog/SSAO, Himmel = Blender-HDRI
  (`assets/sky/echo_night.hdr` — Quelle aus `Cartograph 3D.blend`).

## Kollision (Blender → Godot)

Benennung in Blender steuert den glTF-Import, keine Handarbeit in Godot:

- `*-col` an Meshes → Concave-/Trimesh-StaticBody (Wände, Gelände, Grenzen).
- `*-colonly` an Proxy-Boxen → unsichtbare Kollisionskörper (Poller, Fässer,
  Wracks, Curbs etc.). Leere Empties mit `-col` funktionieren über glTF
  **nicht** (Blender exportiert keinen Display-Typ) — deshalb Proxies als Mesh.
- Kein Suffix = keine Kollision (Deko, Lichter, Sensoren).

Export aus `Cartograph 3D.blend` (Auswahl je Level-Collection) nach
`assets/maps/EchoCart_L1.glb` bzw. `EchoCart_L2.glb`. L1-Gebäude sind begehbar
(hohles EG), L2-Gebäude sind Kulisse (2-m-Slabs), Ruinen begehbar.

## Projektstruktur

```
assets/maps/   Level- und Charakter-GLBs + extrahierte Texturen
assets/sky/    Blender-HDRI für den Himmel
scenes/        Level-Szenen, Player, Sonar, Droiden-KI, HUD, Env, RunState
addons/godot_mcp/  Godot-MCP-Addon (Bridge-Verdrahtung noch offen)
tools/         Headless-Testskripte (git-ignoriert)
```

## Entwicklung

- Git mit LFS (`*.glb`, `*.hdr`, `*.png`, `*.jpg`). `.godot/` und `tools/` sind ignoriert.
- Verifikation headless möglich: Szene laden, Verhalten asserten
  (Beispiele lagen in `tools/`, z. B. Ping-Reveal, Powerup-Cap, KI-Zustände).
- Regel bei paralleler Arbeit: Szenen im Editor nicht speichern, während der
  Agent Dateien anfasst (sonst überschreibt der Editor-Stand die Platte) —
  ersatzweise alles über Commits abgleichen.

## Bekannte Prototyp-Grenzen

- Kein NavMesh: Droiden laufen per Wegpunkt + Wall-Slide, kein Pathfinding.
- Catch = Respawn, kein Game Over, kein Menü, kein Ton.
- L2-Gebäude ohne Innenräume; Treppen-Block und Schild-Lücke als Sonderfälle
  dokumentiert (Etappe 3b).
