#!/usr/bin/env bash
# Usage: scripts/install.sh <project-dir> [--link]
# Copies (default) or symlinks each skill and agent into <project-dir>/.claude without touching existing ones.
# Copy is the default because Claude Code does not reliably load symlinked skills.
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.claude"
dest_root="${1:?usage: install.sh <project-dir> [--link]}"
mode="${2:-}"
dest="$dest_root/.claude"

mkdir -p "$dest/skills" "$dest/agents"

place() {
  local from="$1" to="$2"
  if [ -e "$to" ] || [ -L "$to" ]; then
    echo "skip (exists): $to"
    return
  fi
  if [ "$mode" = "--link" ]; then
    ln -s "$(realpath --relative-to="$(dirname "$to")" "$from")" "$to"
  else
    cp -r "$from" "$to"
  fi
  echo "added: $to"
}

for d in "$src"/skills/*/; do place "${d%/}" "$dest/skills/$(basename "$d")"; done
for f in "$src"/agents/*.md; do place "$f" "$dest/agents/$(basename "$f")"; done
