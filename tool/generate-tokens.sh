#!/usr/bin/env bash
# Regenerates lib/ui/tokens.g.dart from the pinned KiBoard-protocol submodule.
# Flutter has no prebuild-hook system like npm's pre<script>, so this is a manual step —
# run it after `git submodule update` moves the pin, or whenever deck-tokens.json changes.
# Usage: ./tool/generate-tokens.sh
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
node "$root/KiBoard-protocol/protocol/generate-tokens.mjs" \
  "$root/lib/ui/tokens.g.dart" \
  "$root/build/.tokens.g.css"
