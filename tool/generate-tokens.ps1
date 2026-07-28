# Regenerates lib/ui/tokens.g.dart from the pinned KiBoard-protocol submodule.
# Flutter has no prebuild-hook system like npm's pre<script>, so this is a manual step —
# run it after `git submodule update` moves the pin, or whenever deck-tokens.json changes.
# Usage: pwsh tool/generate-tokens.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
node "$root/KiBoard-protocol/protocol/generate-tokens.mjs" `
  "$root/lib/ui/tokens.g.dart" `
  "$root/build/.tokens.g.css"
