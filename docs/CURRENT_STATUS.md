# Current Development Status

Last updated: 2026-07-16 (Asia/Shanghai)

## Current outcome

**Rapid playable prototype — Pass.** The project now provides an immediately playable original 2D side-scrolling shooter loop in Godot 4.7.

**Focused experience polish — Pass.** A concentrated audit identified five first-impression issues; the three highest-impact items were fixed and regression-tested without adding a new level or large system.

**Vertical-slice core-feel pass — Pass.** The next five issues were ranked and the top three were implemented as isolated, regression-tested groups: airborne/landing feel, combat audio plus hit tiers, and aim-aware camera framing.

**Four-weapon system and switching experience — Pass.** Auto rifle, scattergun, rail lance, and sidearm now share one projectile/damage path and one active-weapon state. Number-key switching, HUD state, falloff, penetration, restart initialization, and held-fire isolation are covered by executable tests.

**Enemy diversity, staged encounters, and three-phase Boss — Pass.** Four ordinary/elite combat roles, gated encounters, an independent Boss arena, signal-driven total-health UI, danger cleanup, phase-two death reset, and final settlement now form one verified start-to-finish flow.

**Pixel visual system and core UI — Pass.** The existing 1280×720 gameplay framing now has a nearest-filtered, pixel-snapped rendering baseline; one shared bright fantasy-tech theme; an original procedural portrait and four weapon icons; rebuilt player, weapon, Boss, pause, death, and settlement UI; and verified 720p/1080p/1440p plus ultrawide layout behavior.

**Player pixel character, four held weapons, and base animation — Pass.** The 34×64 physics envelope is unchanged while an original teal/gold layered pixel character, four world-readable weapon silhouettes, per-weapon muzzle markers, and visual-only idle/run/jump/fall/land/shoot/hurt/death states replace the old single-block player.

**Combat-character visual unification — Pass.** Player presentation is calibrated to 125% with its original physics footprint, while assault, gunner, shield, and elite enemies now have original warm-palette pixel silhouettes and logic-driven movement, telegraph, attack, recovery, block/break, stagger, hurt, and death poses.

**Combat presentation and pixel-effects upgrade — Pass.** Four fire signatures, pixel trails/muzzle flashes/casings, tiered normal/heavy/block/break/kill effects, role-specific warning accents, restrained Boss hit response, capped optional camera shake, and local heavy-hit emphasis now pass dedicated and full-flow regression gates without changing combat balance or AI timing.

**Scene pixelization and environment depth — Pass.** The old flat bands, triangle mountains, repeated building rectangles, plain floor/platforms, duplicate crates, tall foreground poles, smooth beacon, and solid Boss gate are replaced by an original four-layer fantasy-tech pixel environment. Exact collision, encounter, camera, Boss, and gameplay contracts remain executable-test locked.

**Iron Tempest formal visual, phase presentation, and readability — Pass.** The geometric purple Boss is replaced by an original layered industrial machine. Complete armor, exposed-core damage, and overload forms bind to the existing 65%/30% phase truth; volley/charge/area presentation reads existing timers; collision, muzzle positions, attack values, phase timing, cleanup, restart, and settlement remain executable-test locked.

**Boss-flow HUD hierarchy and responsive layout — Pass.** Boss identity, mission updates, phase changes, defeat, and settlement now have non-overlapping lifetimes managed by five lightweight UI states. Permanent HUD footprint is reduced from about 15.5% to 11.5% of the 1280×720 frame, the Boss track contains real 65%/30% markers, controls auto-hide, and 720p/1080p/1440p plus synthetic ultrawide layout contracts pass.

**Sound effects, audio mix, and feedback pass — Pass.** Eight routed buses, a Master limiter, 75 semantic original procedural cues, preserved level/Boss loop tracks, bounded 20-voice playback, event prioritization, distance attenuation, semantic music ducking, visible Master/Music/SFX controls, and restart-safe session settings now cover weapons, impacts, movement, enemies, Boss, UI, death, and settlement. Gameplay values and timing remain unchanged.

**Difficulty, pacing, weapon-value, and automated full-run acceptance — Pass for executable gates; human acceptance remains Partial.** Debug-only telemetry established a pre-change baseline, the top three evidenced pacing/fairness issues were fixed, a mixed-weapon playthrough reaches settlement with all four weapons contributing, and the Boss checkpoint restores a clean playable state in about 1.6 seconds. New-player comprehension, expert exploits, physical-controller feel, and subjective difficulty still require people rather than scripted bots.

**Complete arcade mission expansion — Pass for implementation and regression; Partial for human-duration acceptance.** The original 4300 px, nine-enemy route is now a 20,000 px mission with four gated sectors, eleven waves, 28 regular enemies, traversal variation, limited supplies, environmental hazards, moving platforms, the existing Boss, and a statistic-rich settlement. The invulnerable mixed-weapon automation reaches settlement in 131.66 simulated seconds; the requested first-run 5–8 minute and skilled 4–6 minute windows still require measured human sessions.

**Ground roll, charged grenade, and traversal correction — Pass for executable gates; human feel remains Partial.** AA/DD ground rolls use the existing collision body while selectively evading projectile damage, and right-mouse charge throws one of three finite-bounce grenades through the existing damage/feedback paths. First contact now begins at the requested 10-second mark, elevated platforms are inside the unchanged jump envelope, and all road hazards pass real running-jump tests without forced damage. Roll cadence, throw-distance feel, and the grenade's effect on human difficulty still need hands-on acceptance.

**Roll/grenade refinement, reliability, and encounter adaptation — Pass for executable gates; human feel remains Partial.** The measured roll was shortened from 216.7 px to 107.7 px while preserving its exact post-action 0.50-second cooldown. Cooldown input caching, focused-UI input, grenade-cancel roll, safe grenade spawn, collision-truncated trajectory preview, partial movement inheritance, fuse warning, edge falloff, debug telemetry, finite resupply, and two short opening lessons are now covered by executable checks. Subjective double-tap comfort and live grenade hit rate remain human acceptance work.

**Shift sprint and stamina — Pass for executable and captured visual gates; human feel remains Partial.** Grounded Shift+A/D reaches 468 px/s (1.80x normal), drains 28 stamina/s only on real movement, exits at zero, waits 0.60 seconds before 22 stamina/s recovery, and requires 20% recovery after exhaustion. SprintStart/Loop/Stop are visual-only poses under `PlayerVisual`; the physics body never rotates. A world-space pixel stamina bar retracts from right to left and fades after full recovery. Shooting, reload, weapon selection, grenade, roll, jump, hurt, death, pause, focus, camera, walls, gates, and restart contracts are covered by `player_sprint_stamina_test.gd`. The same controller now passes a complete survival run without mode-specific parameter changes.

**Sprint-jump momentum integration — Pass for automated physics and regression gates; human feel remains Partial.** A sprint jump or sprint-speed platform exit preserves the measured launch velocity (468 px/s at full sprint) rather than immediately falling to the normal 260 px/s cap. Same-direction input maintains the launch cap, no-input drag is 170 px/s², reverse braking is 720 px/s², and non-sprint landing deceleration is 1400 px/s² (roughly 0.15 seconds from full sprint to normal cap). Ordinary air movement cannot acquire sprint speed by pressing Shift. SprintJump/Fall/Land poses and sprint camera forward view are presentation-only; firing and grenade charge retain physical momentum, roll remains ground-only, and sprint-air movement grants no damage immunity. `sprint_jump_momentum_test.gd` locks the ten-frame trace, ledge, landing, exhaustion, action, camera, and closed-gate contracts.

**Survival acceptance and pacing pass — Pass for automated stability/pressure; Partial for human duration.** The survival curve now contains 104 ordinary/elite enemies with 4→7 active caps, 3–6 unit reinforcement batches, 0.42–0.62-second individual spawn spacing, one early attack slot and two later slots, occupied-spawn rejection, and bounded supplies. Normal rests are 3.5 seconds instead of 10; waves 5/9 retain 6-second supply windows and a one-shot fast-start request preserves the final spawn warning. Debug-only `SurvivalBalanceTelemetry` records each wave's timing, composition, pressure, incoming damage, resource boundaries, weapon contribution, and grenade use. Repeated real-projectile automation settles once in 454.31–590.92 seconds using all four weapons and in 353.12–501.97 seconds using rifle only plus high-frequency rolls. Every run peaks at two attackers and at most seven active enemies. These bots deliberately use near-perfect aim and heal between frames, so the human 8–15 minute target, headshot readability, and dominant-rifle risk remain unverified.

**Lightweight in-run Roguelite upgrade loop — Pass for implementation and automated isolation; Partial for human Build balance.** Waves 2/4/6/8 pause the survival intermission for one three-card choice drawn from twelve capped, weighted definitions. `RunUpgradeManager` recomputes final player, grenade, and instance-local weapon values from immutable baselines, while the card UI only requests a choice and never edits gameplay values. Maxed options leave the pool; roll, stamina, reload, pellet, penetration, grenade, health, and sprint values retain explicit safety bounds. Death, restart, exit, debug reload, and PVE entry restore base values. After the durability/pacing change, mixed routes complete in 454.31–590.92 simulated seconds and rifle-only pressure in 353.12–501.97 seconds, with four choices each. Human choice quality, card readability under real input, and dominant-Build risk remain unverified.

**Survival durability, headshots, damage numbers, and tighter deployment — Pass for automated gates; human readability/balance remains Partial.** Survival-only health is now 192/216/288/1200 for assault/gunner/shield/elite while PVE retains 44/58/92/230. Visual-following head areas apply one centralized 2.0 multiplier without changing physics, shield fronts or Boss core rules. A fixed 64-label pool shows actual final damage, priority headshots, and block results. Waves 1–9 rise from 77 to 104 enemies, active caps rise from 3–6 to 4–7, normal rests fall from 10 to 3.5 seconds, supply rests are 6 seconds, and rest can be shortened to a final one-second warning. Mixed automation completes in 454.31–590.92 seconds; rifle-only pressure completes in 353.12–501.97 seconds with no card/PVE state leakage.

**Compact headshot numbers and four-weapon audio identity — Pass for executable gates; final loudness taste remains human acceptance.** Headshots now show only their real final-damage integer: gold, dark-orange outlined, approximately 1.32× the settled visual size of an ordinary number, and animated with a short 0.80→1.15→1.00 pop. `HEAD`, `HEADSHOT`, and `CRIT` no longer occupy combat space. The four original procedural firing cues now have measured 65–240 ms signatures, restrained 0.4%–1.6% pitch variation, source peaks below 0.64, synchronized action layers, and the intended sniper ≥ shotgun > rifle > pistol level order. Damage, the 2.0 head multiplier, weapon timing/ammunition, enemies, waves, upgrades, and Boss logic are unchanged.

**Focused shotgun/sniper feedback and rail-lance precision — Pass for executable gates; final loudness taste remains human acceptance.** One shotgun volley now produces one 225 ms low body, one simultaneous air-blast layer, and one pump at 95 ms; one sniper shot produces one 270 ms body, one simultaneous high-frequency crack, one 18 ms reflection tail, and one bolt at 105 ms. Pre-limiter composite peaks measure 0.466/0.473 and energy measures 6.217/8.733 for shotgun/sniper. The rail lance now locks its shot from the live visual muzzle to the mouse world coordinate before recoil, with zero configured standing, movement, or airborne spread. PVE and survival tests cover left/right, near/mid/far, up/down, movement/airborne states, and 720p/1080p/1440p transforms without changing damage, rate, magazine, reload, penetration, or the other three weapons.

This does not mean every production roadmap phase is complete. Detailed crouch acceptance, formal camera tuning, human loudness/fatigue evaluation, checkpoints outside the Boss retry point, production sprite sheets, and measured human balance remain future work.

## Pre-change baseline

- The repository already contained a passing Phase 0 baseline and a passing deterministic horizontal-movement slice.
- The visible build had one placeholder player and horizontal movement but no jump, combat, enemies, death loop, advancing level, or complete presentation.
- Baseline commands `./scripts/verify_phase0.sh` and `./scripts/verify_phase1_horizontal.sh` passed before prototype expansion.
- Git has an intentional baseline, a `codex/player-roll-grenade` working branch, and a configured GitHub origin; current refinements are kept as one coherent verified slice.

## Playable loop now implemented

- Move with keyboard or controller; jump with full-height and early-release behavior.
- Hold Shift with horizontal input for a grounded 1.80x sprint governed by a local stamina/exhaustion gate and world-space pixel bar; sprinting jumps and platform exits carry controllable horizontal momentum into the air.
- Aim with mouse or right stick; hold the auto rifle trigger or point-fire the three semi-automatic weapons.
- Original layered pixel player with separate shadow, body, arms, weapon pivot, active muzzle, and effects; facing is redrawn without negative node scaling.
- Four per-weapon magazines, manual/empty reload, distinct pixel muzzle flash/recoil/tracer silhouettes, and bounded decorative casings.
- Projectiles use continuous ray queries, collide with terrain, filter teams, and apply configurable damage, knockback, range falloff, and bounded penetration.
- Player health, invulnerability flash, damage response, death, and automatic 1.35-second redeploy.
- Four original pixel combat roles: blade-forward assault rushers, rifle-bearing gunners, wide directional shield troops, and a separately drawn heavy-armored elite.
- Twenty-eight regular enemies distributed across four trigger-driven gated sectors and eleven waves, followed by an independent three-phase Boss arena.
- Eliminating regular enemies unlocks the command arena; defeating the Iron Tempest clears all dangers, releases the boundary, and enters final settlement/replay.
- Horizontal camera follow with look-ahead, level clamps, centrally capped trauma shake, and F4 100%/50%/OFF control.
- Original pixel sky, stepped far ridges, modular luminous city, panelled transit deck, collision-aligned platforms, supply consoles, route crystals, low foreground growth, command arena, pixel Boss gate, and exit beacon.
- A 20,000 px route with ten static platforms, two moving platforms, five field supplies, three warned spike strips, and one reusable encounter gate; no inventory or progression system was introduced.
- Compact screen-space pixel HUD for portrait/health/ammo, four switch slots with reduced inactive detail, secondary score, time-bounded objective/control hints, mission notices, and mouse crosshair.
- Signal-driven Boss panel with immediate and delayed damage layers, integrated 65%/30% markers, concise current-phase text, one-shot transition toast, and shared pixel-styled pause, death, and settlement overlays.
- Original procedural level/Boss music and role-routed weapon, combat, enemy, Boss, player, and UI cues with bounded concurrency; the pause panel controls Master/Music/SFX without losing the chosen mix on scene restart.
- F3 diagnostics retain movement/weapon data and add sprint state, stamina/drain/regen values, exhaustion, current speed, grounded state, block reason, current shake scale, and feedback aggregation.

## Combat presentation implementation

- `Projectile` still performs the existing continuous ray query and damage call. After the target resolves damage, it emits presentation-only details containing weapon, target category, travel distance, penetration index, direction, and the target's latest normal/heavy/block/break result.
- `CombatFeedback` contains the shake/visual-hold profiles. Rifle shot trauma is capped at 0.14, shotgun at 0.30, rail lance at 0.34, and sidearm at 0.05. Kill/Boss profiles have their own bounded caps; same-frame shotgun pellets and rail-lance penetration hits merge camera/audio/hold requests.
- Heavy emphasis is implemented as a 0.022–0.045-second local peak-frame hold inside the disposable effect. `Engine.time_scale` stays 1.0, so input, physics, AI timers, invulnerability, reload, and Boss transitions are not paused.
- `PixelMuzzleFlash` draws four authored silhouettes lasting 0.045–0.078 seconds. Projectiles draw weapon-specific hard-edged tracers; `ImpactEffect` draws finite rectangle fragments for terrain, normal, shotgun, sniper/heavy, block, guard break, kill, hurt, land, and Boss events.
- Shield code remains the authority for damage reduction/opening and now reports `block` or `guard_break`. Boss code reports subdued normal or heavy hit presentation; ordinary rifle bullets only brighten its core for 0.032 seconds instead of flashing the entire body.
- Assault, gunner, shield, and elite telegraph poses add short directional accents using the shared danger palette. Ground hazards now show pixel bands/ticks that preserve the original radius and windup values. Foreground posts/cables are thinner and lower-alpha so they do not dominate tracers or warnings.
- Casings never affect collision or damage, are capped at 12, and self-delete within 0.48 seconds. All impacts have a 0.16–0.46-second finite lifetime; restart reloads the scene and `CombatFeedback.clear()` removes camera offset/trauma before reload.

## Audio implementation

- `default_bus_layout.tres` defines `Master`, `Music`, `SFX`, `Weapons`, `Player`, `Enemies`, `Boss`, and `UI`. Music and SFX feed Master; role buses feed SFX. Master owns one limiter with a -1 dB ceiling and -3 dB threshold.
- `ProceduralSFX` is now the lightweight audio director while retaining the existing `SFX` scene node and legacy cue aliases. Its single catalog owns cue bus, level, cooldown, concurrency, priority, pitch variation, and deterministic synthesis parameters.
- Four weapon signatures are deliberately different: rifle remains a 70 ms mid/low impact with a restrained action layer; shotgun is a 225 ms low-frequency body plus simultaneous air blast and a 95 ms pump; rail lance is a 270 ms body plus simultaneous high-frequency crack, an 18 ms reflection tail, and a 105 ms bolt; sidearm remains a compact 65 ms lower-centered report with a fast slide. Main-body levels are -7.0/-4.7/-4.0/-8.0 dB for rifle/shotgun/sniper/pistol, preserving sniper > shotgun > rifle > pistol while sustained rifle concurrency remains bounded. Each weapon has a distinct reload start, common insert/complete stages, and an empty click without changing weapon timing.
- Combat feedback routes normal/heavy/wall, shield block/break, and light/heavy kill events separately. Same-frame visual aggregation remains authoritative for shotgun/penetration feedback, while audio adds cue cooldowns and per-cue voice caps as a second safety layer.
- Jump, footsteps, normal/heavy landing, low health, hurt, and death are driven by player truth events. Ordinary and elite telegraphs, assault swing, shield bash, elite attack/step, hurt, guard, break, and deaths use the Enemies bus. Important off-screen warnings keep a -6 dB attenuation floor while ordinary distant activity can fall to -14 dB.
- Boss intro, phases II/III, volley/charge/area warnings, cannon/charge/area releases, armor/core hits, failure, staged explosions, final collapse, and core shutdown use the Boss bus. Phase/death semantics briefly duck the existing Boss music; ordinary gunfire never does. Boss death stops active Boss-bus voices before the bounded 0.85-second shutdown sequence.
- A fixed pool contains 20 SFX players plus two Music decks. Low-priority cues cannot steal high-priority player death, Boss phase, or Boss death events; dense repeated requests are rejected rather than creating temporary nodes.
- Original generated level and Boss loops use conservative source peaks and crossfade at arena entry. Pause ducks the active music deck by 4 dB; completion fades music before the completion cue; scene restart initializes the level loop.
- Master defaults to 100%, Music 72%, and SFX 86%. The pause panel changes these by 10% steps and toggles mute on the real buses. Values persist across scene reloads only for the current application session; no disk save system was introduced.
- `docs/AUDIO_SOURCES.md` records that all current cues and both tracks are original project-authored procedural assets. No imported audio file is present; any future file requires a verified source and license entry.

## Environment implementation

- `SkyPixelArt` owns only the 1280×720 screen-space gradient bands, stepped sun, clouds, and stars. It contains no gameplay nodes and remains behind every world layer.
- `ParallaxPixelArt` draws two stepped far-ridge bands and modular mid-city buildings/bridges across coverage wider than the camera route. Existing factors remain far `0.15`, mid `0.45`, front `1.15`; every scrolling position is rounded to a logical pixel.
- `LevelPixelArt` draws against the unchanged y=584 ground top and expanded 20,000 px level width. Its ten platform rectangles exactly match the collision rectangles, while floor bays, supports, console props, section markers, crystals, command-arena panels, pylons, and beacon remain visual-only.
- `BossGatePixel` stays attached to the existing `Polygon2D` reference used by game flow. Its collision remains owned by the unchanged 28×720 `StaticBody2D`; the script only replaces the transparent gate polygon with a readable coral/gold pixel barrier.
- The old z=80 foreground poles and cables were replaced by translucent crystal-grass clusters at y≥568. They provide camera-relative depth while remaining below torsos, weapons, projectiles, and attack warnings.
- World art uses hard rectangles/polygons on the project 4 px language. The environment test scans these four scripts and rejects `draw_circle`, `draw_arc`, or `draw_line`, while also locking floor/platform/gate/camera and all nine regular encounter contracts.

## Four-weapon implementation

One `WeaponInventory` child owns the current weapon, per-weapon ammunition, fire/switch/reload cooldowns, and shot sequence. It does not instantiate weapon scenes. `WeaponCatalog` returns four focused configuration dictionaries, while the existing player controller remains responsible only for input, aim/spread construction, recoil, and emitting one volley. Main instantiates every projectile through the shared projectile scene.

Final parameter baseline:

| Slot | Role | Damage | Interval | Speed | Count / spread | Range / falloff | Knockback | Penetration | Magazine |
| --- | --- | ---: | ---: | ---: | --- | --- | ---: | ---: | ---: |
| 1 Auto Rifle | Mid-range sustained output | 24; every 4th shot 34 | 0.085 s | 1050 | 1 / 1.2° plus bloom | 1500 / starts 900, min 75% | 185 | 0 | 32 |
| 2 Scattergun | Close burst | 17 per pellet | 0.62 s | 900 | 7 / 16° | 720 / starts 220, min 25% | 330 | 0 | 8 |
| 3 Rail Lance | Long precise high damage | 92 | 1.0 s | 3600 | 1 / 0.15° | 2400 / no falloff | 420 | 2 normal targets; elite/Boss stops | 5 |
| 4 Sidearm | Reliable precision point-fire | 32 | 0.23 s | 1250 | 1 / 0.35° | 1400 / starts 1000, min 85% | 135 | 0 | 15 |

The 0.055-second switch lock replaces the previous fire cooldown, cancels an in-progress reload, and prevents one-frame switch spam. Selecting the already active slot returns without rebuilding or resetting anything. Semi-automatic weapons require a fresh trigger edge, so holding fire while switching from the rifle cannot discharge them. Scattergun impacts still create individual sparks, but camera/audio hit feedback is aggregated once per physics frame; enemy death already rejects damage after death. Rail-lance ray segments exclude already-hit collision RIDs and continue within the same physics tick, preventing tunneling and repeat hits.

## Player visual implementation

- `Player` remains the only physics owner. Its collision size stays 34×64, floor snap stays 8 px, and all movement/jump/health/weapon numbers retain the pre-change values.
- `PlayerVisual` consumes current velocity, grounded state, aim, landing, hurt, fire, and death events. It never writes velocity, collision, damage, health, fire rate, spread, or AI state.
- `BodySprite` draws the original helmet/visor/face/scarf/suit/belt/leg/boot silhouette on integer coordinates. Idle breathing and run leg alternation keep the feet readable; jump, fall, and land use distinct poses.
- `WeaponPivot` draws the back arm, active gun, and front arm in order. It supports approximately ±80° local aim without negative scaling and owns one live `MuzzlePoint` used by the real projectile origin.
- Scene weapon silhouettes are rifle 40 px muzzle length, shotgun 39 px short/thick profile, sniper 52 px long barrel/scope, and pistol 25 px compact profile. Visual recoil order is sniper 8 px, shotgun 6 px, rifle 3.5 px, pistol 2 px; these values do not change ballistic recoil.
- Shoot is layered over locomotion, hurt lasts 0.18 seconds without disabling input, and death hides the ordinary weapon layer while the existing 1.35-second restart flow proceeds.

## Combat-character visual implementation

- Player visual scale changed from 1.0 to 1.25 with a -8 px vertical compensation. At 720p the 4 px construction grid becomes 5 px; the 34×64 collider, floor snap, movement, jump, camera, health, weapon data, and damage remain unchanged.
- The enemy scene keeps its 38×58 rectangle collider and 8 px floor snap. The elite keeps the pre-existing 1.28 root scale, so its physical envelope is unchanged, but its body is a unique wide heavy-armored silhouette rather than a scaled normal soldier.
- Assault uses a forward lean, alternating long stride, light armor, and visible blade. Its 0.32-second melee warning reads as a rearward brace; the attack lunge and recovery pose are visual overlays on the existing timing.
- Gunner uses a medium helmet, visor, two-handed rifle, aim raise, muzzle flash, and recoil pose. The real projectile origin equals `EnemyVisual/MuzzlePoint` and preserves the old ±24/-12 local baseline.
- Shield uses the shield as its primary silhouette. Closed guard, blue block edge, stagger, and displaced/broken guard correspond to actual front reduction and `guard_open_remaining`; visual code does not calculate damage.
- Elite uses independent wide shoulders, heavy legs, chest core, and cannon. Volley and ground-hazard telegraphs differ, while shotgun/sniper context activates the existing stagger and a stronger visual hit edge.
- Facing redraws integer geometry and moves the muzzle marker by sign; no enemy visual or collision node uses negative scale. Death has highest visual priority, disables collision/physics through the existing logic, and then uses role-weighted falls during the original 0.45-second cleanup.

## Enemy, encounter, and Boss implementation

Audit evidence showed the old enemy script already contained useful movement, telegraph, damage, and death behavior, but weapon identity was lost at the projectile boundary and enemies had no explicit dormant/active lifecycle. The implemented change adds a small hit-context dictionary and explicit states rather than replacing the damage system or player controller.

- Assault troops: 44 HP, 175 px/s approach, 0.32-second melee warning, bounded hit check, and 0.82-second recovery. Their low health and strong player-weapon knockback make close scattergun use efficient.
- Gunners: 58 HP, maintain roughly 230–410 px distance, visibly aim for 0.38 seconds, fire visible 700 px/s rounds, then recover for 0.92 seconds. Sidearm, rifle, and rail lance retain range value.
- Shield troops: 92 HP and one body collider. Front rifle/pistol damage is reduced to 24%/42%; scattergun and rail-lance hits retain 72%/82% damage and open/stagger the guard for 0.72/1.1 seconds. Rear hits use full damage, so positioning and heavy impact are both reliable solutions.
- Elite heavy: 230 HP, 1.28× silhouette, alternating warned three-shot volleys and 92 px warned ground zones, shorter attack recovery below 50% health, and readable scattergun/rail-lance stagger.

Encounter gates activate at player x positions before each enemy becomes visible enough to threaten the player. The four groups teach assault, combine assault/gunner pressure, introduce shield/gunner defense break, and transition through elite/assault pressure. No enemy performs a global player search; each owns a direct target reference and remains dormant until its gate.

The Iron Tempest uses `scenes/bosses/iron_tempest.tscn` and its own state scheduler. Phase I (100–65%) alternates a 3-round ranged volley and warned charge. Phase II (65–30%) adds two warned ground zones and summons at most two ordinary enemies once on transition. Phase III (30–0%) accelerates known volley/charge/area patterns without introducing an unfamiliar attack. The scheduler rejects immediate attack repetition, uses transition invulnerability for 0.85 seconds, and leaves 0.62–0.95-second recovery windows.

The Boss physics root still owns the unchanged 112×122 body while `BossVisual` owns nine replaceable presentation layers. The low heavy feet, reactor hull, sensor crown, ram arm, cannon, and diamond core form one industrial silhouette. Paired armor, one-sided damage/core exposure, and asymmetric overload damage distinguish the three existing phases without consulting the HUD. Cannon light, ground chevrons, and belly emitter bind to the real volley, charge, and area windups; the two muzzle markers retain the original ±62/-26 offsets.

Boss health signals update a screen-space HUD containing name, immediate health, 0.32-second delayed loss, numeric total, concise armored/core-exposed/overload text, phase color, and 65%/30% marks. The panel is hidden before combat and after settlement, does not poll the scene tree, and is anchored between—not over—the player and score panels. Phase transitions and death clear enemy projectiles and ground hazards; death also removes summons and releases the arena wall.

## Focused polish audit and changes

Ranked findings before modification:

1. Rifle and heavy attacks created projectiles immediately with no reaction window.
2. Muzzle flash, weapon pose, hit sparks, knockback, and camera response did not read as one coherent firing beat.
3. The diagnostic panel opened by default and dense foreground poles covered too much of the initial combat view.
4. Jump takeoff/landing lacks a dedicated squash or dust cue.
5. Camera composition uses velocity look-ahead but not aim-direction framing.

Fixed in this pass:

- Rifle wind-up is now 0.32 seconds and heavy wind-up is 0.48 seconds. A bright pulsing diamond appears over the enemy, movement brakes during the wind-up, and the projectile is emitted only when the warning completes.
- Each player shot now moves the weapon body backward, alternates the muzzle shape slightly, and adds a small direction-aware camera recoil. Damaging hits create larger/brighter sparks than terrain hits, apply stronger knockback, and hold the enemy white flash longer.
- The debug overlay starts hidden while remaining available through F3. Foreground posts are half as frequent, thinner, and more transparent, with lighter connecting cables preserving depth.

Deferred intentionally:

- Jump landing feedback and aim-aware camera framing require hands-on feel comparison and were not mixed into the three higher-priority changes.

## Vertical-slice core-feel audit

Ranked findings before this pass:

1. Air control reused the stronger ground acceleration/deceleration/turn values, while landing had no weight cue.
2. The prototype had no audio and no middle feedback tier between ordinary damage and a kill.
3. Camera composition used velocity only, so aiming ahead while stationary or against movement did not affect visible combat space.
4. Runners still rely primarily on approach motion as their contact warning.
5. Physical-controller feel and real 1–3 minute pacing still lack measured playtest data.

Top three changes:

- Ground movement remains `260 / 1600 / 2000 / 2600` for max speed, acceleration, deceleration, and reversal. Air movement now uses `1050 / 500 / 1450`, retaining momentum without removing the ability to reverse within a full jump. Landing above `260 px/s` triggers a 0.16-second `0.82 → 1.06 → 1.0` squash/overshoot, a small floor effect, a low landing cue, and at most `0.045` camera trauma.
- Runtime-generated legal placeholder SFX now cover normal/accent player shots, enemy shot, normal/accent/terrain impacts, kill, hurt, warning, reload, landing, and completion. No external audio asset was added. Every fourth shot is a 34-damage accent round; normal damage remains 24. Feedback strengths are terrain `0.22`, normal `0.62`, accent `0.94`, with kill retaining its larger death burst.
- Camera velocity look factor changed from `0.42` with a pure `115 px` cap to movement factor `0.32`/movement cap `85 px` plus `55 px` aim space, combined cap `125 px`, and look-response `7.0`. Vertical camera position remains fixed, shake/recoil still return to the tracking origin, and level-edge clamping is unchanged.

Parameter ownership:

- Movement, enemy, camera, feedback, and restart tuning lives in `scripts/config/game_tuning.gd`; the four player weapon definitions live in `scripts/weapons/weapon_catalog.gd`.
- Behavior remains in the existing player/enemy/camera/projectile scripts; no service locator, data framework, or broad architectural rewrite was introduced.

## Difficulty, pacing, and full-run acceptance audit

Pre-change scripted baseline:

- Default-rifle completion: 26.73 seconds; encounters 0.93/1.53/3.60/1.64 seconds; Boss phases 2.23/1.93/3.24 seconds.
- Rifle alone fired 108 shots, registered 85 hits, dealt 2250 recorded damage, and received all 10 kills. The other three weapons had no active role in that strategy.
- A nine-enemy pressure probe produced nine simultaneous telegraphs. Gunner and elite attack entry distances were 620/650 px, allowing attacks to begin at or beyond the intended readable edge.
- Boss failure reloaded the full ordinary mission. The pre-Boss recovery was only 25 HP and did not prevent an evidenced 21→46 HP Boss entry; Boss/support warnings could overlap without an explicit semantic gate.

Five ranked findings:

1. Unlimited enemy attack concurrency and 620–650 px ranged attack entry created the strongest unfair-damage risk.
2. Boss death repeated the already-cleared ordinary mission, making a learned Boss retry unnecessarily slow.
3. Weak Boss preparation plus Boss/support overlap could turn prior attrition into an avoidable dead-end.
4. A rifle-only bot could complete every authored role, so encounter-driven reasons to switch were not being verified.
5. The roughly 7.4-second Boss baseline, especially the 1.93-second second phase, was too short to reliably present its existing mechanics.

Top three problem groups fixed:

- A lightweight attack director now caps normal simultaneous telegraphs at two, Boss support at one, inserts a 0.65-second high-risk warning gap, and suppresses support attack starts during a Boss telegraph/active window. Ranged entry is capped at 520 px. The same nine-enemy probe now produces two simultaneous telegraphs.
- Encounter groups unlock in order with a 0.55-second recovery buffer. The pre-Boss command cache is one-shot, restores full health, and raises every magazine to at least 60%; summon attack grace is 1.10 seconds.
- Boss-stage death sets a narrow in-memory checkpoint flag and reloads a clean scene into fresh Phase I in roughly 1.6 seconds. Player health/ammo, Boss/HUD/arena/audio reset; old projectiles and hazards are absent. Ordinary-stage death still restarts the mission.

Measured post-change evidence:

- Mixed-role completion: 30.15 seconds; encounters 1.23/1.41/2.26/4.99 seconds; Boss phases 1.88/5.65/4.19 seconds; max active enemies two; max attacking enemies one.
- Scattergun: 11 shots/30 pellet hits/409 damage/5 kills. Rail lance: 10/11/1012/4. Rifle: 19/19/506/0. Sidearm: 13/12/384/1. All four therefore contribute without changing their existing damage, fire-rate, spread, falloff, or ammunition definitions.
- Debug-only telemetry now also records selected-weapon seconds, per-kind enemy active lifetime, damage source, death cause/position, encounter/Boss timing, and session completion. It is local memory only and is absent from release builds.
- The Boss health increase from 820 to 1200 is the only combat durability change in this pass. It was made after the measured phase-duration outlier; Boss attack damage, cadence, phase thresholds, player movement, weapon balance, ordinary enemy health, AI roles, level coordinates, art, audio, and HUD layout remain unchanged.

The scripted bot deliberately pins a safe Boss-arena test station and grants test-only invulnerability so its result measures weapon-role throughput rather than claiming human survival fairness. Dedicated tests separately cover warning concurrency, readable range, damage sources, death cleanup, and checkpoint recovery. Human new-player/expert/controller/pressure sessions remain the acceptance boundary.

## Complete arcade mission expansion

Modification baseline:

- The prior complete automation took 30.15 seconds and reached the Boss at about 18.43 seconds.
- The route was only 4300 px, held nine resident enemies in four short groups, and had no forward encounter gate. The content was genuinely short; no broken trigger or premature enemy cleanup explained the result.
- A continuously moving player could reach the Boss route before the existing combat groups had enough spatial or wave structure to form a complete mission.

Implemented structure:

- The route is 20,000 px. At the unchanged maximum run speed, the 2600 px distance from spawn to the first trigger is exactly 10 seconds before combat, shortening the overlong opening without a forced wait or movement-speed change.
- Four sectors use trigger positions at x=2830/7800/10800/13600 and forward gates at x=5200/10500/13300/16200. They contain 7/6/8/7 enemies across 3/2/3/3 waves and immediately reopen after their final wave.
- The sectors progress from assault/gunner teaching, to elevated ranged pressure, to shield displacement, to an elite-centered climax. The existing two-telegraph cap and 520 px ranged readability rules remain unchanged.
- A 30-second no-kill watchdog repositions all surviving progress enemies to readable ground positions. It was added after an expanded-run test exposed a real final-wave in-bounds path/line-of-fire stall; it never awards a kill or bypasses the wave.
- Four original pickups provide +20/+25 health or 35%/45% magazine floors; the refinement adds one finite +1 grenade pickup after first contact. The Boss cache adds 45 health, raises magazines to a 60% floor, and restores up to two grenades. Three warned 72 px spike strips, ten reachable static platforms, and two vertical moving platforms provide limited environmental variation without changing jump physics.
- Settlement uses existing counters for elapsed time, score, kills, projectile-based accuracy, damage events, rank, and remaining health. Boss-checkpoint reload retains those mission counters while fully resetting Boss, hazards, projectiles, HUD, music, and SFX.

Measured post-change evidence:

- Before refinement, the automated run reached Boss combat at 118.82 seconds and settlement at 131.66 seconds without exercising roll or grenade. The refined run deliberately performed one successful roll and one 55% grenade throw, reached Boss combat at 126.99 seconds, and settled at 139.74 seconds; Boss phases remained effectively stable at 2.54/5.86/4.36 seconds.
- It defeated all 28 regular enemies, exercised all four firearms plus both new abilities, recorded maximum three active enemies and one attacking enemy, and reached settlement without a gate bypass. Its one moving-target grenade missed, while the dedicated static-target check resolved 80 elite, 47 ranged shield, and 80 Boss damage exactly once; live-target grenade hit rate remains a human tuning question.
- This runner is deliberately invulnerable and applies scripted movement/aim/fire plus ordinary traversal jumps, so 139.74 seconds is a throughput floor, not a human playtime claim. The authored timing targets are 350–460 seconds for a first clear and 240–360 seconds for a skilled clear.
- Automated contracts prove the closed 720 px gate collides with the player route, the Boss cannot activate before mission completion, first contact is 10 seconds from spawn, elevated platforms and every road hazard can be cleared with unchanged movement, stalled enemies are recovered rather than deleted, supplies remain limited, and a Phase II Boss death restores a clean checkpoint in about 1.6 seconds with no old grenade.

## Roll and grenade implementation

- Roll input is recognized from non-echo action press events, keeping left and right tap caches independent. The selected window remains 0.25 seconds; roll lasts 0.30 seconds at 340 px/s and measures 107.7 px in the executable test, approximately three 34 px collision-body widths. Cooldown remains 0.50 seconds after completion.
- Invalid/CD input no longer arms a delayed tap cache, focused UI ignores direction taps, and death/pause/focus loss/reload clear the appropriate transient state. A roll cancels an unthrown grenade charge without consuming it. Roll keeps terrain, gate, and arena collision active.
- `projectile` damage is discarded before hurt, knockback, flash, or ordinary invulnerability begins; melee, contact, explosion, and environment damage are not discarded. A cyan graze spark and rate-limited low-volume cue confirm a successful projectile dodge without large text.
- Grenade charge uses a 1.0-second ping-pong cycle. Charge maps continuously to 340–820 px/s plus 25% of player horizontal velocity, with 1200 px/s² gravity, 0.56 bounce retention, five-bounce cap, and 1.70-second pause-safe fuse with accelerating final ticks.
- The centered world-space meter no longer jumps on facing changes. The 5–8-point preview begins at the real safe spawn point and stops at the first terrain collision. The 110 px explosion deals 80 at its center and falls to 44 at the edge, resolves each target once, applies 360 outward knockback, and does not self-damage in current PVE.
- F3 and `RunTelemetry` report attempts/successes/dodges plus grenade throws, average charge, hits, kills, and damage by target type. One +1 route pickup and up to two Boss-cache grenades keep the default three-grenade resource finite; no inventory framework was added.
- The opening prompts teach the roll before one readable gunner and the grenade before a compact three-assault wave. Each prompt fades after the first successful use. Enemy count, Boss health, phase thresholds, attack timing, and damage values remain unchanged.

## Headshot-number and weapon-audio refinement

- `DamageNumberManager` now passes only `final_damage` to a headshot label. Ordinary damage remains 18 px, 0.56 seconds, and 42 px rise; a headshot uses 22 px gold `#FFD34E`, dark-orange `#963B2B` outline, 0.68 seconds, and 56 px rise. Its 1.08 node scale combined with the font-size change settles at about 1.32× ordinary visual size, after a 0.075-second 0.80→1.15 pop and a 0.185-second settle.
- Headshots retain priority 3 in the existing fixed 64-label pool and displace lower-priority numbers at the ten-label per-target cap. Each valid automatic-fire headshot still presents its actual value with serial horizontal offset; only redundant `HEAD`/`HEADSHOT`/`CRIT` text was removed.
- Original runtime synthesis supports optional per-cue tail, low-thump, and high-crack shaping. Measured main-body signatures are rifle 70 ms/0.430 peak/0.089 RMS, shotgun 225 ms/0.613/0.117, sniper 270 ms/0.682/0.144, and pistol 65 ms/0.440/0.099. Complete layered shotgun/sniper events remain below 0.50 pre-limiter peak; source samples clamp at 0.78 and Master retains its -1 dB ceiling/-3 dB threshold limiter.
- Rifle and pistol pitch variation remain ±1.6% and ±1.4%; shotgun and sniper use ±0.5% and ±0.3%. The existing 20-voice pool, cue cooldowns, per-cue caps, and priority stealing remain authoritative. Executable wiring checks pass a real seven-pellet shotgun volley and verify exactly one shotgun body/air/pump event, plus exactly one sniper body/crack/tail/bolt event.
- `tests/survival_headshot_pacing_test.gd` locks exact numeric-only presentation, color, outline, pop phases, 2.0 damage truth, shield/Boss rules, pool cleanup, TTK, and wave values. `tests/audio_system_test.gd` locks bus routing, voice count, level order, signature shape/duration, subtle pitch ranges, source peak/RMS headroom, actual firing/mechanical event wiring, pause mix, Boss priority, and music ducking.
- `tests/sniper_accuracy_test.gd` locks exact muzzle-to-mouse direction and projectile rotation through PVE/survival, bidirectional near/mid/far and vertical aim, standing/moving/airborne velocities, and 720p/1080p/1440p canvas transforms. Its catalog guard also locks damage, rate, projectile speed/count, magazine, reload, and penetration values.
- `./scripts/verify_prototype.sh` passes PVE, all player abilities, four-weapon combat, sniper precision, Boss, pause/restart, Roguelite isolation, structural and scripted ten-wave survival, rifle-only pressure, and the 120-frame runtime check.

## Validation evidence

Primary command:

```bash
./scripts/verify_prototype.sh
```

Recorded output:

```text
PHASE0_SMOKE_PASS Godot 4.7-stable (official); 15 input actions; main scene and debug overlay loaded
PHASE0_VERIFY_PASS smoke, main-scene boot, roadmap uniqueness, and source hygiene checks passed
PHASE1_HORIZONTAL_PASS accel=0.167s stop=0.133s reverse_zero=0.100s reverse_90=0.250s max=260px/s
PHASE1_HORIZONTAL_VERIFY_PASS Phase 0 regression and horizontal movement checks passed
PROTOTYPE_SMOKE_PASS movement, weighted landing, aim framing, automatic fire, procedural audio, feedback tiers, staged enemies, boss arena, settlement
WEAPON_SYSTEM_PASS switching, hold-fire isolation, rifle auto, shotgun spread/falloff/single-death, sniper penetration/elite-stop, pistol precision, HUD
SNIPER_ACCURACY_PASS muzzle-to-mouse world ray, zero standing/moving/air spread, left/right near/mid/far/up/down, scrolling camera/Boss arena, 720p/1080p/1440p canvas transforms, PVE and survival
ENEMY_BOSS_PASS assault warning/recovery, gunner telegraph, shield front/opening, elite hazard, staged activation, boss phases/UI/attacks/summons/cleanup/settlement
ENEMY_VISUAL_PASS player 125% calibration, four role silhouettes, logic-driven locomotion/telegraph/attack/recover, gunner muzzle sync, shield block/break, elite stagger, death priority
PIXEL_UI_PASS nearest/snap baseline, 720p/1080p/1440p/ultrawide anchors, avatar/icons, weapon/ammo, health, boss layers/phases, pause audio/death/settlement
PLAYER_VISUAL_PASS separated physics/visuals, idle/run/jump/fall/land/hurt/death, bidirectional aim, four silhouettes/recoil profiles, muzzle-origin sync, restart reset
PLAYER_ABILITIES_PASS roll input/collision/projectile evade/cooldown plus grenade charge/ping-pong/trajectory/physics/single-hit damage/inventory/pause/death cleanup
PLAYER_ABILITIES_METRICS {"roll_cooldown":0.517,"roll_distance":107.7,"roll_duration":0.317,"throw_distances":[219.1,425.4,707.0]}
PLAYER_ABILITIES_MEASUREMENT_PASS bounded 3-body roll and distinct low/medium/high grenade arcs
COMBAT_FEEDBACK_PASS four pixel fire signatures, capped/optional shake, merged shotgun response, hit tiers, local hold, casing cleanup, unchanged balance
ENVIRONMENT_VISUAL_PASS pixel sky/far/mid/play/front layers, exact collision/platform/encounter contracts, bounded foreground, snapped scrolling, no smooth world primitives
LEVEL_MOBILITY_PASS 10-second opening contract, reachable elevated platform, three normally jumpable road hazards
BOSS_VISUAL_PASS layered industrial silhouette, exact collision/muzzles, three visual phases, logic-driven telegraphs, local hurt, one-shot death
BOSS_UI_FLOW_PASS intro/title timing, pause-safe fade, active hierarchy, one-shot phase toasts, integrated thresholds, defeat exit, compact HUD, control auto-hide
AUDIO_SYSTEM_PASS eight buses, Master limiter, original level/Boss loops, four weapon signatures and reload layers, spatial semantic combat/Boss/UI cues, bounded 20-voice pool, pause mix controls and semantic duck
RESTART_SMOKE_PASS phase-two death restored a clean full-resupply Boss checkpoint in about 1.6s, phase-one Boss/HUD/arena, no dangers or grenades, retained session audio mix
COMBAT_PACING_PASS four gated multi-wave sectors, immediate unlock, stall recovery, two-telegraph cap, 520px readability, limited Boss cache
SCRIPTED_PLAYTHROUGH_PASS expanded mission, four active weapon roles, gated waves, debug telemetry summary, encounter/Boss timings
MODE_SELECT_PASS project boots to an accessible PVE/survival selector and both independent scenes load
SURVIVAL_THREE_WAVE_PASS ordered waves, capped spawning, pause-safe countdown, unique kills, isolated HUD, death cleanup and restart
SURVIVAL_UPGRADE_PASS wave-two three-card loop, input isolation, twelve bounded upgrades, runtime reset and grenade synchronization
SURVIVAL_HEADSHOT_PACING_PASS actual damage numbers, head/body exclusivity, shield/Boss rules, bounded pool, TTK and wave curve
SURVIVAL_TEN_WAVE_PASS data-driven composition, elite milestones, capped spawns, three-phase Boss, single settlement, cleanup and local records
SURVIVAL_SCRIPTED_PASS ten-wave weapon playthrough, survival abilities and target-duration telemetry
PROTOTYPE_VERIFY_PASS PVE regression, survival 3/10-wave upgrade/headshot loops, mode selection, abilities, scripted playthroughs, and 120-frame runtime checks passed
```

Automated coverage includes all prior movement/camera/four-weapon contracts plus dormant activation, every enemy warning/recovery/damage rule, shield front/rear/opening behavior, elite area warning, idempotent death, Boss attack alternation, all three one-time thresholds, transition invulnerability, summon cap, HUD real/delayed values, intro/active/transition/defeat UI states, pause-safe fades, control auto-hide, eight audio buses, Master limiter, source peak headroom, semantic cue/event routing, spatial attenuation floors, original music crossfade, fixed voice count, dense-request rejection, pause/semantic duck, mix controls, rail-lance Boss stop, scattergun single Boss death, projectile/hazard/summon cleanup, arena release, settlement, and a real phase-two death reload retaining its session audio mix while restoring gameplay state.

Graphical validation:

- Godot graphical Movie Maker rendered 30 frames at 1280×720 and 60 FPS using OpenGL 4.1 over Metal on Apple M5.
- A rendered frame confirmed the player, enemies, health/ammo/score/objective UI, debug overlay, floor, platform, cover, foreground, midground city, distant mountains, and mission banner were visible and correctly layered.
- A post-polish rendered frame confirmed the debug overlay starts hidden and the reduced foreground density leaves enemies, crosshair, level geometry, and HUD unobstructed.
- A post-weapon rendered frame at `/private/tmp/bigshot-four-weapons.png` confirmed all four weapon slots remain visible, the rifle slot/current name are highlighted, the player and weapon silhouette are visible, and the original foreground/midground/background layering remains intact.
- Mid-encounter and Boss graphical captures rendered with OpenGL 4.1 over Metal at 1280×720. The enemy composition frame reported 73 FPS and the complete Boss/HUD/arena frame reported 67 FPS; neither emitted project script or resource errors.
- The first Boss capture exposed a 13 px HUD overlap. Boss anchors were narrowed from 24–76% to 27–73%, and the repeated render confirmed player health, Boss total health, and score panels no longer overlap while the full Boss remains visible.
- The graphical run emitted no project script or resource errors.
- Fresh captures were produced at exactly 1280×720, 1920×1080, and 2560×1440. Player, score, weapon, objective, and control regions stayed inside the viewport; the top-center Boss panel remained between the corner HUD regions. A 2560×1080 synthetic viewport test additionally verifies ultrawide anchors without stretching the authored 16:9 playfield.
- 720p is the authored 1× presentation and 1440p is a clean 2× presentation. 1080p preserves the same gameplay framing with nearest-filtered 1.5× scaling; it is intentionally a fractional compromise rather than claiming integer-perfect scaling.
- HUD camera-invariance checks move the player and camera into the Boss arena and prove the player/weapon rectangles do not move with the world camera. Pause/resume, damage/recovery, rapid weapon selection, Boss phase/delayed health, death, settlement, and clean restart state all pass in executable tests.
- Player graphical captures at 1280×720 show the original character and rifle/shotgun/sniper/pistol silhouettes inside the live level; a 2560×1440 capture confirms the same hard-edged 2× presentation. The four gun captures use a deterministic right-aim verification mode and do not alter runtime input behavior.
- Combat-character lineup captures at exact 1280×720, 1920×1080, and 2560×1440 show the cyan/gold player as the primary focal point, subdued but readable ordinary enemies, a shield-dominant defender, and a visibly larger elite. The 1440p capture reported 59 FPS and retained hard 2× pixel edges.
- A separate real-state capture holds each enemy inside its existing telegraph timer: assault brace, gunner aim, shield attack warning, and elite hazard-charge core remain readable beneath the shared orange/gold warning diamonds without covering the HUD.
- Final combat-effect captures at `/private/tmp/bigshot-fx-final-{rifle,shotgun,sniper,pistol}.png` show four distinct live muzzle/tracer silhouettes. `/private/tmp/bigshot-fx-final-impact-tiers.png` places normal, heavy, block, guard-break, and heavy-kill pixels together for direct contrast review.
- The pre-upgrade enemy-warning and geometric-Boss regression captures at 1280×720 reported 67 FPS and 66 FPS after 90 graphical frames on OpenGL 4.1/Metal; these remain historical before-state evidence.
- Exact 1920×1080 impact-tier and 2560×1440 rail-lance captures verify the same hard-edged effect shapes under the existing nearest/aspect-preserving viewport strategy. The graphical one-frame weapon captures are for appearance evidence, not performance claims.
- Environment before/after evidence is recorded at `/private/tmp/bigshot-environment-before-{start,combat,boss}.png` and `/private/tmp/bigshot-environment-final-720-{start,telegraphs,boss}.png`. The final captures show new sky/far/mid/play/front separation without foreground crossings or platform mismatch.
- Final environment files are exactly 1280×720, 1920×1080, and 2560×1440. The 720p telegraph/Boss captures reported 136/64 FPS, the 1080p combat capture 66 FPS, and the 1440p Boss capture 63 FPS on OpenGL 4.1/Metal; none emitted project script or resource errors.
- Final Iron Tempest captures at `/private/tmp/bigshot-boss-final-{720-phase1,1080-phase2,1440-phase3}.png` are exactly 1280×720, 1920×1080, and 2560×1440. They show complete armor, one-sided damage/core exposure, and asymmetric overload damage with stable top-center HUD anchors and hard-edged project pixels.
- `/private/tmp/bigshot-boss-final-charge-telegraph.png` verifies the compressed charge pose plus ground chevrons point toward the real charge side. Separate volley/area/transition/death captures verify cannon light, belly emitter, finite phase debris, zeroed health, and the staged shutdown without persistent danger nodes.
- The post-upgrade primary suite adds `BOSS_VISUAL_PASS` and still reaches `PROTOTYPE_VERIFY_PASS`; the 120-frame runtime and all graphical captures emitted no script, resource-load, or persistent runtime errors.
- Final HUD hierarchy captures at `/private/tmp/bigshot-ui-final-{720-boss-active,1080-phase-transition,1440-phase3}.png` are exactly 1280×720, 1920×1080, and 2560×1440. They show the compact permanent panels, no active-combat central title/objective/control strip, integrated Boss thresholds, and a non-obstructive phase toast.
- Additional exact 1280×720 captures cover clean combat, player death, and settlement. Death has only the retry overlay; settlement replaces the Boss panel and every transient notice. The requested graphical 2560×1080 window was capped by the current physical display at 1920×1080, so ultrawide is claimed only from the passing synthetic SubViewport layout contract, not from that limited screenshot.
- The final permanent player/weapon/score/Boss rectangles occupy about 11.5% of the logical frame, down from the recorded 15.5% baseline (roughly 25% relative reduction). The primary suite now includes `BOSS_UI_FLOW_PASS` and reports no script, parse, or resource-load error.
- `/private/tmp/bigshot-audio-final-pause.png` is an exact 1280×720 graphical capture of the live pause panel. Master/Music/SFX rows, decrement/value/increment/mute controls, Continue, and Restart all remain inside the shared pixel panel without covering the permanent corner HUD.
- Audio source-data checks hold selected weapon, impact, Boss-death, level-music, and Boss-music peaks below 0.80 linear before bus gain/limiting. A 48-request dense-hit burst plus mixed events never exceeds the fixed 20 SFX voices and produces no temporary-player growth.

## Human acceptance checklist

New-player session (do not explain enemy or Boss rules first):

- Record the first time the player switches away from the rifle and why; note any weapon whose purpose is not understood.
- Record every damage event the player cannot explain immediately, especially ranged/off-screen hits and Boss/support combinations.
- Record first-clear or first-death time, death location/cause, health/ammo entering the Boss, and whether retry is chosen immediately.

Skilled-player session:

- Attempt a fast clear and a rifle-only clear; look for skipped encounter gates, permanent safe positions, AI stalls, or one weapon dominating every role.
- Check whether shield/elite recovery windows and all three Boss phases can be deliberately exploited without engaging their intended rules.
- Compare shotgun close pressure, rail-lance lined targets, rifle suppression, and sidearm mobile precision; each should create a voluntary switch reason.

Pressure/reliability session:

- Rapidly switch 1–4 while firing, fight at the maximum authored enemy count, and cross Boss thresholds with shotgun/rail-lance burst damage.
- Repeatedly pause/resume, die/retry in ordinary combat and every Boss phase, and confirm no old warning, projectile, audio, HUD, or statistics state remains.
- Enter the Boss with low health/ammo, verify the one-time command cache, then confirm a Boss retry restores full resources and control in about three seconds or less.

## Run and controls

```bash
godot --path /Users/darkeryi/Documents/BigShot
```

- Move: A/D, arrow keys, or controller left stick.
- Jump: Space or controller south face button.
- Aim: mouse or controller right stick.
- Fire: left mouse, J, or controller west face button.
- Weapons: number keys 1 auto rifle, 2 scattergun, 3 rail lance, 4 sidearm.
- Reload: R or controller north face button.
- Diagnostics: F3.
- Camera shake: F4 cycles 100%, 50%, and OFF.
- Pause/resume: Escape; the pause panel also provides Continue and Restart.
- Pause audio: Master/Music/SFX can be adjusted in 10% steps or muted for the current application session.
- Replay after completion: Enter or controller Start.

Objective: advance through four gated sectors and eleven waves, use the traversal and supply spaces, enter the command arena, defeat all three Iron Tempest phases, then review the mission settlement. Ordinary-stage death restarts the mission; Boss-stage death returns to a clean Phase I checkpoint.

## Known limitations

- The original procedural mix is structurally bounded and conservative, but perceived loudness, repetition, fatigue, bass response, and Boss/music hierarchy still require human listening on speakers and headphones.
- Assault/gunner/shield/elite and Boss telegraphs are implemented and automated concurrency is bounded, but final reaction windows and mixed-pressure fairness still need human full-run playtests.
- Mouse aiming, camera look-ahead, projectile speed, difficulty, and the authored first-run 5–8 minute/skilled 4–6 minute completion targets need human playtesting and tuning.
- Controller bindings are defined but have not been verified on a physical controller.
- Final weapon loudness, shotgun/rail-lance impulse comfort, pixel-flash brightness, and moving/airborne readability require hands-on comparison; automated tests verify bounds and state, not subjective comfort.
- Crouching, general checkpoints, saved progress, production sprite sheets, and broader content variety are not implemented. Grenades are intentionally capped at three and use only one finite route pickup plus the Boss cache; no inventory system exists.
- Enemies use direct horizontal pursuit rather than navigation, cover selection, or sophisticated platform traversal.
- The first Git baseline and the roll/grenade feature branch exist in the linked GitHub repository; this refinement is committed only after the full verifier remains green.
- Engine-default font rendering remains a replaceable placeholder. Generated audio/music, shared styles, palette, avatar, layered player/four weapons, four enemy roles, combat effects, complete layered environment, and Iron Tempest procedural Boss are project-authored original prototype assets; audio can later be replaced with mastered recordings without changing event calls.
- Integer-perfect output is guaranteed at 1280×720 and 2560×1440. The supported 1920×1080 path is clear and correctly laid out but necessarily uses a 1.5× scale while the 1280×720 gameplay framing is preserved.
- Survival upgrades are lifecycle- and boundary-tested, but automated bots cannot determine whether choices feel equally exciting, whether descriptions scan quickly enough, or whether a dominant Build emerges during human play.
- Headshot geometry, actual-damage labels, and bounded display pressure are executable-tested, but a human still needs to judge whether moving head areas feel fair, automatic-fire numbers remain legible, and the rifle-only 5:53 pressure clear makes the rifle too dominant.

## Highest-value next improvements

1. Run timed new-player and skilled-player clears of the expanded mission on keyboard/mouse, then repeat the pressure/retry checklist and one physical-controller run. Record elapsed time, deaths, weapon choices, health/ammo at Boss entry, and any gate stall.
2. Run two human ten-wave survival sessions with headshots and the upgrade overlay enabled; record clear/death time, body/head TTK, number readability, every offered/selected card, weapon use, and supply sufficiency.
3. Compare mixed play with a rifle-only/headshot-focused clear. Tune only evidenced health, number-density, wave, or selection parameters; do not add content or couple survival values to PVE defaults.
