# BigShot

BigShot is an original Godot 4.x 2D side-scrolling arcade-shooter prototype. It uses project-authored code plus layered procedural pixel visuals for the player, four held weapons, four enemy roles, combat effects, a complete fantasy-tech environment, and the three-form Iron Tempest industrial Boss. Reference games inform pacing principles only.

## Play

```bash
godot --path /Users/darkeryi/Documents/BigShot
```

The project opens on a mode selector. Choose `1` for the 20,000 px arcade mission or `2` for an independent ten-wave survival arena. Survival escalates through the existing four enemy roles, places elites on waves 5 and 9, and ends with the three-phase Iron Tempest on wave 10. No Roguelite upgrades are included in this baseline.

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
- Pause audio mix: Master/Music/SFX `−`/`+` and mute controls
- Toggle diagnostics: `F3`
- Camera shake: `F4` cycles 100%, 50%, and OFF
- Replay after completion: `Enter` or controller Start

## Verify

```bash
./scripts/verify_prototype.sh
```

This command runs all prior PVE gates plus mode-selection loading, the three-wave survival prerequisite, the complete ten-wave lifecycle, elite/Boss milestones, Boss-wave death reset, local-record saving, a real-weapon survival playthrough, sprint-jump/roll/grenade compatibility, capped spawning, and the final headless runtime check. `scripts/tools/capture_frame.gd` remains available for graphical capture.

## Scope

The current build contains one complete PVE mission and one independent base ten-wave survival mode; it is not a production-ready content architecture. It intentionally omits crouching, general checkpoints, online play, and Roguelite/progression systems. Survival saves only highest score and best time locally with `ConfigFile`. The pixel UI, portrait, layered player/four weapons, assault/gunner/shield/elite visuals, Iron Tempest Boss, combat effects, PVE environment, survival arena, music, and semantic audio cues are original project-authored procedural assets suitable for continued prototype iteration. See `VISUAL_STYLE.md` and `docs/AUDIO_SOURCES.md`.
