# LED Shelf Controller Project

This project redesigns a commercial LED shelf lighting controller to eliminate audible buzzing and power brick hiss.

## Observed Issues
- Audible buzzing at partial brightness from PWM dimming
- Power supply brick hissing at maximum brightness

## Design Approach
A custom STM32 controller generates high frequency PWM (~30 kHz) and drives the LED strips using a MOSFET switching stage.

The system also limits maximum duty cycle to avoid noisy operating regions in the SMPS power supply.

## Goals
- Eliminate audible noise
- Improve brightness control and add features/functionality
- Document oscilloscope and FFT measurements
