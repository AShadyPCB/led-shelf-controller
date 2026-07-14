<p align="center">
  <img src="media/IMAGES/v1_1_pcb_hero.png" width="700" alt="Shady Electronics LED Shelf Controller v1.1, black ENIG 4-layer PCB">
</p>

<h1 align="center">LED Shelf Controller</h1>

<p align="center">
The stock controller on my LED shelf whined, and it got louder as I dimmed it.<br>
This is how I worked out why, and the silent replacement I built to fix it:<br>
a 25&nbsp;kHz H-bridge driver with BLE control from my phone, on a custom 4-layer board.
</p>

---

## The Problem

The shelf is a 24 V tunable-white LED strip driven by an off-the-shelf controller. At full brightness it puts out a faint high-pitched whine. Dim it to a normal, usable level and the whine gets worse, turning into a piercing tone that's hard to ignore once you've heard it.

<!-- TODO: embed hiss demo clip here (drag-drop .mp4 into web editor, <10MB, caption "🔊 sound on") -->

<p align="center">
  <img src="media/IMAGES/og_board_closeup.jpeg" width="600" alt="Original controller PCB, opened up">
</p>

So I opened it up and put it on the bench.

## Reverse Engineering the Original

<p align="center">
  <img src="media/IMAGES/og_current_draw_measurement.jpeg" width="600" alt="Measuring strip current draw at max brightness">
</p>

Probing the two output lines (SHA and SHB) showed how it works. The controller takes 24 V in from the brick, but it drives the strip differentially: the two lines swap polarity, so the strip sees either +24 V or -24 V across it. The strip has two anti-parallel LED strings, so one polarity lights the warm (orange) LEDs and the other lights the cool white ones.

| Mode | Capture |
|---|---|
| Fully warm, output dwells on one polarity | <img src="media/IMAGES/og_waveform_fully_warm.png" width="420"> |
| Fully cool, output dwells on the opposite polarity | <img src="media/IMAGES/og_waveform_fully_cool.png" width="420"> |
| Mixed colour, SHA/SHB alternating | <img src="media/IMAGES/og_waveform_sha_shb_closeup.png" width="420"> |

Colour comes from the ratio of time spent at +24 V versus -24 V. Brightness comes from inserting 0 V dwell into the waveform: the more zero time, the dimmer the strip.

Here is the differential (SHA-SHB) measurement at max brightness in 50/50 colour mode:

<p align="center">
  <img src="media/IMAGES/og_fft_5050_max_differential.png" width="600" alt="Differential ±24V waveform across the strip at max brightness">
</p>

### Why it whines

The switching fundamental sits at 2 kHz, right in the audible range where our hearing is most sensitive. An FFT of the output shows that fundamental plus a comb of harmonics running up through the audible band:

<p align="center">
  <img src="media/IMAGES/og_fft_5050_sha_shb.png" width="600" alt="FFT of original controller output: 2kHz fundamental plus audible harmonics">
</p>

The dimming behaviour makes sense in the frequency domain too. Adding 0 V dwell for brightness control breaks the symmetry of the waveform, and that pushes energy into extra harmonics. At low brightness the 4th, 8th, and 12th harmonics grow noticeably:

<p align="center">
  <img src="media/IMAGES/og_waveform_lowbrightness.png" width="420" alt="Time-domain waveform at low brightness showing zero-dwell insertion">
  <img src="media/IMAGES/og_fft_lowbrightness_harmonics.png" width="420" alt="FFT at low brightness: 4th, 8th and 12th harmonics increased">
</p>

So there is more audible harmonic energy at exactly the brightness you'd actually run the shelf at. That is the whine. The magnetics and ceramic caps on the board turn that electrical spectrum into an acoustic one.

The fix follows directly: keep the same drive scheme, but move the fundamental above the range human ears can hear.

## The Replacement Design

A full bridge (H-bridge) is the natural way to recreate the ±24 V / 0 V drive. It's the same topology used in motor drives. It switches the strip between +24 V and the reversed polarity, and it can hold the strip at 0 V on its own. I run the PWM fundamental at 25 kHz, which puts it and every harmonic above it out of the audible band.

<!-- TODO: media/IMAGES/hbridge_gate_drive_diagram.png - Inkscape block diagram: STM32 -> MP6528 -> 4x FET bridge -> strip, rails labeled -->

| Function | Part | Notes |
|---|---|---|
| Gate driver | **MP6528GR-Z** | 5-60 V H-bridge gate driver for four N-channel FETs. Bootstrap high-side supply with internal charge pump for 100 % duty operation, adjustable dead-time via DT pin, OCP, UVLO. QFN-28 with exposed pad. |
| Power stage | **SQJ746ELP** ×2 | Vishay dual N-channel 40 V TrenchFET, 8.8 mΩ, PowerPAK SO-8L. Two dual packages make up the full bridge. AEC-Q101 automotive-qualified. |
| MCU | **STM32F303K8T6** | Cortex-M4F at 72 MHz. Advanced-control timer with complementary outputs and hardware dead-time insertion generates the bridge PWM. |
| BLE | **RNBD350PE-I/100** | Microchip Bluetooth LE 5.2 certified module. Talks to the STM32 over UART; the iOS app sends colour and brightness, and the MCU maps them to timer compare (CCR) values. |
| Logic rail | **MP2459GJ-Z** | 55 V-input, 0.5 A, 480 kHz buck stepping the 24 V brick down to the logic rail. |

### The PWM generation problem

Standard complementary PWM only gives two states per leg, so it can't directly produce the three-level (+24 V / 0 V / -24 V) waveform while controlling the colour ratio and the zero-dwell brightness independently. My workaround uses three timers. A third timer gates the bridge legs, a NAND-like combination of the two base PWM channels, to insert the 0 V states without disturbing the polarity ratio.

<!-- TODO: media/IMAGES/timer_scheme.png - matplotlib figure: two complementary PWM channels + gating timer + resulting three-level output -->

Control path: iOS app (SwiftUI) → BLE → RNBD350 → UART → STM32 → timer CCR updates → gate driver → bridge → strip.

## Build and Bring-up (Version 1)

<p align="center">
  <img src="media/IMAGES/v1_pcb_assembled.jpeg" width="600" alt="Version 1 assembled PCB">
</p>

I hand-assembled Version 1, QFN gate driver and all, and brought it up on the bench. It worked: clean PWM on the bridge, and the strip ran silently at 25 kHz.

<p align="center">
  <img src="media/IMAGES/v1_bench_working_pwm.jpeg" width="600" alt="Version 1 on the bench producing clean PWM">
</p>

## What Went Wrong Along the Way

**A hidden open joint under the QFN.** The board powered up, but the bridge output was distorted in a way that looked like half a dozen different faults at once. The real cause was the MP6528's DT (dead-time) pin, which wasn't making contact with its programming resistor. One bad joint under the QFN from an uneven hot-air reflow. Finding it took much longer than fixing it. Reflowing on a hot plate gave reliable joints and the distortion went away.

<p align="center">
  <img src="media/IMAGES/fault_dtpin_distorted_pwm.png" width="600" alt="Distorted PWM caused by a floating dead-time pin">
</p>

**A trace too close to a FET pad.** V1 ran a thin trace right up against an inner MOSFET pad, which caused solder bridges during assembly. I ended up chasing those down under the microscope.

<p align="center">
  <img src="media/IMAGES/fault_trace_fet_pad_short.jpg" width="600" alt="V1 layout: trace routed too close to FET pad, causing shorts">
</p>

**Probing a live switch node killed the driver.** While I was capturing SHA/SHB waveforms on the working V1 board, the gate driver died, almost certainly from a momentary probe or ground-clip short on a live switch node. The rework to replace it bridged, and pulling the dead part lifted the QFN pads with it. What I took from it: use spring-tip probe grounds, current-limit the first power-up, and leave the risky measurements for last, once the photos are already taken.

## Version 1.1

V1.1 (the black ENIG board at the top) folds those lessons in: fixed clearances around the FET pads, a general layout cleanup, and the full Shady Electronics treatment with a 4-layer stackup, a via-stitched perimeter, and a custom octagonal outline.

<!-- TODO: assembled v1.1 photos when boards arrive -->
<!-- TODO: v1.1 output FFT at 25kHz + stacked comparison vs original 2kHz FFT with audible band shaded -->
<!-- TODO: BLE demo gif/clip -->

## Status

- [x] Original controller reverse-engineered, noise mechanism identified
- [x] V1 designed, assembled, verified silent at 25 kHz
- [x] V1.1 layout revisions, fabbed
- [ ] V1.1 assembly and bring-up
- [ ] Before/after acoustic and FFT comparison
- [ ] Full video writeup

## Repo Layout

```
hardware/   schematics, layout notes, BOM
firmware/   STM32 project (timer scheme, BLE UART protocol)
media/      scope captures, photos, diagrams
```
