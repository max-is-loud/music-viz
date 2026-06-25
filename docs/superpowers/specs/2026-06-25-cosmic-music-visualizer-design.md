# Cosmic Music Visualizer Design

Date: 2026-06-25
Status: Approved for implementation planning

## Summary

Build a native macOS visualizer that behaves like a compressed 2D cosmic
evolution sandbox. The app simulates particles and fields that coalesce into
larger structures, ignite into stars, age, collapse, explode, and seed new
matter. System audio from the selected output device influences the universe by
injecting energy, waves, heat, turbulence, and compression into the simulation.

The simulation is the source of truth. Rendering can exaggerate the state with
rich shaders, bloom, trails, glow, and distortion, but music and shaders should
not fake cosmic events that the simulation state does not support.

## Target Platform

- macOS Tahoe 26 and newer.
- Apple Silicon only.
- Native Swift app shell with Metal compute and render pipelines.
- Modern Core Audio system output capture using audio taps, with a local-only
  audio analysis permission prompt.

References:

- Apple Core Audio taps: https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps
- Apple macOS 26 release notes: https://developer.apple.com/documentation/macos-release-notes/macos-26-release-notes

## Product Goals

- Create a beautiful, simulation-first 2D universe that can run for long
  sessions without feeling like a canned animation.
- Push modern Apple Silicon GPUs with large particle counts, field textures,
  compute passes, and shader-rich rendering.
- React to whatever audio is playing through the system output, including Apple
  Music, Spotify, browser audio, or other players.
- Slow down into a cosmic simmer during silence or low-energy audio rather than
  stopping completely.
- Offer an ambient fullscreen experience by default, with a simulation lab
  available on demand.

## Non-Goals For The First Prototype

- Physically accurate astrophysics.
- 3D rendering.
- Recording or video export.
- MIDI control.
- Plugin architecture.
- Networked or shareable sessions.
- Full scientific units or exact stellar evolution.
- A complex preset manager.

## Experience Model

The app opens into a fullscreen living universe. Matter drifts, accretes,
heats, ignites, collapses, cools, and recycles. When the music is quiet, gravity
and cooling continue at a calmer pace. When the music becomes energetic, the
audio analysis creates pressure waves, turbulence, heat, and compression that
make dramatic but state-consistent events more likely.

The default interface is ambient and minimal. A hidden or collapsible lab panel
can expose controls for simulation, audio analysis, rendering, seeds, reset,
pause, time scale, particle counts, field resolution, debug overlays, and
performance stats.

## Core Architecture

The app is a thin native shell wrapped around a GPU-first frame pipeline.

Swift owns:

- App lifecycle and permissions.
- Fullscreen windowing and display mode behavior.
- Core Audio tap setup.
- Audio analysis coordination.
- Lab UI and app settings.
- Seed, reset, pause, and persistence.

Metal owns:

- Particle buffers.
- Field textures.
- Compute kernels for deposit, field update, audio injection, particle
  integration, and lifecycle transitions.
- Render passes for particles, fields, trails, glow, bloom, distortion, debug
  overlays, and final tonemapping.

The CPU prepares bounded parameters each frame. The GPU performs the heavy
simulation and drawing work.

## Frame Pipeline

```text
system audio -> analyzer -> bounded audio forces
lab controls -> simulation parameters

particles -> deposit density, heat, mass, radiation into fields
fields -> diffuse, decay, flow, pressure, shockwave updates
audio -> inject energy, compression, turbulence, heat, wavefronts
particles -> sample fields and integrate motion
particles -> lifecycle transitions
renderer -> particles, fields, trails, bloom, distortion, overlays
```

The design should avoid direct all-pairs gravity. Particles deposit influence
into grid textures. Compute passes update those fields. Particles sample fields
to move and evolve. This keeps the universe scalable and GPU-friendly.

## Simulation Model

The universe has two cooperating layers.

Particles represent visible matter and identity:

- Dust.
- Plasma.
- Gas clumps.
- Protostars.
- Stars.
- Unstable stars.
- Remnants.
- Ejecta and debris.

Fields represent continuous environment state:

- Density.
- Heat.
- Velocity or flow.
- Pressure.
- Radiation.
- Turbulence.
- Audio shockwaves.

Particles write into fields. Fields push back on particles. Music writes into
fields as bounded energy inputs.

The first lifecycle grammar is:

```text
dust/plasma
-> dense clumps
-> protostars
-> stable stars
-> unstable stars
-> supernova or collapse
-> remnants, shockwaves, and new debris
```

The lifecycle should be stylized, legible, and internally consistent. Early
rules can be simple thresholds around density, heat, mass, age, and fuel. The
rules should be visible in the lab panel so the user can learn how the universe
is behaving.

## Audio Influence

The app captures system output audio so any currently playing source can drive
the simulation. The analyzer extracts:

- Overall energy.
- Bass, low-mid, mid, and high bands.
- Transient hits.
- Spectral brightness.
- Sustained intensity.
- Silence or simmer state.

Signals become bounded simulation inputs:

- Bass drives gravity-like compression pulses and shockwaves.
- Transients drive localized pressure waves or matter disturbances.
- High frequencies drive radiation sparkle, plasma agitation, and fine
  turbulence.
- Sustained energy drives heat, star ignition likelihood, and faster stellar
  aging.
- Silence lowers the time scale, cools the universe, and emphasizes drifting
  accretion.

Audio must not directly trigger canned cosmic events. It changes local and
global conditions, then the simulation decides what can happen.

## Rendering Model

Rendering should make the simulation feel vast, luminous, and alive while still
reading as the output of the underlying state.

Visual layers:

- Particle matter for dust, plasma, ejecta, stars, and remnants.
- Field glow for heat, density, radiation, and shockwaves.
- Motion history through trails, accretion streaks, and expanding shells.
- Post effects such as bloom, tonemapping, chromatic richness, and subtle
  lensing-like distortion.
- Debug overlays for field views, particle types, performance, and audio bands.

The renderer can be more dramatic than the physics. It should not hide or
contradict the simulation.

## UI Model

The app has two postures:

- Ambient cinematic: fullscreen universe, minimal overlay, suitable for leaving
  on while music plays.
- Simulation lab: collapsible controls and debug views for tuning and
  understanding the system.

Initial lab controls:

- Pause and resume.
- Reset with seed.
- Time scale.
- Audio influence strength.
- Audio smoothing.
- Particle count target.
- Field resolution.
- Gravity or compression strength.
- Heat decay.
- Turbulence strength.
- Star ignition threshold.
- Collapse threshold.
- Render intensity.
- Bloom strength.
- Debug overlay selection.

Initial parameter presets are allowed, but they are parameter sets rather than
canned scenes:

- Stellar Nursery.
- Quiet Deep Field.
- Cataclysmic Audio.
- Blackened Remnants.
- High-Energy Plasma.

## Error Handling

- If audio capture permission is denied, the app should continue in no-audio
  simmer mode and show a clear lab-panel status.
- If the audio tap fails after permission is granted, the simulation should keep
  running and the lab should expose the failure state.
- If audio is silent, the analyzer should enter simmer mode instead of sending
  noisy low-level input into the simulation.
- If the GPU workload exceeds the frame budget, the lab should make quality
  controls obvious: particle count, field resolution, render intensity, and
  post-processing.
- If a simulation parameter combination becomes unstable, reset controls should
  recover the universe without restarting the app.

## First Prototype Scope

The first implementation should prove the full loop:

- Swift macOS app shell.
- Metal view rendering fullscreen.
- GPU particle buffer.
- GPU field textures.
- Basic particle motion through fields.
- Particle-to-field density and heat deposit.
- Field decay and diffusion pass.
- Simple star and protostar lifecycle rules.
- System audio capture through Core Audio taps.
- Audio analyzer producing energy, bands, and transients.
- Audio pulses injected into fields.
- Ambient fullscreen mode.
- Basic lab panel with core sliders and debug overlays.
- Bloom, trails, and field glow rendering.
- Seed, reset, pause, and time scale controls.

## Verification Strategy

- Build and run on Apple Silicon macOS Tahoe 26 or newer.
- Verify the app can render a nonblank evolving particle universe.
- Verify silence produces simmering motion rather than total stillness.
- Verify system output audio changes field energy and particle behavior.
- Verify denied audio permission leaves the simulation usable.
- Verify lab controls affect the simulation without requiring restart.
- Use Metal debugging and performance tools to inspect frame timing and GPU
  workload.
- Add focused unit tests where practical for audio smoothing, parameter
  clamping, seed serialization, and lifecycle threshold logic.

## Implementation Notes

- Prefer a Swift app shell with an AppKit-hosted Metal view and a SwiftUI or
  AppKit lab overlay, choosing the UI path that gives the cleanest fullscreen
  and Metal integration.
- Keep simulation constants explicit and clamped so the lab cannot easily
  produce unrecoverable numerical explosions.
- Keep audio analysis local. Do not persist or transmit captured audio.
- Design the first engine so particle and field counts can scale up after the
  first working loop is verified.
