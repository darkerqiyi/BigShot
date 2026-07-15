#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/bigshot-phase0.XXXXXX")"
trap 'rm -rf "$LOG_DIR"' EXIT
mkdir -p "$LOG_DIR/home"
export HOME="$LOG_DIR/home"

cd "$ROOT"

fail_on_engine_errors() {
	local log_file="$1"
	local filtered_errors
	filtered_errors="$(grep -E "SCRIPT ERROR|Parse Error|Failed to load script|ERROR:" "$log_file" | grep -v 'get_system_ca_certificates' | grep -v 'Condition "ret != noErr"' || true)"
	if [[ -n "$filtered_errors" ]]; then
		printf 'Engine error detected in %s\n' "$log_file" >&2
		printf '%s\n' "$filtered_errors" >&2
		exit 1
	fi
}

roadmap_count="$(find . -path './.git' -prune -o -iname 'ROADMAP.md' -print | wc -l | tr -d ' ')"
if [[ "$roadmap_count" != "1" ]]; then
	printf 'Expected exactly one ROADMAP.md, found %s\n' "$roadmap_count" >&2
	exit 1
fi

if rg -n '[[:blank:]]+$' --glob '*.gd' --glob '*.tscn' --glob '*.md' --glob '*.sh' --glob 'project.godot' .; then
	printf 'Trailing whitespace detected\n' >&2
	exit 1
fi

if ! "$GODOT_BIN" --headless --path "$ROOT" --script res://tests/phase0_smoke.gd >"$LOG_DIR/smoke.log" 2>&1; then
	cat "$LOG_DIR/smoke.log" >&2
	exit 1
fi
fail_on_engine_errors "$LOG_DIR/smoke.log"
grep "PHASE0_SMOKE_PASS" "$LOG_DIR/smoke.log"

if ! "$GODOT_BIN" --headless --path "$ROOT" --quit-after 2 >"$LOG_DIR/run.log" 2>&1; then
	cat "$LOG_DIR/run.log" >&2
	exit 1
fi
fail_on_engine_errors "$LOG_DIR/run.log"

git diff --check
printf 'PHASE0_VERIFY_PASS smoke, main-scene boot, roadmap uniqueness, and source hygiene checks passed\n'
