#!/usr/bin/env bash
# Reruns a tools/coop_screens.sh run from a snapshot its host wrote, each autoplayed
# window from the leg it was on then, through coop_screens.sh itself:
#
#   GODOT=<4.8-dev7 binary> tools/coop_resume.sh <run dir> [<n> | -<seconds>] [out dir]
#
# With no choice, the last snapshot; <n> takes <run dir>/snapshots/<n>; -<seconds> the
# last one written at least that long before the run ended (its newest log or snapshot). A
# snapshot holds the campaign a checkpoint would write and the leg each window had
# started once the host held the world it starts from (P1_FROM=, P2_FROM= in
# snapshot.env), so the resumed window replays that leg from its start. A window the
# snapshot has no leg for starts where the first run started it. The scenario,
# WHITEOUT and KILL come from <run dir>/run.env. The host keeps every snapshot of
# the last 30 minutes and, before that, the first of each 5 minutes. The out dir
# defaults to <run dir>.resume.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
usage="usage: GODOT=<binary> tools/coop_resume.sh <run dir> [<n> | -<seconds>] [out dir]"
run="$(realpath "${1:?$usage}")"
pick="${2:-}"
out="$(realpath -m "${3:-$run.resume}")"
[[ -f "$run/run.env" && -d "$run/snapshots" ]] || { echo "coop_resume: $run has no run.env and snapshots" >&2; exit 2; }
[[ "$run/" != "$out/"* ]] || { echo "coop_resume: the out dir would remove $run" >&2; exit 2; }
value() { sed -n "s/^$1=//p" "$2" | head -n 1; }

mapfile -t numbers < <(find "$run/snapshots" -mindepth 1 -maxdepth 1 -type d -regex '.*/[0-9]+' -printf '%f\n' | sort -n)
(( ${#numbers[@]} )) || { echo "coop_resume: no snapshots in $run/snapshots" >&2; exit 2; }
snap=""
case "$pick" in
	"") snap="${numbers[-1]}" ;;
	-*)
		end="$( (stat -c %Y "$run"/*.log; value UNIX "$run/snapshots/${numbers[-1]}/snapshot.env") | sort -n | tail -n 1)"
		for n in "${numbers[@]}"; do
			if (( $(value UNIX "$run/snapshots/$n/snapshot.env") <= end - ${pick#-} )); then snap="$n"; fi
		done ;;
	*) snap="$pick" ;;
esac
dir="$run/snapshots/$snap"
[[ -n "$snap" && -f "$dir/snapshot.env" ]] || { echo "coop_resume: no snapshot ${pick:-} in $run/snapshots (${numbers[*]})" >&2; exit 2; }

seed="$(mktemp -d)"
trap 'rm -rf "$seed"' EXIT
cp -r "$dir/coop_campaigns" "$dir/coop_identity.json" "$seed/"
p1="$(value P1_FROM "$dir/snapshot.env")"
p2="$(value P2_FROM "$dir/snapshot.env")"
p1="${p1:-$(value P1_FROM "$run/run.env")}"
p2="${p2:-$(value P2_FROM "$run/run.env")}"
echo "coop_resume: snapshot $snap of $run, written $(date -d "@$(value UNIX "$dir/snapshot.env")" +%T), p1 from ${p1:-the start}, p2 from ${p2:-the start}"
status=0
SEED="$seed" FROM="" P1_FROM="$p1" P2_FROM="$p2" WHITEOUT="$(value WHITEOUT "$run/run.env")" KILL="$(value KILL "$run/run.env")" \
	"$root/tools/coop_screens.sh" "$(value SCENARIO "$run/run.env")" "$out" || status=$?
exit "$status"
