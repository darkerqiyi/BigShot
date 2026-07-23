# BigShot 0.9.0 Demo Release QA

Use this checklist after installing the matching Godot 4.7 export templates and before distributing a build. Record platform, input device, resolution, result, and any issue for every run.

## Automated gate

1. Run `./scripts/verify_prototype.sh`; require `PROTOTYPE_VERIFY_PASS` and no project `SCRIPT ERROR`, parse error, or missing resource.
2. Export `macOS Demo` and `Windows Desktop Demo`; launch each resulting package on its target platform.
3. Confirm the release build starts with diagnostics hidden and contains no `DEBUG` presentation.

## Cold-start and settings

4. Cold start: title → main menu → settings. Change display, Master/Music/SFX/UI volume, shake, damage numbers, flash, hints, and one supported key.
5. Quit and relaunch. Confirm settings persist, then restore defaults and confirm critical key conflicts are rejected.
6. Open Controls, return with Escape, and verify mouse/keyboard focus never selects two buttons.

## PVE

7. Start PVE, complete the deployment countdown, move/jump/sprint/roll/throw, switch and fire all four weapons, pause/resume, then finish the Boss and inspect settlement.
8. Die once before the Boss and once during the Boss. Confirm the correct retry state and that no projectile, audio, UI, event, or input lock survives.

## Survival — both maps

9. Complete Industrial District with one output-oriented Build. Trigger an upgrade at waves 2/4/6/8 and confirm no event UI overlaps it.
10. Complete `SUBLEVEL-09` with a mobility/grenade-oriented Build. Verify platforms, steam warnings, spawn safety, camera bounds, and input restoration after every overlay.
11. Across the two runs, force or naturally observe Supply Drop, Elite Bounty success/failure, and Emergency Reinforcements. Confirm at most two distinct events occur per run and none persists into the Boss.
12. Verify wave 10 Boss, survival/Boss HUD layering, victory statistics, replay, reselect map, and main-menu return.
13. Intentionally fail survival during an event, retry, and alternate maps twice. Confirm upgrades, events, scores, timers, hazards, player resources, and controls reset.

## Presentation, compatibility, and soak

14. Repeat a representative combat segment at 1280×720, 1920×1080, 2560×1440, fullscreen, and windowed. Check pixel clarity, HUD bounds, mouse aim, damage numbers, audio peaks, warnings, and camera comfort.
15. Play at least three consecutive runs without restarting the application. Record frame-time spikes, node/object growth, audio accumulation, controller behavior, and any shutdown leak warning.

Release status is **PASS** only when both exported packages launch and all applicable manual rows above are signed off. Missing export templates, platform signing, or physical-controller evidence must remain explicit rather than inferred from headless tests.
