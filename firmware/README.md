# Firmware

STM32F303K8 firmware for the LED shelf controller.

## Headline feature — three-timer PWM synthesis

The strip needs a three-level differential waveform (+24V / 0V / −24V) where
**polarity ratio sets colour** (warm vs. cool) and **zero-dwell sets brightness**.
Standard complementary PWM can't produce this — it gives you a single duty cycle,
not independent control of colour ratio *and* a zero-level dwell. So three timers
are combined with a NAND-like gating scheme to build the waveform directly.

<!-- TODO: link the timer configuration source file here (and from the root
     README "PWM generation problem" section) once firmware source lands. -->
<!-- TODO: exact timer/channel assignments unknown until source is committed —
     do not document specific TIMx/CCRy mappings until verified. -->

## Control path

BLE (RNBD350) → UART → firmware. The app sends colour/brightness commands that map
to timer CCR values. Switching runs at 25 kHz so the drive waveform is ultrasonic.

<!-- TODO: document the BLE UART command format (byte layout for colour/brightness)
     once the protocol is finalised in source. -->

## What lands here

- STM32CubeIDE project (or bare CMSIS/HAL source)
- Timer configuration for the three-level waveform synthesis
