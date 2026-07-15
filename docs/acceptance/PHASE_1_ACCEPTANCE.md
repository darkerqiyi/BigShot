# Phase 1 Acceptance — Player Movement and Camera Feel

Phase 1 passes only when the behaviors below are implemented in an original gray-box test room and verified at the fixed 60 Hz physics rate. Values are initial testable targets, not permanent design promises; changes require an evidence note in `docs/CURRENT_STATUS.md`.

## Horizontal movement

- Holding left or right on ground reaches a capped speed of `260 ± 5 px/s` within `0.18 s` from rest.
- Releasing horizontal input from full speed reaches `≤ 5 px/s` within `0.14 s` without sliding or changing facing twice.
- Reversing direction from full speed crosses zero within `0.12 s` and reaches 90% of opposite max speed within `0.30 s` total.
- Opposite simultaneous keyboard inputs resolve to zero horizontal intent; analog stick magnitude below `0.25` produces no movement.
- Character motion produces the same measured displacement within 2% at rendered 30, 60, and 120 FPS while physics remains 60 Hz.

Current evidence for the horizontal slice, recorded 2026-07-13:

- Automated: max speed 260 px/s, acceleration 0.167 s, release-to-stop 0.133 s, reverse zero-cross 0.100 s, and reverse-to-90% 0.250 s.
- Automated: opposite digital inputs resolve to zero, action deadzone is 0.25, physics rate is 60 Hz, the player settles on the floor, and scene-level input moves the body.
- Pending manual evidence: physical gamepad behavior and displacement comparison at rendered 30/60/120 FPS.

## Jump

- A full jump from level ground reaches an apex `96 ± 8 px` above takeoff and returns to ground in `0.65 ± 0.08 s`.
- Releasing jump before `0.12 s` produces a short jump at least 30% lower than the full-jump apex.
- A jump pressed within `120 ms` before landing fires on the first eligible grounded physics tick.
- A jump pressed within `100 ms` after walking off a ledge still fires; a press later than `120 ms` does not.
- Horizontal air control cannot exceed ground max speed and remains responsive enough to reverse horizontal intent before landing from a full jump.

## Crouch and collision safety

- Crouch activates only while grounded, changes to a collider no taller than 65% of standing height, and exposes an explicit crouched state to diagnostics.
- Releasing crouch under an obstruction keeps the player crouched with no overlap; standing occurs on the first clear physics tick.
- Entering crouch never moves the character's feet by more than 1 pixel.

## Camera

- During steady rightward travel, the player remains between 35% and 55% of viewport width and the camera never reveals outside the test-room bounds.
- Direction reversal changes look-ahead smoothly over `0.20–0.35 s`; the camera does not snap across the player.
- A normal full jump does not move the camera vertically until the player crosses a 72 px vertical dead zone.
- Camera position is stable when the player is idle: no measurable subpixel drift over 5 seconds.

## Inputs and diagnostics

- All movement behaviors work through the existing action names on keyboard and one standard gamepad; no gameplay script reads raw key codes or button indices.
- Switching between keyboard/mouse and gamepad during play requires no restart and is reflected by the diagnostic overlay.
- Diagnostics show grounded, velocity, requested movement, crouched state, jump-buffer time, coyote time, camera position, and current physics FPS.

## Verification gate

- Automated tests cover action contract, acceleration/deceleration, jump buffer, coyote window, crouch clearance, and camera bounds.
- Headless project load emits no `SCRIPT ERROR`, `Parse Error`, `Failed to load script`, or project-originated engine `ERROR:` lines; documented host-environment warnings must be listed separately.
- A manual play check records keyboard and gamepad results, plus any acceptance item that cannot be proven headlessly.
- Existing Phase 0 verification remains green.
