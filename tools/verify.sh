#!/usr/bin/env bash
# One unattended check of the checked-out branch: what CI runs, then any
# two-window scenarios, with a summary of a few lines at the end.
#
#   GODOT=<4.8-dev7 binary> tools/verify.sh [--coop] [--builds[=<dir>]] [scenario[=<seed dir>] ...]
#
#   --coop      only the co-op GUT suites (test_coop*) instead of the whole suite
#   --builds    also the private Windows and Linux builds of HEAD (a clean tree
#               only): exported, booted (Windows under Wine) and zipped with
#               docs/coop/playing.md into <dir> (default <stamp>/builds)
#   scenario    names under tools/coop_screens/, run after the headless stages;
#               =<seed dir> is that scenario's SEED, the others start a fresh
#               campaign (an exported SEED is refused rather than given to all)
#
# Stages: import, GUT, release gates, boot smoke test, ENet demo, three
# processes, then each scenario, then the builds. Full logs and captures go to
# $VERIFY_OUT/<stamp>/ (default ~/dev-scratch/pokerecomp-online-coop/verify), the
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
builds=""
scenarios=()
for a in "$@"; do
	case "$a" in
		--coop) coop_only=1 ;;
		--builds) builds=default ;;
		--builds=*) builds="${a#--builds=}" ;;
		-h|--help) sed -n '2,23p' "$0"; exit 0 ;;
		*) scenarios+=("$a") ;;
	esac
done
[[ -z "${SEED:-}" ]] || { echo "verify: SEED reaches every scenario; name it per scenario as <scenario>=<seed dir>" >&2; exit 2; }

out="${VERIFY_OUT:-$HOME/dev-scratch/pokerecomp-online-coop/verify}/$(date +%Y%m%d-%H%M%S)"
[[ "$builds" == default ]] && builds="$out/builds"
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
# Before any stage touches the tree: a build names its commit.
dirty="$(git -C "$root" status --porcelain --untracked-files=no)"

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

for a in "${scenarios[@]}"; do
	s="${a%%=*}" seed=""
	[[ "$a" != *=* ]] || { seed="${a#*=}"; seed="$(realpath -m "${seed/#\~/$HOME}")"; }
	if (cd "$root" && GODOT="$godot" SEED="$seed" tools/coop_screens.sh "$s" "$out/screens/$s") > "$out/screens-$s.log" 2>&1; then
		note "scenario $s: ok (captures in screens/$s${seed:+, seed $seed})"
	else
		note "scenario $s: FAILED${seed:+ (seed $seed)}"
		failed=$((failed + 1))
	fi
done

# boot <name> <log> <command...>: the launcher came up (it prints the cartridges
# it accepts) with no error, in the private user folder.
boot() {
	local name="$1" log="$2"; shift 2
	if XDG_DATA_HOME="$out/xdg" GODOT_CAP=300 tools/ci_godot.sh "$@" --headless --quit-after 60 > "$log" 2>&1 \
		&& grep -q "pokerecomp supported cartridges:" "$log" && ! grep -q "ERROR" "$log"; then
		note "  $name: boots"
	else
		note "  $name: FAILED to boot (see ${log#"$out"/})"
		return 1
	fi
}

# Private builds (#44), both from one commit so their protocol matches, and from
# a git archive of it so nothing untracked (a cartridge, a cache) can reach them.
make_builds() {
	local sha name src work game_version
	sha="$(git -C "$root" rev-parse --short=8 HEAD)"
	name="$(git -C "$root" rev-parse --abbrev-ref HEAD)"
	name="${name#coop/}-$sha"
	name="${name//\//-}"
	src="$out/builds-src"
	work="$out/builds-work/$name"
	mkdir -p "$src" "$work/linux" "$work/windows" "$builds"
	git -C "$root" archive HEAD | tar -x -C "$src"
	(cd "$src" && "$godot" --headless --import --path . \
		&& "$godot" --headless --path . --export-release "Linux" "$work/linux/pokerecomp.x86_64" \
		&& "$godot" --headless --path . --export-release "Windows Desktop" "$work/windows/pokerecomp.exe") \
		> "$out/builds-export.log" 2>&1 || { note "  export: FAILED (see builds-export.log)"; return 1; }
	game_version="$(sed -n 's/^const VERSION: String = "\(.*\)"$/\1/p' "$src/game/main/app_version.gd")"
	printf '%s\n' "pokerecomp co-op $game_version, protocol $(sed -n 's/^const PROTOCOL: int = //p' "$src/game/coop/coop_host.gd")" \
		"commit $(git -C "$root" rev-parse HEAD) ($(git -C "$root" rev-parse --abbrev-ref HEAD)), built $(date '+%F %T') with Godot $version" \
		"Players join only a host with a build of the same version. How to play: PLAYING.md." > "$work/BUILD.txt"
	(cd "$root" && boot linux "$out/builds-boot-linux.log" "$work/linux/pokerecomp.x86_64") || return 1
	if command -v wine >/dev/null; then
		(cd "$root" && WINEPREFIX="$out/wine" WINEDEBUG=-all WINEDLLOVERRIDES="mscoree,mshtml=" \
			boot windows "$out/builds-boot-windows.log" wine "$work/windows/pokerecomp.exe") || return 1
		rm -rf "$out/wine"
	else
		note "  windows: not booted (no wine)"
	fi
	for os in linux windows; do
		cp "$work/BUILD.txt" "$work/$os/"
		cp "$src/docs/coop/playing.md" "$work/$os/PLAYING.md"
		(cd "$work/$os" && python3 -m zipfile -c "$work/pokerecomp-$name-$os.zip" ./*) || return 1
	done
	rm -rf "${builds:?}/$name"
	mv "$work/pokerecomp-$name-linux.zip" "$work/pokerecomp-$name-windows.zip" "$builds/"
	mv "$work" "$builds/$name"
	rm -rf "$src" "$out/builds-work"
	note "  $builds/pokerecomp-$name-{linux,windows}.zip"
}

if [[ -n "$builds" ]]; then
	if [[ -n "$dirty" ]]; then
		note "builds: FAILED (uncommitted changes at the start; a build names its commit)"
		failed=$((failed + 1))
	elif make_builds; then
		note "builds: ok"
	else
		note "builds: FAILED"
		failed=$((failed + 1))
	fi
fi

rm -rf "$out/tmp"
if (( failed )); then
	note "RESULT: FAILURES ($failed stage(s); logs in $out)"
else
	note "RESULT: all passed (logs in $out)"
fi
cat "$summary"
exit $(( failed > 0 ))
