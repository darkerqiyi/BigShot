# BigShot

BigShot is an original Godot 4.7 2D side-scrolling arcade-shooter prototype. It uses project-authored code plus layered procedural pixel visuals for the player, four held weapons, four enemy roles, combat effects, a complete fantasy-tech environment, and the three-form Iron Tempest industrial Boss. Reference games inform pacing principles only.

Current packaged-demo version: **0.9.0-demo**.

## Play

```bash
godot --path /Users/darkeryi/Documents/BigShot
```

The project opens on a mode selector. Choose `1` for the 20,000 px arcade mission or `2` to open the survival-map selector. Survival offers the original open industrial district and the tighter `SUBLEVEL-09` underground transport station; both share the same ten-wave lifecycle, waves 2/4/6/8 upgrade choices, up to two run-local field events on waves 3/5/7, existing four enemy roles, and the three-phase Iron Tempest finale.

The cold-start flow is title → main menu → mode/map selection → short deployment countdown. Settings persist in `user://settings.cfg`; display, Master/Music/SFX/UI levels, presentation options, and supported keyboard bindings can be restored to defaults from the settings page. A compact first-run tutorial completes step-by-step and can also be reset there.

## Controls

- Move: `A` / `D` or arrow keys; controller left stick
- Sprint: hold left or right `Shift` with horizontal movement; stamina recovers after a short delay
- Ground roll: double-tap `A` or `D` (projectile evade; does not avoid melee or environment damage)
- Jump: `Space`; controller south face button
- Aim: mouse; controller right stick
- Fire: left mouse or `J`; controller west face button
- Charge/throw grenade: hold/release right mouse (`K` remains an alternate mapped action); capacity three with finite route/Boss-cache resupply
- Select weapon: `1` auto rifle, `2` scattergun, `3` rail lance, `4` sidearm
- Reload: `R`; controller north face button
- Pause/resume: `Escape`
- Settings: available from the main menu and pause screen; changes apply immediately and persist locally
- Toggle diagnostics: `F3`
- Camera shake: `F4` cycles 100%, 50%, and OFF
- Replay after completion: `Enter` or controller Start

## Verify

```bash
./scripts/verify_prototype.sh
```

This command runs all prior PVE gates plus mode/map-selection loading, both maps' complete ten-wave lifecycle, the three-wave prerequisite, elite/Boss milestones, deterministic two-event scheduling, Supply Drop choices, bounty success/failure, bounded emergency reinforcements, event-death reset, upgrade/event isolation, steam-hazard behavior, local-record saving, real-weapon survival playthroughs, sprint-jump/roll/grenade compatibility, capped spawning, and the final headless runtime check. `scripts/tools/capture_frame.gd` and `scripts/tools/capture_survival_map.gd` remain available for graphical capture.

## Export

Godot export presets are included for `macOS Demo` and `Windows Desktop Demo`:

```bash
mkdir -p builds/macos builds/windows
godot --headless --path /Users/darkeryi/Documents/BigShot --export-release "macOS Demo"
godot --headless --path /Users/darkeryi/Documents/BigShot --export-release "Windows Desktop Demo"
```

Godot 4.7 export templates must be installed locally first (`Editor → Manage Export Templates`). macOS signing/notarization and Windows code signing are intentionally not configured for this unsigned prototype handoff.

The release-candidate manual matrix is in [`docs/RELEASE_QA.md`](docs/RELEASE_QA.md).

## Scope

The current build contains one complete PVE mission and one independent ten-wave survival mode with two configured maps and run-local upgrades; it is not a production-ready content architecture. It intentionally omits crouching, general checkpoints, online play, and permanent progression. Survival saves only highest score and best time locally with `ConfigFile`; all upgrades reset on death/exit and never modify PVE. The pixel UI, portrait, layered player/four weapons, assault/gunner/shield/elite visuals, Iron Tempest Boss, combat effects, both survival environments, music, and semantic audio cues are original project-authored procedural assets suitable for continued prototype iteration. See `VISUAL_STYLE.md` and `docs/AUDIO_SOURCES.md`.
The current build contains one complete PVE mission and one independent base ten-wave survival mode（Roguelike）; it is not a production-ready content architecture. It intentionally omits crouching, general checkpoints, online play, and Roguelite/progression systems. Survival saves only highest score and best time locally with `ConfigFile`. The pixel UI, portrait, layered player/four weapons, assault/gunner/shield/elite visuals, Iron Tempest Boss, combat effects, PVE environment, survival arena, music, and semantic audio cues are original project-authored procedural assets suitable for continued prototype iteration. See `VISUAL_STYLE.md` and `docs/AUDIO_SOURCES.md`.
