# Hitbox-Report EchoCart_L1 · level_1.tscn

Toleranzen: Überstand > 0.02 m → P0 (unsichtbare Wand); Abdeckungsdefizit > 0.05 m → P1 (Blockade deckt Geometrie nicht). Killbox: Raster 0.25 m, Radius 3.50 m, Probe 0.06 m, Kapsel r 0.35 / h 1.90.

**Zusammenfassung**: Collider 275, Meshes 887, unpaired 0 — Findings **P0 25**, **P1 6**

**Killbox 'L1_Wreck_0'**: Punkte 613, blocked-any 6 (0.0 % der Punkte), im Autokennfeld 0 (legitim), Kapselkontakt-an-Soliden 3, Rest-Overlap skipped 328 — weg-geblockt ohne Legitimation: **0** — Schuldverteilung: {  }

## Findings

| P | Collider | Partner | Modus | Befund |
|---|---|---|---|---|
| P0 | `@StaticBody3D@19852` | `L1_Lamp_W Gasse_Pole` | proximity-0.01m | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P0 | `@StaticBody3D@19851` | `L1_Lamp_Tot_Pole` | proximity-0.01m | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P0 | `@StaticBody3D@19850` | `L1_Lamp_Sued_Pole` | proximity-0.01m | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P0 | `@StaticBody3D@19849` | `L1_Lamp_Strasse_Pole` | proximity-0.01m | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P0 | `@StaticBody3D@19847` | `L1_Lamp_Kern_Pole` | proximity-0.01m | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P0 | `@StaticBody3D@19846` | `L1_Lamp_Exit_Pole` | proximity-0.01m | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P0 | `@StaticBody3D@19845` | `L1_Lamp_BandW_Pole` | proximity-0.01m | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P0 | `@StaticBody3D@19844` | `L1_Lamp_BandE_Pole` | proximity-0.01m | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P0 | `@StaticBody3D@19843` | `L1_DebrisPile_2` | proximity-0.26m | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P1 | `@StaticBody3D@19843` | `L1_DebrisPile_2` | proximity-0.26m | Collider enger als Sichtgeometrie um (0.000, 0.480, 0.000) |
| P0 | `@StaticBody3D@19842` | `L1_DebrisPile_1` | proximity-0.26m | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P1 | `@StaticBody3D@19842` | `L1_DebrisPile_1` | proximity-0.26m | Collider enger als Sichtgeometrie um (0.000, 0.480, 0.000) |
| P0 | `@StaticBody3D@19841` | `L1_DebrisPile_0` | proximity-0.26m | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P1 | `@StaticBody3D@19841` | `L1_DebrisPile_0` | proximity-0.26m | Collider enger als Sichtgeometrie um (0.000, 0.480, 0.000) |
| P0 | `L1_BrokenSlab_1` | `L1_BrokenSlab_1_3 (+3 Teile)` | colonly-name | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P1 | `L1_BrokenSlab_1` | `L1_BrokenSlab_1_3 (+3 Teile)` | colonly-name | Collider enger als Sichtgeometrie um (0.000, 0.143, 0.000) |
| P0 | `L1_BrokenSlab_0` | `L1_BrokenSlab_0_3 (+3 Teile)` | colonly-name | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P1 | `L1_BrokenSlab_0` | `L1_BrokenSlab_0_3 (+3 Teile)` | colonly-name | Collider enger als Sichtgeometrie um (0.000, 0.143, 0.000) |
| P0 | `@StaticBody3D@19840` | `L1_Bollard_7` | proximity-0.01m | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P0 | `@StaticBody3D@19839` | `L1_Bollard_6` | proximity-0.01m | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P0 | `@StaticBody3D@19838` | `L1_Bollard_5` | proximity-0.01m | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P0 | `@StaticBody3D@19837` | `L1_Bollard_4` | proximity-0.01m | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P0 | `@StaticBody3D@19836` | `L1_Bollard_3` | proximity-0.01m | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P0 | `@StaticBody3D@19835` | `L1_Bollard_2` | proximity-0.01m | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P0 | `@StaticBody3D@19834` | `L1_Bollard_1` | proximity-0.01m | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P0 | `L1_Bike_1` | `L1_Bike_1_9 (+2 Teile)` | colonly-name | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P0 | `L1_Bike_0` | `L1_Bike_0_9 (+2 Teile)` | colonly-name | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P0 | `@StaticBody3D@19832` | `L1_Barrel` | proximity-0.01m | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P0 | `L1_B_S1_Tire` | `L1_B_S1_Tire_1 (+1 Teile)` | colonly-name | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P1 | `L1_B_S1_Tire` | `L1_B_S1_Tire_1 (+1 Teile)` | colonly-name | Collider enger als Sichtgeometrie um (0.000, 0.110, 0.000) |
| P0 | `L1_B_S1_InBarrel` | `L1_B_S1_InBarrel_0` | colonly-name | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |

## Killbox-Details (weg-blockierte Samples)

| Punkt XZ | Radius | Collider | NormalY | im Kennfeld |
|---|---|---|---|---|
| (31.50, 22.50) | 3.35 | `L1_B_Kiosk` | 0.00 | false |
| (32.00, 23.00) | 3.20 | `L1_B_Kiosk` | 0.00 | false |
| (32.25, 23.00) | 3.36 | `L1_B_Kiosk` | 0.00 | false |
