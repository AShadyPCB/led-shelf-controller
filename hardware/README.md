# Hardware

This folder will contain hardware design info.

Planned contents:
- schematics (PDF + source files)
- PCB layout (optional)
- BOM
- wiring diagram

## 24V Polarity-Reversing LED Pad H-Bridge (MOSFET)

The LED pad/load sits in the center of a full H-bridge so the applied polarity can be switched between `+24V` and `-24V` by alternating diagonal MOSFET pairs.

```text
                         +24V BUS
                           |
                    .------'------.
                    |             |
               Q1 (P-MOS)    Q2 (P-MOS)
                    |             |
                    o-----[ LED PAD ]-----o
                    |                     |
               Q3 (N-MOS)          Q4 (N-MOS)
                    |                     |
                    '------. .------------'
                           | |
                          GND (0V)

Switching states:
- +24V across LED pad (left -> right):    Q1 + Q4 ON, Q2 + Q3 OFF
- -24V across LED pad (right -> left):    Q2 + Q3 ON, Q1 + Q4 OFF
- Off / high-Z: all MOSFETs OFF

Important:
- Never turn ON Q1+Q3 (left leg shoot-through) or Q2+Q4 (right leg shoot-through) together.
- Add dead-time when changing states.
- Use proper gate drivers for high-side MOSFETs and include gate resistors.
- Add flyback/transient protection appropriate for wiring inductance and LED strip behavior.
```
