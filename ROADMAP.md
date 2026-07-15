# BigShot Development Roadmap

This is the project's only roadmap. Progress is advanced one small, complete, verified slice at a time. Each phase must leave the repository runnable and must not borrow protected code, art, audio, names, characters, or level layouts from reference games.

## Product guardrails

- Original 2D side-scrolling run-and-gun game built with Godot 4.7.
- Arcade-first controls with keyboard/mouse and gamepad support.
- Single-player first; gameplay ownership and input APIs should not prevent later local co-op.
- The first vertical slice eventually includes movement, jump, crouch, shooting, throwable, three enemy archetypes, one advancing level, and a small boss.
- Feel and encounter readability have priority over content volume or progression systems.
- No online multiplayer, deep equipment progression, large cast, or large story system before the vertical slice is proven.

## Reference-derived design principles

Only abstract patterns are retained: simple controls under pressure, fast run-and-gun pacing, distinct weapon behavior, readable enemy projectiles, terrain-aware fights, and strong audiovisual confirmation. `docs/REFERENCE_NOTES.md` records sources and the originality boundary.

## Rapid playable prototype milestone

Status: **Pass** on 2026-07-13.

The user explicitly authorized a one-session playable prototype spanning the earlier production gates. This milestone does not declare every detailed production-phase acceptance item complete; it proves the following end-to-end loop:

- Move, jump, mouse/right-stick aim, automatic fire, reload, damage, death, and fast restart.
- Player projectiles damage and kill activation-gated assault, gunner, shield, and elite enemies before an independent Boss.
- Four advancing encounters across a 4300 px original gray-box level, followed by a locked three-phase Boss arena and settlement state.
- Horizontal camera follow, procedural far/mid/front art layers, muzzle flash, projectile trails, hit sparks, flash, knockback, camera shake, health/ammo/objective/score UI.
- Automated regression and gameplay smoke tests plus a real 1280×720 graphical render capture.

Primary verification: `./scripts/verify_prototype.sh`.

Focused experience polish completed 2026-07-13:

- Rifle/heavy shots now have explicit 0.32/0.48-second visual wind-ups before projectile creation.
- Weapon-body recoil, directional camera recoil, larger damaging-hit sparks, stronger knockback, and longer enemy hit flash were coordinated into one firing rhythm.
- Diagnostics now start hidden and foreground occluders are sparser/lighter; F3 access remains.
- Automated death-to-reload verification now proves a fresh live, full-health run is created after failure.

Vertical-slice core-feel pass completed 2026-07-13:

- Stable ground parameters were preserved; distinct air-control acceleration/deceleration/turn values and a landing squash/dust/camera cue were added.
- A lightweight procedural SFX node now covers weapon, hit tier, enemy warning, hurt, reload, landing, kill, and mission cues without external assets.
- Every fourth automatic round is an accent round, producing a visible/audible tier between normal hit and kill feedback.
- Camera framing now blends movement look-ahead with restrained aim-direction space and smooths the combined offset within level bounds.
- Actively tuned values are centralized in `scripts/config/game_tuning.gd`; no general-purpose framework was introduced.

Four-weapon system pass completed 2026-07-13:

- Number keys 1–4 select auto rifle, scattergun, rail lance, and sidearm through one weapon inventory/state node; switching cancels reload and replaces the active cooldown without creating parallel weapon instances.
- A centralized weapon catalog owns damage, interval, projectile speed/count, spread, recoil, shake, knockback, range/falloff, penetration, fire mode, movement/air accuracy, magazine, reload, color, and muzzle scale.
- Shared continuous-ray projectiles now support configurable distance falloff and bounded penetration. The rail lance passes through two normal targets but stops after damaging a heavy; the scattergun aggregates same-frame hit feedback and enemy death remains idempotent.
- Four persistent HUD slots, immediate active highlighting, distinct weapon silhouettes/colors/muzzle scale, procedural weapon cues, and F3 weapon diagnostics provide switching and balancing feedback.
- `tests/weapon_system_test.gd` verifies all four keys, same-slot stability, held-fire isolation, shotgun spread/falloff/single-death, sniper penetration/elite-stop, sidearm precision, HUD updates, and sniper camera space.

Enemy diversity, staged encounters, and Boss pass completed 2026-07-13:

- Nine regular enemies are divided into four activation-gated encounters: assault teaching, assault/gunner cross-pressure, shield/gunner defense break, and elite/assault transition. Dormant enemies cannot attack before the player reaches their segment.
- Assault, gunner, shield, and elite roles share explicit activation/telegraph/recovery/stagger/death contracts while retaining distinct movement, warnings, silhouettes, colors, weapons, health, and attack rules.
- Projectiles now pass a minimal hit context containing weapon, direction, team, and impact strength. Shield front reduction/opening and elite stagger use that context without duplicating collision or damage systems.
- The original Iron Tempest Boss has an independent scene/state scheduler, three threshold phases, projectile volley, warned charge, warned ground zones, bounded phase-two summons, transition invulnerability, arena lock, danger cleanup, and final settlement.
- The screen-space Boss HUD is signal-driven, hidden outside battle, responsive between player/score panels, and includes immediate health, delayed-loss health, numeric total, phase color, and 65%/30% marks.
- Automated coverage now verifies every enemy contract, Boss phases/UI/attack alternation/summon cap/penetration stop/multi-pellet death/cleanup/settlement, plus death during phase two restoring a clean initial scene.

Pixel visual system and core UI pass completed 2026-07-13:

- The authored 1280×720 logical viewport is preserved, with nearest texture filtering, pixel-snapped 2D transforms/vertices, aspect-preserving stretch, and rounded camera/parallax presentation positions.
- `VISUAL_STYLE.md` is the single visual specification for the bright fantasy-tech palette, pixel grid, spacing, borders, typography, motion, asset naming, and originality boundary.
- One centralized pixel theme now styles panels, buttons, slots, labels, player health, the immediate/delayed Boss bars, and pause/death/settlement overlays.
- The player portrait and four weapon icons are original procedural pixel drawings. Weapon selection, ammo, health feedback, Boss phases, restart reset, and overlay state are executable-test contracts rather than decorative mockups.
- Real graphical captures at 1280×720, 1920×1080, and 2560×1440 confirm anchored screen-space UI and aspect-stable composition; automated coverage also includes 2560×1080 ultrawide bounds.

Player pixel character, four held weapons, and action-animation pass completed 2026-07-13:

- The unchanged 34×64 collision body is now separated from `PlayerVisual`, a procedural `BodySprite`, layered `WeaponPivot`, four scene-readable weapons, per-weapon `MuzzlePoint`, and visual-only effects.
- The original teal/gold/deep-blue character has a helmet, visor, face, scarf, torso, belt, legs, and boots on the project 4 px construction grid; it no longer reads as one geometric block.
- Idle, run, jump, fall, land, shoot/recoil, hurt, and death are coordinated as visual states. Shoot layers over locomotion; hurt is short priority feedback; death suppresses normal weapon animation without delaying the existing restart.
- Facing is redrawn and weapon rotation is computed without negative scale. Projectile origins now come from the active visual muzzle marker while spread, direction, damage, recoil physics, and fire timing remain unchanged.
- Automated coverage locks the collision/movement/health baseline, node separation, all action states, bidirectional/extreme aim, four muzzle lengths/recoil profiles, muzzle-origin equality, and clean restart state.

Combat-character visual unification pass completed 2026-07-13:

- Player visibility increased to 125% on the existing 4 px construction grid with an -8 px foot compensation; the 34×64 collision shape, camera, movement, jump, weapon, and damage contracts are unchanged.
- Assault, gunner, shield, and elite enemies now use original role-specific pixel silhouettes instead of red rectangles. All share the player outline density and animation rhythm while using a restrained warm hostile palette.
- Enemy locomotion, warning, attack, recovery, guard opening, stagger, hurt, block, and death poses read existing AI states/timers. Visual code never emits damage or changes behavioral timers.
- Gunner/elite projectile origins now use the live pixel muzzle marker at the same baseline offset. Facing redraws geometry without negative scale; shield block/break and elite heavy-hit states follow the real damage rules.
- Automated tests lock collision, speed, health, telegraph, muzzle, shield, stagger, death, restart, Boss-summon, and full-flow contracts. Graphical captures verify the five-character hierarchy and warnings at 720p, 1080p, and 1440p.

Combat presentation and pixel-effects pass completed 2026-07-13:

- Four weapon-specific pixel muzzle flashes and projectile signatures now distinguish stable rifle rhythm, wide shotgun force, long rail-lance precision, and light sidearm snap without changing ballistic data.
- Projectile hit details report the result already decided by enemy/Boss damage code. A shared effect renderer presents terrain, normal, heavy, block, guard break, light kill, heavy kill, player hurt, and restrained Boss reactions without becoming a damage source.
- One lightweight feedback controller owns profile caps, same-frame merging, local peak-frame emphasis, and a 100%/50%/OFF F4 shake control. It never changes global time scale; shotgun pellets preserve multiple impact points while sharing one camera/audio response.
- Enemy telegraph poses now add role-specific direction pixels, ground hazards use bounded pixel warning bands, Boss normal hits no longer flash the full body, and foreground posts were reduced so warnings/tracers retain priority.
- Decorative casings are capped at 12 and clean within 0.48 seconds. Automated coverage locks unchanged damage/fire interval/projectile speed plus feedback tiers, caps, cleanup, restart, and full-flow regression.

Scene pixelization and environment-depth pass completed 2026-07-13:

- The original 1280×720 framing now renders a stepped pixel sky, stars/clouds/sun, two far-ridge bands, modular fantasy-tech city silhouettes, playable transit-deck modules, collision-aligned platforms, supply consoles, route markers, a distinct command arena, pixel Boss gate, and exit beacon.
- Far/mid/play/front separation retains the existing -90/-70/-10/80 z-order and 0.15/0.45/1.15 parallax factors. Layer coverage extends beyond the 4300 px camera route and positions are rounded to prevent scrolling seams and subpixel shimmer.
- All floor, wall, platform, Boss-gate, camera, enemy spawn/activation, Boss spawn, and arena logic coordinates are unchanged. A new executable environment contract locks these values and rejects smooth circle/arc/line primitives in world art scripts.
- Foreground poles/cables were replaced by sparse low crystal-grass clusters beginning at y=568, preserving depth without crossing character bodies, projectiles, or telegraphs.
- Real graphical captures at 720p, 1080p, and 1440p confirm the new layers remain sharp and HUD/character/telegraph priorities survive the added detail.

Iron Tempest formal visual and phase-presentation pass completed 2026-07-14:

- The former purple block is replaced by an original low-center-of-gravity industrial war machine with articulated feet, reactor hull, sensor crown, protected diamond core, asymmetric ram arm, and directional cannon.
- `BossVisual` is separated into shadow, lower body, main body, front armor, core, two weapons, finite damage effects, exact muzzle markers, and ground-contact effects. Visual code reads authoritative Boss state/timers and never emits damage or changes AI timing.
- Phase I keeps both shoulder plates and a protected core; Phase II loses one plate, exposes a larger core, and adds capped steam/electric damage; Phase III removes most armor, enlarges/pulses the overload core, and increases bounded short-circuit effects.
- Volley, charge, and area attacks now have distinct timer-bound poses and warnings. Projectile origins remain exactly `(-62,-26)` / `(62,-26)`, charge/area ranges and all attack values remain unchanged, and phase changes remain one-shot at 65%/30%.
- Intro uses the existing 0.9-second recovery window; phase conversion uses the existing 0.85-second invulnerability window; the 0.85-second staged shutdown fits the existing danger cleanup and settlement delay. The Boss HUD adds concise armored/exposed/overload labels without changing its signal-driven layout.
- `tests/boss_visual_test.gd` locks collision, layer structure, muzzle positions, three forms, telegraph binding, local hit feedback, and idempotent death in the primary verification command.

Boss-flow HUD hierarchy and responsive-layout pass completed 2026-07-14:

- Boss UI now has five lightweight presentation states: Hidden, Intro, Active, PhaseTransition, and Defeated. The central intro title clears before combat presentation becomes active, phase changes use a compact top toast, and settlement replaces all transient Boss messaging.
- Long-lived duplicate Boss text was removed. During active combat the only permanent Boss identity is the top health panel; mission updates, intro identity, phase changes, and defeat are time-bounded messages.
- The Boss bar is 15% shorter, integrates exact 65%/30% pixel markers into the health track, retains immediate/delayed layers, and displays one concise phase label without repeated percentage text.
- Player, weapon, and score panels were reduced to 296×96, 252×128, and 160×36 logical pixels. Their combined footprint with the Boss bar fell from about 15.5% to 11.5% of the 1280×720 frame while preserving health, current weapon/ammo, four switch slots, and score.
- The full control strip now hides after four seconds or first gameplay input, never persists into the Boss encounter, and can be configured to remain visible. Debug help is appended only in debug builds; the pause overlay retains a compact control reference.
- `tests/boss_ui_flow_test.gd` verifies title timing, pause-safe fading, active hierarchy, one-shot phase notices, objective suppression, defeat/settlement cleanup, and control auto-hide. Multi-resolution tests cover 720p, 1080p, 1440p, and a synthetic 2560×1080 ultrawide viewport.

Audio, music, and final-experience pass completed 2026-07-14:

- The former one-node temporary-player SFX implementation is now a bounded procedural audio director. `Master`, `Music`, `SFX`, `Weapons`, `Player`, `Enemies`, `Boss`, and `UI` buses provide independent semantic routing, with a -1 dB Master limiter and conservative source headroom.
- Sixty-four original runtime-generated cues distinguish all four weapons and mechanical/reload layers, empty fire, movement/landing/low-health state, normal/heavy/wall impacts, shield block/break, enemy actions and deaths, Boss intro/landing/phases/warnings/releases/layered death, and pause/hover/adjust/confirm/completion UI events.
- A fixed 20-voice pool, per-cue cooldown, per-cue concurrency, event priority, and low-priority voice stealing prevent automatic fire, shotgun pellets, penetration hits, and simultaneous deaths from creating unbounded players or runaway peaks.
- World requests use bounded distance attenuation with a louder floor for important telegraphs. Two original procedural loop tracks provide a restrained fantasy-tech level pulse and a faster industrial Boss pulse; Boss entry crossfades tracks, key semantic events briefly duck music, pause ducks rather than desynchronizes it, completion fades the loop, and restart restores the level track.
- The pause panel exposes Master/Music/SFX 10% steps and mute controls. Values update the real buses immediately and survive scene reloads for the current application session without introducing a save/progression system.
- `tests/audio_system_test.gd` verifies bus routing, limiter ownership, source peak headroom, cue roles, event wiring, spatial floors, track switching, fixed voice count, dense-event rejection, semantic/pause ducking, and mix controls. Restart verification also proves session mix retention.

Difficulty, pacing, and automated acceptance pass completed 2026-07-15:

- Debug-only in-memory telemetry now reports encounter durations, weapon selected time/shots/hits/damage/kills, damage sources, death cause/position, enemy active lifetime, Boss phase duration, and peak active/attacking enemies. It writes no file and sends no data.
- Four encounters now unlock sequentially with a 0.55-second buffer. A lightweight attack director caps ordinary simultaneous telegraphs at two, Boss support at one, and separates high-risk warnings by 0.65 seconds. Gunner/elite attacks cannot begin beyond 520 px.
- The one-time command cache before the Boss restores full health and guarantees at least 60% of each magazine. Boss support receives spawn grace and cannot begin an attack during a Boss telegraph/active semantic window.
- Iron Tempest health moved from 820 to 1200 only after the baseline showed a roughly 7.4-second rifle clear with a 1.93-second Phase II. The mixed-weapon scripted run now measures about 30 seconds total and roughly 1.9/5.7/4.2 seconds across the three Boss phases.
- A Boss-stage death now returns to a clean Phase I checkpoint in about 1.6 seconds with full health/ammo, reset HUD/arena/audio, and no old projectiles or hazards. Normal-stage death behavior is unchanged.
- `tests/combat_pacing_test.gd`, `tests/scripted_playthrough_test.gd`, and the strengthened restart test are part of the primary verifier. Automated engineering gates pass; new-player, expert, controller, and pressure feel remain human acceptance work before release QA.

Complete arcade mission expansion completed 2026-07-15:

- The playable route expands from the original 4300 px/9-enemy layout to a 20,000 px mission with a 10-second minimum traversal before first contact, four major gated sectors, eleven waves, and 28 regular enemies before the existing Boss.
- The sectors teach mixed close/ranged pressure, platform-and-sniper sightlines, shield displacement, and an elite-centered climax. Forward energy gates close only for major encounters and reopen immediately after the final wave.
- Enemy waves are created only after their authored trigger. A 30-second no-kill watchdog repositions surviving progress enemies into the readable combat area instead of killing them, preventing screen-off permanent locks without shortening healthy encounters.
- Four field supplies, three warned spike strips, and two vertical moving platforms add recovery and traversal variation without an inventory, progression system, or new enemy/weapon type. The pre-Boss cache is deliberately limited to +45 health and a 60% magazine floor.
- Settlement now reports rank, time, score, kills, accuracy, hits taken, and remaining health using existing run data, with replay and exit choices. Boss-checkpoint retry preserves mission statistics while fully resetting gameplay danger state.
- The full mixed-weapon automation completes the expanded mission in 131.66 simulated seconds under test-only invulnerability, continuous combat input, and ordinary traversal jumps. This proves end-to-end reachability, not the requested 5–8 minute human target; human first-run/skilled timing remains the stage gate.

Ground-roll, charged-grenade, and traversal-correction pass completed 2026-07-15:

- Same-direction action-edge double taps within 0.25 seconds start a 0.30-second, 340 px/s ground roll. Direction is locked, world/gate collision remains active, and a 0.50-second cooldown begins only when the roll finishes.
- Rolling cancels reload and fire, blocks weapon switching and grenade use, and ignores only damage classified as `projectile`. Melee, contact, explosion, and environment damage remain active; no player collision shape is disabled.
- Holding/releasing the existing `throw_grenade` action charges a pixel world-space meter with a 1.0-second ping-pong cycle and throws one of three grenades at 340–820 px/s. Grenades use gravity, at most five damped bounces, a 1.70-second pause-safe fuse, one deduplicated 110 px/80-damage enemy-only explosion, and bounded audio/camera feedback.
- First contact moved from x=5200 to x=2830 (10 seconds at the unchanged 260 px/s run speed). Static platform tops were lowered into the unchanged jump envelope; all three road hazards are now 72 px wide, with the second moved clear of a low platform.
- `tests/player_combat_abilities_test.gd` and `tests/level_mobility_test.gd` lock input/state/damage/inventory/cleanup plus real platform and hazard traversal. The mixed-weapon runner now performs ordinary route jumps and reaches settlement in 131.66 simulated seconds.

Roll/grenade refinement and encounter-adaptation pass completed 2026-07-15:

- Measurement reduced roll travel from 216.7 px to 107.7 px (about three collision-body widths) while retaining the 0.25-second double-tap window and measured 0.517-second post-action cooldown. Invalid/CD taps cannot arm a delayed roll, focused UI ignores taps, and grenade charge cancels without consumption when a valid roll begins.
- Projectile-only dodge feedback uses one bounded cyan graze effect and a rate-limited original cue. Debug telemetry/F3 now records roll attempts, successes, dodges, grenade throws, charge average, hits, kills, and damage by target type.
- The grenade meter is centered above the player; its 5–8 prediction points start at the safe real origin and stop at first terrain contact. Throw speed remains 340–820 px/s with 25% horizontal movement inheritance, 1.0-second charge ping-pong, 1.70-second fuse, accelerating warning ticks, and finite bounce behavior.
- Explosion damage remains 80 at the center but now falls continuously to 44 at the 110 px edge. One explosion still resolves each target once; three grenades total at most 240 raw Boss damage (20% of 1200 HP), so one throw cannot skip either 65%/30% threshold.
- First contact now teaches one readable gunner before a compact three-assault wave. Short world-compatible prompts dismiss after the first roll or grenade explosion; one +1 route pickup and a two-grenade Boss-cache top-up remain finite.
- The primary verifier now includes deterministic roll duration/distance/cooldown and low/mid/high throw-distance measurements. Full combat, environment, audio, restart, Boss, and scripted-playthrough gates remain green; subjective double-tap comfort, grenade hit rate against live enemies, and human mission difficulty remain the stage gate.

Shift sprint and stamina pass completed 2026-07-15:

- `sprint` is an InputMap action bound to left/right Shift. Grounded horizontal input reaches 468 px/s (1.80x the unchanged 260 px/s normal speed) with separate 2100 acceleration and 2400 post-sprint deceleration.
- Stamina is centralized at 100 maximum, 28/s drain, 22/s recovery, 0.60-second delay, and a 20-point exhausted restart gate. Drain uses real post-collision displacement, so standing, opposing inputs, air time, pause, controlled states, and wall contact do not waste stamina.
- Sprint cannot shoot or switch weapons. Fire, grenade charge, roll, hurt, death, focus loss, and disabled controls end it immediately; safe reload cancellation preserves current ammo. Rolls retain projectile evade and remain stamina-independent, while sprint has no invulnerability.
- Visual-only SprintStart/Loop/Stop poses lean the body without rotating or resizing the 34x64 physics body. The weapon is stowed, footsteps accelerate, small pixel dust trails appear, and the independent world-space bar retracts from right to left before fading after full recovery.
- Camera movement look gains a smooth, bounded 38 px sprint extension while preserving the 20,000 px level clamp. `player_sprint_stamina_test.gd`, captured sprint frames, the mixed-weapon PVE run, and the full verifier are the acceptance gates. No survival-mode runtime currently exists, so Roguelite/survival additions remain deferred.

## Phase gates

### Phase 0 — Project audit, technical baseline, and diagnostics

Status: **Pass** (see `docs/CURRENT_STATUS.md` for current evidence).

- Audit repository and installed engine.
- Create a minimal runnable project and stable directory boundaries.
- Define input action names and keyboard/mouse/gamepad defaults.
- Provide an in-game debug readout and executable verification.
- Define Phase 1 acceptance criteria.

### Phase 1 — Player movement and camera feel

Status: **Partial** — horizontal movement, jump foundation, aiming, and camera follow are playable; crouch and the full detailed camera/jump acceptance suite remain.

- Implement one controllable test character in a gray-box movement room.
- Cover acceleration, deceleration, jump buffering, coyote time, variable jump, crouch clearance, and camera behavior.
- Meet every behavior in `docs/acceptance/PHASE_1_ACCEPTANCE.md` with automated or recorded manual evidence.

Completed slices:

- Gray-box room and original placeholder player.
- Horizontal acceleration, braking, reversal, keyboard/gamepad action input, collision bounds, and movement telemetry.
- Full and cut-short jump behavior with buffer/coyote implementation, mouse/right-stick aiming, and horizontal follow camera.

Next production slice:

- Complete timed new-player and skilled-player runs of the expanded mission. If first-run 5–8 minutes and skilled 4–6 minutes are confirmed without fairness or gate stalls, proceed to pre-release QA; evaluate survival mode only after that evidence.

### Phase 2 — Shooting, ballistics, and damage

Prototype status: **Pass** — four differentiated firearms, per-weapon magazine/reload state, direct switching, ray-safe projectiles, falloff, bounded penetration, team filtering, player/enemy damage and death.

- Add an ownership-safe weapon interface, one baseline firearm, projectiles/hits, damage contracts, and disposable target dummies.

### Phase 3 — Hit, hurt, and audiovisual feedback

Prototype status: **Pass for current prototype scope** — weapon-specific pixel effects, layered hit/block/break/kill feedback, capped camera trauma, local peak-frame emphasis, eight-bus original procedural audio/music, bounded/spatial playback, pause mix controls, and cleanup gates pass; subjective listening remains a human test.

- Add readable hit pause/flash, recoil, particles, camera impulse, audio hooks, invulnerability signaling, and tuning controls using original placeholders.

### Phase 4 — Basic enemies and combat encounter

Prototype status: **Pass** — assault, gunner, shield, and elite roles form four activation-gated mixed encounters with readable attack states.

- Add three distinct enemy behavior roles and one bounded encounter with deterministic reset and debug observability.

### Phase 5 — First complete level vertical slice

Prototype status: **Pass** — one original advancing level with four staged encounters, Boss arena, and final settlement is playable; human completion-time measurement remains.

- Build one original gray-box-to-polish advancing level with encounter pacing, hazards, pickups, and a finish condition.

### Phase 6 — Boss, checkpoint, and retry

Prototype status: **Pass for current prototype scope** — independent three-phase Boss, locked arena, total-health HUD, danger cleanup, clean Boss-stage checkpoint retry, and final settlement pass; general checkpoints remain intentionally unimplemented.

- Add one small original boss, checkpoints, death/retry, and complete start-to-finish flow.

### Phase 7 — Feel, performance, and playability polish

Prototype status: **In progress** — pixel UI, player/four-weapon, four-role enemy visuals, combat effects, layered environment, three-form Boss, and bounded audio/music mix pass; deeper performance profiling and repeated human playtests remain.

- Profile frame time and object counts, tune difficulty and feedback, improve accessibility, and run repeated playtest passes.

### Phase 8 — Expansion decision

- Use vertical-slice evidence to decide whether local co-op, progression, more characters, or more levels are justified. Do not assume they are approved.

## Engineering loop

1. Read the current status and phase acceptance criteria.
2. Select one smallest end-to-end behavior.
3. State expected behavior and rollback boundary.
4. Implement without unrelated refactors.
5. Run the relevant automated checks and a proportionate manual play check.
6. Record evidence, known gaps, and the next smallest slice in current status.
7. Commit only a coherent, passing slice.
