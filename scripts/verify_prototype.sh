#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/bigshot-prototype.XXXXXX")"
trap 'rm -rf "$LOG_DIR"' EXIT
mkdir -p "$LOG_DIR/home"
export HOME="$LOG_DIR/home"

cd "$ROOT"
./scripts/verify_phase1_horizontal.sh

if ! "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/prototype_smoke_test.gd >"$LOG_DIR/prototype.log" 2>&1; then
	cat "$LOG_DIR/prototype.log" >&2
	exit 1
fi

filtered_errors="$(grep -E "SCRIPT ERROR|Parse Error|Failed to load script|ERROR:" "$LOG_DIR/prototype.log" | grep -v 'get_system_ca_certificates' | grep -v 'Condition "ret != noErr"' || true)"
if [[ -n "$filtered_errors" ]]; then
	printf '%s\n' "$filtered_errors" >&2
	exit 1
fi

grep "PROTOTYPE_SMOKE_PASS" "$LOG_DIR/prototype.log"

if ! "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/weapon_system_test.gd >"$LOG_DIR/weapons.log" 2>&1; then
	cat "$LOG_DIR/weapons.log" >&2
	exit 1
fi
filtered_errors="$(grep -E "SCRIPT ERROR|Parse Error|Failed to load script|ERROR:" "$LOG_DIR/weapons.log" | grep -v 'get_system_ca_certificates' | grep -v 'Condition "ret != noErr"' || true)"
if [[ -n "$filtered_errors" ]]; then
	printf '%s\n' "$filtered_errors" >&2
	exit 1
fi
grep "WEAPON_SYSTEM_PASS" "$LOG_DIR/weapons.log"

if ! "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/enemy_boss_test.gd >"$LOG_DIR/enemy_boss.log" 2>&1; then
	cat "$LOG_DIR/enemy_boss.log" >&2
	exit 1
fi
filtered_errors="$(grep -E "SCRIPT ERROR|Parse Error|Failed to load script|ERROR:" "$LOG_DIR/enemy_boss.log" | grep -v 'get_system_ca_certificates' | grep -v 'Condition "ret != noErr"' || true)"
if [[ -n "$filtered_errors" ]]; then
	printf '%s\n' "$filtered_errors" >&2
	exit 1
fi
grep "ENEMY_BOSS_PASS" "$LOG_DIR/enemy_boss.log"

if ! "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/enemy_visual_test.gd >"$LOG_DIR/enemy_visual.log" 2>&1; then
	cat "$LOG_DIR/enemy_visual.log" >&2
	exit 1
fi
filtered_errors="$(grep -E "SCRIPT ERROR|Parse Error|Failed to load script|ERROR:" "$LOG_DIR/enemy_visual.log" | grep -v 'get_system_ca_certificates' | grep -v 'Condition "ret != noErr"' || true)"
if [[ -n "$filtered_errors" ]]; then
	printf '%s\n' "$filtered_errors" >&2
	exit 1
fi
grep "ENEMY_VISUAL_PASS" "$LOG_DIR/enemy_visual.log"

if ! "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/pixel_ui_test.gd >"$LOG_DIR/pixel_ui.log" 2>&1; then
	cat "$LOG_DIR/pixel_ui.log" >&2
	exit 1
fi
filtered_errors="$(grep -E "SCRIPT ERROR|Parse Error|Failed to load script|ERROR:" "$LOG_DIR/pixel_ui.log" | grep -v 'get_system_ca_certificates' | grep -v 'Condition "ret != noErr"' || true)"
if [[ -n "$filtered_errors" ]]; then
	printf '%s\n' "$filtered_errors" >&2
	exit 1
fi
grep "PIXEL_UI_PASS" "$LOG_DIR/pixel_ui.log"

if ! "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/player_visual_test.gd >"$LOG_DIR/player_visual.log" 2>&1; then
	cat "$LOG_DIR/player_visual.log" >&2
	exit 1
fi
filtered_errors="$(grep -E "SCRIPT ERROR|Parse Error|Failed to load script|ERROR:" "$LOG_DIR/player_visual.log" | grep -v 'get_system_ca_certificates' | grep -v 'Condition "ret != noErr"' || true)"
if [[ -n "$filtered_errors" ]]; then
	printf '%s\n' "$filtered_errors" >&2
	exit 1
fi
grep "PLAYER_VISUAL_PASS" "$LOG_DIR/player_visual.log"

if ! "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/player_combat_abilities_test.gd >"$LOG_DIR/player_abilities.log" 2>&1; then
	cat "$LOG_DIR/player_abilities.log" >&2
	exit 1
fi
filtered_errors="$(grep -E "SCRIPT ERROR|Parse Error|Failed to load script|ERROR:" "$LOG_DIR/player_abilities.log" | grep -v 'get_system_ca_certificates' | grep -v 'Condition "ret != noErr"' || true)"
if [[ -n "$filtered_errors" ]]; then
	printf '%s\n' "$filtered_errors" >&2
	exit 1
fi
grep "PLAYER_ABILITIES_PASS" "$LOG_DIR/player_abilities.log"

if ! "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/combat_feedback_test.gd >"$LOG_DIR/combat_feedback.log" 2>&1; then
	cat "$LOG_DIR/combat_feedback.log" >&2
	exit 1
fi
filtered_errors="$(grep -E "SCRIPT ERROR|Parse Error|Failed to load script|ERROR:" "$LOG_DIR/combat_feedback.log" | grep -v 'get_system_ca_certificates' | grep -v 'Condition "ret != noErr"' || true)"
if [[ -n "$filtered_errors" ]]; then
	printf '%s\n' "$filtered_errors" >&2
	exit 1
fi
grep "COMBAT_FEEDBACK_PASS" "$LOG_DIR/combat_feedback.log"

if ! "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/environment_visual_test.gd >"$LOG_DIR/environment_visual.log" 2>&1; then
	cat "$LOG_DIR/environment_visual.log" >&2
	exit 1
fi
filtered_errors="$(grep -E "SCRIPT ERROR|Parse Error|Failed to load script|ERROR:" "$LOG_DIR/environment_visual.log" | grep -v 'get_system_ca_certificates' | grep -v 'Condition "ret != noErr"' || true)"
if [[ -n "$filtered_errors" ]]; then
	printf '%s\n' "$filtered_errors" >&2
	exit 1
fi
grep "ENVIRONMENT_VISUAL_PASS" "$LOG_DIR/environment_visual.log"

if ! "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/level_mobility_test.gd >"$LOG_DIR/level_mobility.log" 2>&1; then
	cat "$LOG_DIR/level_mobility.log" >&2
	exit 1
fi
filtered_errors="$(grep -E "SCRIPT ERROR|Parse Error|Failed to load script|ERROR:" "$LOG_DIR/level_mobility.log" | grep -v 'get_system_ca_certificates' | grep -v 'Condition "ret != noErr"' || true)"
if [[ -n "$filtered_errors" ]]; then
	printf '%s\n' "$filtered_errors" >&2
	exit 1
fi
grep "LEVEL_MOBILITY_PASS" "$LOG_DIR/level_mobility.log"

if ! "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/boss_visual_test.gd >"$LOG_DIR/boss_visual.log" 2>&1; then
	cat "$LOG_DIR/boss_visual.log" >&2
	exit 1
fi
filtered_errors="$(grep -E "SCRIPT ERROR|Parse Error|Failed to load script|ERROR:" "$LOG_DIR/boss_visual.log" | grep -v 'get_system_ca_certificates' | grep -v 'Condition "ret != noErr"' || true)"
if [[ -n "$filtered_errors" ]]; then
	printf '%s\n' "$filtered_errors" >&2
	exit 1
fi
grep "BOSS_VISUAL_PASS" "$LOG_DIR/boss_visual.log"

if ! "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/boss_ui_flow_test.gd >"$LOG_DIR/boss_ui_flow.log" 2>&1; then
	cat "$LOG_DIR/boss_ui_flow.log" >&2
	exit 1
fi
filtered_errors="$(grep -E "SCRIPT ERROR|Parse Error|Failed to load script|ERROR:" "$LOG_DIR/boss_ui_flow.log" | grep -v 'get_system_ca_certificates' | grep -v 'Condition "ret != noErr"' || true)"
if [[ -n "$filtered_errors" ]]; then
	printf '%s\n' "$filtered_errors" >&2
	exit 1
fi
grep "BOSS_UI_FLOW_PASS" "$LOG_DIR/boss_ui_flow.log"

if ! "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/audio_system_test.gd >"$LOG_DIR/audio_system.log" 2>&1; then
	cat "$LOG_DIR/audio_system.log" >&2
	exit 1
fi
filtered_errors="$(grep -E "SCRIPT ERROR|Parse Error|Failed to load script|ERROR:" "$LOG_DIR/audio_system.log" | grep -v 'get_system_ca_certificates' | grep -v 'Condition "ret != noErr"' || true)"
if [[ -n "$filtered_errors" ]]; then
	printf '%s\n' "$filtered_errors" >&2
	exit 1
fi
grep "AUDIO_SYSTEM_PASS" "$LOG_DIR/audio_system.log"

if ! "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/restart_smoke_test.gd >"$LOG_DIR/restart.log" 2>&1; then
	cat "$LOG_DIR/restart.log" >&2
	exit 1
fi
filtered_errors="$(grep -E "SCRIPT ERROR|Parse Error|Failed to load script|ERROR:" "$LOG_DIR/restart.log" | grep -v 'get_system_ca_certificates' | grep -v 'Condition "ret != noErr"' || true)"
if [[ -n "$filtered_errors" ]]; then
	printf '%s\n' "$filtered_errors" >&2
	exit 1
fi
grep "RESTART_SMOKE_PASS" "$LOG_DIR/restart.log"

if ! "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/combat_pacing_test.gd >"$LOG_DIR/combat_pacing.log" 2>&1; then
	cat "$LOG_DIR/combat_pacing.log" >&2
	exit 1
fi
filtered_errors="$(grep -E "SCRIPT ERROR|Parse Error|Failed to load script|ERROR:" "$LOG_DIR/combat_pacing.log" | grep -v 'get_system_ca_certificates' | grep -v 'Condition "ret != noErr"' || true)"
if [[ -n "$filtered_errors" ]]; then
	printf '%s\n' "$filtered_errors" >&2
	exit 1
fi
grep "COMBAT_PACING_PASS" "$LOG_DIR/combat_pacing.log"

if ! "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/scripted_playthrough_test.gd >"$LOG_DIR/scripted_playthrough.log" 2>&1; then
	cat "$LOG_DIR/scripted_playthrough.log" >&2
	exit 1
fi
filtered_errors="$(grep -E "SCRIPT ERROR|Parse Error|Failed to load script|ERROR:" "$LOG_DIR/scripted_playthrough.log" | grep -v 'get_system_ca_certificates' | grep -v 'Condition "ret != noErr"' || true)"
if [[ -n "$filtered_errors" ]]; then
	printf '%s\n' "$filtered_errors" >&2
	exit 1
fi
grep "SCRIPTED_PLAYTHROUGH_PASS" "$LOG_DIR/scripted_playthrough.log"

if ! "$GODOT_BIN" --headless --path "$ROOT" --quit-after 120 >"$LOG_DIR/runtime.log" 2>&1; then
	cat "$LOG_DIR/runtime.log" >&2
	exit 1
fi
filtered_errors="$(grep -E "SCRIPT ERROR|Parse Error|Failed to load script|ERROR:" "$LOG_DIR/runtime.log" | grep -v 'get_system_ca_certificates' | grep -v 'Condition "ret != noErr"' || true)"
if [[ -n "$filtered_errors" ]]; then
	printf '%s\n' "$filtered_errors" >&2
	exit 1
fi

printf 'PROTOTYPE_VERIFY_PASS regression, combat pacing, mixed-weapon playthrough, and 120-frame runtime checks passed\n'
