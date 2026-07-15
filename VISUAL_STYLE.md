# BigShot Pixel Visual Style

This is the project's only visual-style specification. It applies to original project-authored UI and procedural placeholder art.

## Direction

- Keywords: bright fantasy-tech, rounded pixel silhouette, readable arcade action, adventurous interface, forceful combat.
- Originality: borrow only general clarity and iconography principles; never reproduce another game's characters, icons, fonts, layouts, branding, or assets.
- Logical resolution: 1280×720. The existing 4300 px world, camera limits, encounter framing, and UI coordinates are authored for this baseline.
- Pixel grid: 2 logical pixels for UI borders and alignment; 4 logical pixels for icon construction. World transforms and camera follow snap to whole logical pixels.
- Scaling: nearest filtering. 720p is 1× and 1440p is 2× pixel-clean. 1080p uses nearest 1.5× fractional scaling to preserve framing; minor uneven pixel widths are an accepted prototype compromise. Aspect ratio is preserved with letterboxing rather than stretching.

## Palette

| Role | Hex |
| --- | --- |
| Ink / outline | `#10243A` |
| Panel | `#183852` |
| Panel highlight | `#245273` |
| Primary cyan | `#45D8D0` |
| Adventure gold | `#FFD35A` |
| Health green | `#55E39A` |
| Shield blue | `#65C8FF` |
| Danger coral | `#FF5A62` |
| Boss magenta | `#D967FF` |
| Boss armor dark | `#4B315F` |
| Boss armor | `#74466F` |
| Boss core red | `#F04D5E` |
| Boss damage arc | `#D3F4FF` |
| Text cream | `#FFF4D2` |
| Muted / disabled | `#718395` |

## UI construction

- Common icons: 32×32 or 40×32; avatar: 56×56; all shapes use the 4 px icon grid.
- Spacing: 4 px micro gap, 8 px component gap, 12 px panel inset, 20 px safe-screen inset.
- Panels: 4 px dark outer border plus 2 px colored inner/readability edge; corner radius is 6 px with antialiasing disabled.
- Buttons: minimum 44 px height; normal, hover/focus, pressed, and disabled states use the shared theme.
- Bars: 18–24 px tall, 3 px border, immediate value layer; delayed layer only where gameplay already supplies meaningful high damage (Boss).
- Type hierarchy: 28–32 px state title, 18–20 px section/Boss title, 16 px HUD body, 12–13 px metadata. The engine default font is a readable temporary placeholder until an original or suitably licensed pixel font is selected.
- Shadows/highlights: one 2 px hard shadow; one upper-left highlight edge. No soft glow behind body text.
- Animation: 0.08–0.18 s for selection/damage feedback, 0.20–0.35 s for panel entry/exit, never delay gameplay state.
- Permanent 1280×720 HUD bounds: player 296×96, weapon 252×128, score 160×36, Boss 512×78. Responsive anchors keep the Boss panel between corner HUD regions; an optional snapped UI scale basis exposes 80%, 90%, and 100% without stretching individual borders.
- Boss information hierarchy: only the top name/health/phase panel persists during combat. Intro identity, mission updates, phase-transition copy, and defeat copy are mutually exclusive transient messages. Phase thresholds are hard pixel marks inside the health track at 65% and 30%, never detached percentage captions.
- Control help appears at mission start, fades after four seconds or first gameplay input, and is suppressed before Boss combat. Debug-key copy is allowed only in debug builds; the pause overlay is the durable place to review controls.

## Components and naming

- Shared style source: `scripts/ui/pixel_ui_style.gd`.
- Shared procedural icons: `scripts/ui/pixel_icon.gd`.
- Screen UI scenes: `scenes/ui/`; reusable visual resources: `resources/ui/` if bitmap/NinePatch assets are introduced later.
- Naming: `ui_<role>_<state>`, `icon_<subject>_<size>`, `fx_<event>_<variant>`.
- Current programmatic UI, player/weapons, enemy roles, combat effects, layered environment, and Iron Tempest Boss are original project assets suitable for continued prototype use. The player is built on a 4 px construction grid with a 34×64 unchanged physics envelope. The engine default font remains an explicit placeholder.
- Player visual naming: `PlayerVisual/BodySprite`, `WeaponPivot/{BackArm,WeaponSprite,FrontArm,MuzzlePoint}`, and `VisualEffects`. Visual animation may consume physics state but never write movement, collision, health, damage, or weapon-balance values.

## World combat characters

- Player calibration: `PlayerVisual` uses a 1.25 visual scale and -8 px vertical compensation. The 4 px construction grid becomes 5 px at the 720p baseline while the 34×64 collision body and foot line remain unchanged.
- Normal enemies retain the 38×58 collision envelope and use roughly 58–64 px authored silhouettes. The elite retains its existing 1.28 root/collision scale but uses a separately drawn heavy body rather than a scaled normal soldier.
- Shared outline: ink `#10243A` plus enemy-purple ink `#30263B`; never pure black. Player remains cyan/gold. Enemy bodies use warm red `#E65345`, dark red `#8F3440`, orange `#F49A36`, purple `#72426F`, and elite highlight `#B95D8D`.
- Enemy warnings reserve bright orange/gold and must exceed the body value contrast. Shield blocks reserve shield blue `#65C8FF`; hurt edges use cream `#FFF4D2`.
- Animation is pose-driven at 8–14 readable changes per second. AI state/timers are authoritative; visual one-shots may overlap recovery but never emit damage, change velocity, or extend a telegraph.
- Enemy visual naming: `EnemyVisual/{MuzzlePoint,MuzzleFlash,VisualEffects}`. Facing is redrawn from a sign value; visual and collision nodes must keep positive scale.

## Combat effects

- All runtime combat effects use integer-positioned rectangles or polygons at the shared logical-pixel density. Smooth particle textures, blurred glow sprites, and unbounded emitters are not part of the current effect language.
- Player-fire colors remain weapon-readable: rifle gold, shotgun orange/copper, rail lance cyan, sidearm mint. Hostile fire and danger warnings reserve coral/orange; shield blocks reserve cyan; guard breaks combine gold and orange.
- Projectile signatures are silhouette contracts: rifle is a medium segmented tracer, shotgun uses short chunky pellets, rail lance uses a long two-pixel core plus brief afterimage, and sidearm uses a short thin tracer.
- Impact priority is `terrain < normal < heavy < block < guard break < light kill < heavy kill`. Boss normal hits only brighten the core; heavy Boss hits may brighten the body briefly. Effects must not obscure the warning diamond or attack direction.
- Muzzle flashes last 0.045–0.078 seconds. Impact effects last 0.16–0.46 seconds. Heavy-event emphasis is a local peak-frame hold of at most 0.045 seconds; global time scale remains 1.0.
- Camera trauma is centralized, profile-capped, and same-frame multi-hit requests are merged. F4 cycles 100%, 50%, and OFF for accessibility/testing. UI remains in CanvasLayer and never inherits camera displacement.
- Pixel casings are decorative only, live for at most 0.48 seconds, and are capped at 12 nodes. Every effect owns a finite lifetime and must clean itself without gameplay authority.

## Iron Tempest Boss

- Silhouette: low, broad industrial machine with separated feet, reactor hull, sensor head, ram arm, cannon, and a central diamond core. Authored extents may exceed the unchanged 112×122 hit body; art never owns collision.
- Layer names: `BossVisual/{Shadow,LowerBody,MainBody,ArmorFront,Core,LeftWeapon,RightWeapon,DamageEffects,MuzzlePoints,GroundContactEffects}`. Projectile markers remain exactly x `±62`, y `-26` relative to the physics root.
- Phase language is structural: Phase I has complete paired armor and a protected core; Phase II removes one shoulder plate and exposes machinery; Phase III leaves asymmetric armor stubs and a large pulsing overload core. Color change alone is never sufficient.
- Attack language: cannon-side segmented light means volley, a compressed body plus ground chevrons means charge, and a widening orange belly/ground emitter means area attack. The shared warning diamond remains above all three.
- Orange/gold is reserved for Boss telegraph energy, core red for stable hostile power, cyan-white for damage arcs and heavy-hit accents. Steam, arcs, debris, and explosions are deterministic, capped draw primitives with no persistent emitter nodes.
- Boss visual state reads `state`, pending attack, windup, transition, health phase, and target direction from the gameplay node. It may offset or compress only drawn pixels; it never changes collision, velocity, attack ranges, damage, invulnerability, or scheduler timers.

## World environment

- Environment keywords: luminous frontier city, fantasy-tech transit deck, readable industrial adventure, restrained crystalline growth. The world uses original procedural geometry only and does not trace or reproduce reference-game scenery.
- Environment palette: sky ink `#10243A`, far blue `#244766`, horizon teal `#2B6670`, mid-body `#173F55`, mid-face `#20566A`, ground `#194852`, surface green `#55E39A`, environment cyan `#45D8D0`, utility gold `#FFD35A`, arena purple `#72426F`.
- `SkyPixels` is screen-space at 1280×720. Far and mid world layers retain 0.15 and 0.45 parallax; every transform is rounded to a logical pixel. Procedural coverage extends beyond both level edges so camera travel cannot expose a seam.
- The playable layer owns visual rectangles only. Ground top is y=584, level width is 4300, and platform art must exactly match `Rect2(730,470,260,22)`, `Rect2(1580,425,300,22)`, `Rect2(2730,475,250,22)`, and `Rect2(3400,410,280,22)`. Visual work never owns collision.
- Ground modules use 100 px bays, hard 4–8 px highlights, finite window colors, and dark structural gaps. Platforms use cyan collision edges and gold endpoints; danger coral remains reserved for attacks and the active Boss gate.
- Foreground decorations are sparse, translucent, and begin at y=568 or lower. They may overlap feet/ground for depth but must never cross the torso, weapon, projectile line, or enemy warning diamond.
- World drawing scripts use hard rectangles and polygons only. Smooth circles, arcs, antialiased lines, blurred particles, and high-frequency one-pixel noise are prohibited in these layers.

## Do not

- Do not use bilinear filtering, fractional world transforms, one-pixel hairlines, stretched raster borders, low-contrast text, or long UI animations.
- Do not put combat-critical warnings beneath opaque HUD panels.
- Do not add fake shield/ammo/stat values, decorative systems, or per-screen copies of the same style.
- Do not trace, extract, imitate, or rename protected assets from reference games.
