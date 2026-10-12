#!/usr/bin/env bash
# One unattended check of the checked-out branch: what CI runs, then any
# two-window scenarios, with a summary of a few lines at the end.
#
#   GODOT=<4.8-dev7 binary> tools/verify.sh [--coop] [scenario ...]
#
#   --coop      only the co-op GUT suites (test_coop*) instead of the whole suite
#   scenario    names under tools/coop_screens/, run after the headless stages
#
# Stages: import, GUT, release gates, boot smoke test, ENet demo, three
# processes, then each scenario. Full logs and captures go to
# $VERIFY_OUT/<stamp>/ (default ~/dev-scratch/pokerecomp-coop/verify), the
# summary to <stamp>/summary.txt and stdout. Exits 0 only if every stage passed.
#
# Headless stages run with a private XDG_DATA_HOME, so tests never see the
# owner's campaigns, logs or identity, and under bwrap with an empty /dev when
# bwrap is installed, so plugged-in pads can't disturb timing tests. Scenarios
# keep their own private user folder (tools/coop_screens.sh).
set -uo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
godot="${GODOT:-godot}"
coop_only=0
scenarios=()
for a in "$@"; do
	case "$a" in
		--coop) coop_only=1 ;;
		-h|--help) sed -n '2,18p' "$0"; exit 0 ;;
		*) scenarios+=("$a") ;;
	esac
done

out="${VERIFY_OUT:-$HOME/dev-scratch/pokerecomp-coop/verify}/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$out/xdg" "$out/tmp"
summary="$out/summary.txt"
export TMPDIR="$out/tmp"
failed=0

note() { echo "$*" >> "$summary"; }
note "verify $(git -C "$root" rev-parse --abbrev-ref HEAD) @ $(git -C "$root" rev-parse --short HEAD) ($(date '+%F %T'))"

version="$("$godot" --version 2>/dev/null | tail -1)"
case "$version" in
	4.8.dev7*) ;;
	*) note "godot: '$godot' is '${version:-missing}', not 4.8-dev7"; note "RESULT: FAILURES"; cat "$summary"; exit 1 ;;
esac

sandbox=()
command -v bwrap >/dev/null && sandbox=(bwrap --dev-bind / / --dev /dev)

# stage <name> <cap seconds> <done line or ""> <command...>: a headless Godot run
# through tools/ci_godot.sh, its output in <name>.log.
stage() {
	local name="$1" cap="$2" done_line="$3"; shift 3
	if (cd "$root" && XDG_DATA_HOME="$out/xdg" GODOT_CAP="$cap" GODOT_DONE="$done_line" \
		"${sandbox[@]}" tools/ci_godot.sh "$@") > "$out/$name.log" 2>&1; then
		note "$name: ok"
	else
		note "$name: FAILED"
		failed=$((failed + 1))
	fi
}

# The editor import rewrites .import files it didn't need to change; put back
# the ones that were clean before it, so a run leaves the work tree as it was.
clean_imports="$(cd "$root" && git ls-files '*.import' | sort | comm -23 - <(git diff --name-only -- '*.import' | sort))"
stage import 600 "" "$godot" --headless --editor --path . --quit
(cd "$root" && git diff --name-only -- '*.import' | sort | comm -12 - <(echo "$clean_imports") | xargs -r git checkout --)

gut=(-s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit)
(( coop_only )) && gut+=(-gselect=test_coop)
stage gut 900 "---- All tests passed! ----" "$godot" --headless --path . "${gut[@]}"
plain="$(sed 's/\x1b\[[0-9;]*m//g' "$out/gut.log")"
counts="$(grep -E '^(Tests|Passing Tests|Failing Tests|Risky/Pending) ' <<< "$plain" | tr -s ' ' | paste -sd ',' -)"
[[ -n "$counts" ]] && note "  gut: $counts"
# each failing test once, as <script> <test>
awk '/^res:\/\/.*\.gd$/ { script = $0 } /^\* test_/ { test = $2 }
	/\[Failed\]/ && !seen[script test]++ { print "  FAILED: " script " " test }' <<< "$plain" | head -20 >> "$summary"

if (cd "$root" && tools/release.sh --gates) > "$out/gates.log" 2>&1; then
	note "gates: ok"
else
	note "gates: FAILED"
	failed=$((failed + 1))
fi

stage boot 180 "" "$godot" --headless --path . --quit-after 30
stage enet-demo 180 "coop demo: all" "$godot" --headless --path . -s res://tools/coop_session.gd -- demo

if (cd "$root" && XDG_DATA_HOME="$out/xdg" GODOT="$godot" "${sandbox[@]}" tools/coop_two_process.sh 24690 180) \
	> "$out/three-processes.log" 2>&1; then
	note "three-processes: ok"
else
	note "three-processes: FAILED"
	failed=$((failed + 1))
fi

for s in "${scenarios[@]}"; do
	if (cd "$root" && GODOT="$godot" tools/coop_screens.sh "$s" "$out/screens/$s") > "$out/screens-$s.log" 2>&1; then
		note "scenario $s: ok (captures in screens/$s)"
	else
		note "scenario $s: FAILED"
		failed=$((failed + 1))
	fi
done

rm -rf "$out/tmp"
if (( failed )); then
	note "RESULT: FAILURES ($failed stage(s); logs in $out)"
else
	note "RESULT: all passed (logs in $out)"
fi
cat "$summary"
exit $(( failed > 0 ))
