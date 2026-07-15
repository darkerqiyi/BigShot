# BigShot

BigShot is an original Godot 4.x 2D side-scrolling arcade-shooter prototype. It uses project-authored code plus layered procedural pixel visuals for the player, four held weapons, four enemy roles, combat effects, a complete fantasy-tech environment, and the three-form Iron Tempest industrial Boss. Reference games inform pacing principles only.

## Play

```bash
godot --path /Users/darkeryi/Documents/BigShot
```

Advance through a 20,000 px arcade mission with four gated sectors and eleven mixed waves, use moving platforms and field supplies, then enter the locked command arena and defeat the three-phase Iron Tempest boss. A normal-stage death restarts the mission; a Boss-stage death restores a clean, fully supplied Boss checkpoint after a short delay.

## Controls

- Move: `A` / `D` or arrow keys; controller left stick
- Jump: `Space`; controller south face button
- Aim: mouse; controller right stick
- Fire: left mouse or `J`; controller west face button
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

This command runs Phase 0 regression checks, deterministic horizontal-motion checks, end-to-end prototype smoke tests, four-weapon switching/ballistics tests, enemy/Boss lifecycle tests, combat-character visual contracts, pixel UI/multi-resolution tests, Boss intro/active/phase/defeat UI-flow tests, eight-bus audio/music/voice-limit/spatial-mix-control tests, player animation/muzzle contracts, combat-feedback caps/tiers/cleanup tests, exact environment/collision/encounter contracts, layered Boss-art/state/muzzle contracts, Boss-checkpoint restart verification, encounter-concurrency/readability checks, a complete mixed-weapon scripted playthrough, and a 120-frame headless runtime check. `scripts/tools/capture_frame.gd` also captures four fire signatures, hit tiers, layered environments, character lineups, all three Boss forms, compact HUD states, pause audio controls, attack telegraphs, transitions, death, and settlement.

## Scope

The current build is a complete playable mission prototype, not a production-ready content architecture. It intentionally omits crouching, checkpoints outside the Boss retry point, saved progress, online play, and progression systems. The pixel UI, portrait, layered player/four weapons, assault/gunner/shield/elite visuals, Iron Tempest Boss, muzzle flashes, tracers, impacts, warning accents, sky, city, transit deck, platforms, props, arena, mission gates, field pickups, hazards, two music loops, and 64 semantic audio cues are original project-authored procedural assets suitable for continued prototype iteration. The engine-default font remains replaceable, and the audio event layer supports later mastered-asset replacement. See `VISUAL_STYLE.md` for the single visual specification and `docs/AUDIO_SOURCES.md` for audio provenance.
