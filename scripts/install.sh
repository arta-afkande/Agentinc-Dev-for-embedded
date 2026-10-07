#!/usr/bin/env bash
# Usage: scripts/install.sh <project-dir>
# Copies each skill and agent into <project-dir>/.claude, replacing existing ones.
# Skills named embedded-userdefined-* are never replaced if they already exist.
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.claude"
dest_root="${1:?usage: install.sh <project-dir>}"
dest="$dest_root/.claude"

mkdir -p "$dest/skills" "$dest/agents"

place() {
  local from="$1" to="$2"
  if [ -e "$to" ] || [ -L "$to" ]; then
    case "$(basename "$to")" in
      embedded-userdefined-*)
        echo "skip (user-defined, exists): $to"
        return
        ;;
    esac
    rm -rf "$to"
  fi
  cp -r "$from" "$to"
  echo "added: $to"
}

for d in "$src"/skills/*/; do place "${d%/}" "$dest/skills/$(basename "$d")"; done
for f in "$src"/agents/*.md; do place "$f" "$dest/agents/$(basename "$f")"; done
