# Hitbox-Report EchoCart_L1 · level_1.tscn

Toleranzen: Überstand > 0.02 m → P0 (unsichtbare Wand); Abdeckungsdefizit > 0.05 m → P1 (Blockade deckt Geometrie nicht). Killbox: Raster 0.25 m, Radius 3.50 m, Probe 0.06 m, Kapsel r 0.35 / h 1.90.

**Zusammenfassung**: Collider 309, Meshes 966, unpaired 0 — Findings **P0 0**, **P1 2**

**Killbox 'L1_Wreck_0'**: Punkte 613, blocked-any 4 (0.0 % der Punkte), im Autokennfeld 0 (legitim), Kapselkontakt-an-Soliden 4, Rest-Overlap skipped 159 — weg-geblockt ohne Legitimation: **0** — Schuldverteilung: {  }

## Findings

| P | Collider | Partner | Modus | Befund |
|---|---|---|---|---|
| P1 | `@StaticBody3D@19801` | `L1_Barrel_Flame (+3 Teile)` | proximity-0.29m | Collider enger als Sichtgeometrie um (32.800, 0.000, 1.300) |
| P1 | `L1_B_S1_InBarrel` | `L1_B_S1_InBarrel_1 (+1 Teile)` | colonly-name | Collider enger als Sichtgeometrie um (3.954, 0.530, 8.604) |

## Killbox-Details (weg-blockierte Samples)

| Punkt XZ | Radius | Collider | NormalY | im Kennfeld |
|---|---|---|---|---|
| (40.50, 35.40) | 2.70 | `L1_B_S2_BaseL` | 0.11 | false |
| (40.50, 35.65) | 2.92 | `L1_B_S2_BaseL` | 0.11 | false |
| (40.50, 35.90) | 3.13 | `L1_B_S2_BaseL` | 0.11 | false |
| (40.50, 36.15) | 3.35 | `L1_B_S2_BaseL` | 0.11 | false |
