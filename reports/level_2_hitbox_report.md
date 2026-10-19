# Hitbox-Report EchoCart_L2 · level_2.tscn

Toleranzen: Überstand > 0.02 m → P0 (unsichtbare Wand); Abdeckungsdefizit > 0.05 m → P1 (Blockade deckt Geometrie nicht). Killbox: Raster 0.25 m, Radius 3.50 m, Probe 0.06 m, Kapsel r 0.35 / h 1.90.

**Zusammenfassung**: Collider 141, Meshes 558, unpaired 0 — Findings **P0 7**, **P1 0**

## Findings

| P | Collider | Partner | Modus | Befund |
|---|---|---|---|---|
| P0 | `@StaticBody3D@19809` | `L2_Ruin_B_Wreck` | proximity-0.25m | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P0 | `@StaticBody3D@19808` | `L2_Lamp_Pole_5` | proximity-0.01m | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P0 | `@StaticBody3D@19807` | `L2_Lamp_Pole_4` | proximity-0.01m | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P0 | `@StaticBody3D@19806` | `L2_Lamp_Pole_3` | proximity-0.01m | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P0 | `@StaticBody3D@19805` | `L2_Lamp_Pole_2` | proximity-0.01m | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P0 | `@StaticBody3D@19804` | `L2_Lamp_Pole_1` | proximity-0.01m | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |
| P0 | `@StaticBody3D@19803` | `L2_Lamp_Pole_0` | proximity-0.01m | Collider ragt in XZ aus Sichtgeometrie hinaus (unsichtbare Wand): +0.020/0.020 X, +0.020/0.020 Z (über/unter) |

## Killbox-Details

(kein CarPrefix übergeben — kein Sweep)
