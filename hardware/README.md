# Hardware

Electronics design for the quiet 24V tunable-white LED shelf controller.

The current revision is **V1.1**: black ENIG, 4 layers, octagonal outline. Fabricated and
in transit, not yet assembled. V1 was assembled and working before it was retired
(see the failure section of the [root README](../README.md)).

## Core parts

| Function | Part |
|---|---|
| MCU | STM32F303K8T6 |
| H-bridge gate driver | MP6528 |
| Power FETs (full bridge) | 2× SQJ746ELP (dual N-channel) |
| BLE module | RNBD350 |
| Logic-rail buck | MP2459 |

The strip is driven as a three-level differential waveform (+24V / 0V / -24V) at
25 kHz, so the fundamental and its harmonics sit above the audible band.

## What lands here

- `schematic_v1_1.pdf` (schematic export) <!-- TODO: owner to add; then link from root README design section -->
- Board renders (top/bottom)
- BOM

<!-- TODO: add gerber/render exports and BOM once V1.1 is documented -->
