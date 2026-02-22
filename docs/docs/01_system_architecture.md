# System Architecture

The LED shelf lighting system consists of:

- 24V SMPS power brick
- STM32 microcontroller
- N channel MOSFET switching stage
- Four LED strip segments (~1A total load)

## Control Strategy

The STM32 generates high-frequency PWM (25–35 kHz)

Advantages:
- moves switching harmonics outside the audible range
- allows smooth brightness control
- reduces audible noise compared to stock dimmer

