# MusicViz

Native macOS Tahoe 26+, Apple Silicon-only cosmic music visualizer.

MusicViz is a Swift + Metal experiment: a simulation-first 2D universe where
particles and fields evolve into clumps, protostars, stars, remnants, and
shockwaves. Audio analysis feeds energy into the simulation rather than playing
canned animations.

## Requirements

- macOS Tahoe 26 or newer
- Apple Silicon Mac
- Xcode 26 command line tools

## Build

```bash
make app
```

## Run

```bash
open .build/MusicViz.app
```

## Test

```bash
swift test
```

## Controls

- `l`: show or hide the simulation lab
- Space: toggle the lab pause state

## Audio

The prototype uses a Core Audio system output tap so music from Apple Music,
Spotify, browser audio, or other players can drive the universe. If permission
is denied or the tap fails, the app falls back to a synthetic audio source and
keeps the simulation usable.
