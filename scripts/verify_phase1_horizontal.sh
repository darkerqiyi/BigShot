#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/bigshot-phase1-horizontal.XXXXXX")"
trap 'rm -rf "$LOG_DIR"' EXIT
mkdir -p "$LOG_DIR/home"
export HOME="$LOG_DIR/home"

cd "$ROOT"

./scripts/verify_phase0.sh

if ! "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/phase1_horizontal_movement_test.gd >"$LOG_DIR/horizontal.log" 2>&1; then
	cat "$LOG_DIR/horizontal.log" >&2
	exit 1
fi

filtered_errors="$(grep -E "SCRIPT ERROR|Parse Error|Failed to load script|ERROR:" "$LOG_DIR/horizontal.log" | grep -v 'get_system_ca_certificates' | grep -v 'Condition "ret != noErr"' || true)"
if [[ -n "$filtered_errors" ]]; then
	printf '%s\n' "$filtered_errors" >&2
	exit 1
fi

grep "PHASE1_HORIZONTAL_PASS" "$LOG_DIR/horizontal.log"
printf 'PHASE1_HORIZONTAL_VERIFY_PASS Phase 0 regression and horizontal movement checks passed\n'

