# Rastro

**Three cars. Your signature.**

Rastro is a garage-only, single-player customization game on the DCS Base
architecture. There are **no races, competitions, driving physics, currency or
unlock gates** in this first version. Every car and every part is free.

The Nissan Cube, Hyundai Sonata and Honda CR-V are available immediately. Each
keeps its own build: paint, wheel design, rim finish, tires, spring/damper kit,
ride height and engine kit. Changes appear in the real 3D workshop.
Mechanical parts also change the displayed **fictional game estimates**, not
manufacturer specifications. Engine kits currently affect data, not a running
engine or a drivable car.

## Running

This repository is the game folder, not a standalone Godot project. It is
consumed at `godot-base\games\rastro` by `jraleman/dcs_games`. Run from the
host's `godot-base` directory with Godot 4.7:

```powershell
godot --path . -- --game=rastro
godot --path . -- --game=all
```

The manifest is discovered automatically. `gameplay.tscn` inherits the shared
`GameShell`, which supplies pause, settings and navigation; Rastro opts out of
countdown/lives rules and never ends a visit automatically. Shared menus,
branding, credits and Saves remain framework-owned.
The shared instructions screen includes a recording of actual garage
customization, inspection, autosaving and portable export.

The `rastro` export feature selects this game and its stable
`DeskCanSaw Games/Rastro` user directory. The host supplies Windows, Web,
Android and iOS presets. A development `--game=rastro` launch selects the game,
not the export feature, and therefore uses the host's developer save directory.
Keep the standalone directory stable after release.

## Controls

| Input | Customize | Inspect |
| --- | --- | --- |
| Keyboard | Tab/arrows, Enter, and the ride-height slider | A/D orbit, W/S raise/lower, Q/E zoom, R frame car; all rebindable |
| Mouse | Click parts and drag the slider | Drag the preview, wheel to zoom, double-click to frame |
| Gamepad | Left stick/D-pad, A | Assigned controller's right stick, shoulders to zoom, Y to frame |
| Touch | Tap parts and drag the slider | Drag the preview, two-finger pinch, or use camera buttons |

Escape, gamepad Start or **Menu** opens the shared pause menu. Frame car only
resets the camera. **Factory reset** asks before resetting the selected car;
other cars stay unchanged. The parts panel scrolls, including with focused
keyboard/gamepad controls. Physical touch targets and text adapt from portrait
phones through short landscape and ultrawide windows, including Interface size.
Idle inspection is static; Reduced motion does not prevent manual inspection.
**Help** reveals camera buttons and guidance. Part/paint editing, primary actions
and save failures remain visible without opening it.

## Saves

`user://rastro_garage.cfg` holds the selected car and one complete build for each
car. Edits autosave after 0.35 seconds; opening the menu, losing window focus or
exiting also flushes pending changes. Failed writes leave the previous save
unchanged and show **Retry**. A damaged or newer save opens an explicitly
read-only factory preview rather than silently overwriting it.

The manifest declares this file for the shared main-menu **Saves** screen, so
backup, restore and delete operate on this garage without touching another
game or any settings. Options and key bindings remain in the framework's
`settings.cfg`.

## Portable car builds, version 1

**Export build** shows copyable JSON; **Import build** validates pasted JSON
before replacing only its named car's build. It does not import models,
resource paths, executable code, scores, ownership or claimed performance.
An invalid import changes nothing and displays its reason.

```json
{
  "format": "dcs.car-build",
  "version": 1,
  "car_id": "nissan_cube",
  "paint_id": "lagoon",
  "wheel_id": "five_spoke",
  "rim_finish_id": "bronze",
  "tire_id": "trail",
  "suspension_id": "rally",
  "ride_height_mm": 35,
  "engine_id": "intake"
}
```

All ten fields are required; unknown fields, versions, cars or parts are
rejected. Builds are limited to 4 KB. `ride_height_mm` is relative to factory,
from -25 through +60 in integer 5 mm steps. See `car_catalog.gd` for the
authoritative part identifiers.

`car_build.gd` recomputes power (kW), mass (kg), power-to-weight (kW/tonne),
tire radius (m), clearance (mm), road/loose-surface grip and spring/damping
multipliers. Paint/rim color do not affect these values. Lightweight wheels
reduce mass; sport/trail tires trade grip and change dimensions; suspension
kits change spring/damping factors; ride height changes clearance; engine kits
change power and mass. No simulated acceleration or competition result is
claimed.

**Cube Trials cannot load these builds yet.** The future adapter can map these
canonical ids to its character ids:

| Portable id | Cube Trials character id |
| --- | --- |
| `nissan_cube` | `cube_car` |
| `hyundai_sonata` | `cube_sonata` |
| `honda_crv` | `cube_crv` |

The future consumer must explicitly decide how to map mechanical tuning into
its own rules; version 1 does not bypass Cube Trials unlocks or alter its
shared handling. Portable text works across separate standalone save
directories without a shared writable garage.

## Ownership and layout

The three self-contained GLBs in `assets\models` are local copies of
DeskCanSaw's original Cube Trials models. There is **no runtime dependency on
another game folder**, no downloaded vehicle asset, and no new renderer or
plugin. The workshop, suspension and aftermarket wheels are original
procedural Compatibility geometry. Vehicle names identify models, without
manufacturer endorsement.

| File | Responsibility |
| --- | --- |
| `game.gd`, `rastro_options.gd` | Manifest, branding, copy, controls and save declaration |
| `gameplay.gd`, `gameplay.tscn` | Shared-shell integration, input adapters and autosave |
| `garage.gd` | Responsive parts controls, confirmations and JSON dialogs |
| `garage_view.gd`, `car_rig.gd` | Isolated 3D workshop, inspection and actual visual modifications |
| `car_catalog.gd`, `car_build.gd` | Parts, validated portable format and derived specifications |
| `garage_state.gd` | Per-car state, protected loads and atomic ConfigFile saves |

## Validation

From `godot-base`:

```powershell
godot --headless --path . --import
godot --headless --path . --script res://games/rastro/tests/car_build_test.gd -- --game=rastro
godot --headless --path . --script res://games/rastro/tests/garage_geometry_test.gd -- --game=rastro
godot --headless --path . --script res://games/rastro/tests/garage_scene_test.gd -- --game=rastro
godot --path . --script res://games/rastro/tests/garage_view_test.gd -- --game=rastro
```

The last suite requires a real Compatibility graphics window. Pass
`--rastro-artifacts=C:\absolute\capture-directory` after `--` to save review
frames. Suites use their own garage files and clean them up. The scene suite
uses synthetic keyboard, assigned/unassigned gamepad and independent touch
events through the real adapters; `input_gameplay_fixture.gd` only supplies a
virtual controller id.

Physical gamepads/mobile touch hardware, signing and platform-specific export
toolchains still need device/release testing. Competitions and Cube Trials
loading are intentionally later work.

The development-only `tools\tutorial_driver.gd` drives the real widgets and
camera input, then verifies the saved and exported build. Re-record through
the host's existing pipeline:

```powershell
pwsh tools\record_tutorials.ps1 -Godot godot -Games rastro -Variants solo
```