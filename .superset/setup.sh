#!/usr/bin/env bash
# Makes a fresh worktree of this fork ready for an agent session. Superset runs
# it on workspace creation (.superset/config.json); run it by hand in any other
# worktree. Idempotent, a few seconds, touches only this checkout's git config
# and the scratch folder. Never installs anything and never changes the owner's
# global git identity.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

git config user.name Claude
git config user.email noreply@anthropic.com
git config core.hooksPath .githooks
if ! git remote get-url upstream >/dev/null 2>&1; then
	git remote add upstream https://github.com/Decryptu/pokerecomp.git
fi
git remote set-url --push upstream DISABLED

mkdir -p "$HOME/dev-scratch/pokerecomp-online-coop"

godot="${GODOT:-$HOME/.local/opt/godot-4.8-dev7/godot}"
if [[ -x "$godot" ]]; then
	echo "setup: GODOT=$godot"
else
	echo "setup: no Godot 4.8-dev7 at $godot; set GODOT before tools/verify.sh" >&2
fi
command -v bwrap >/dev/null || echo "setup: bwrap missing; verify runs without the empty /dev sandbox" >&2

echo "setup: $(git config user.name) <$(git config user.email)>, hooks $(git config core.hooksPath), branch $(git branch --show-current)"
echo "setup: read HANDOFF.md first, then AGENTS.md"
