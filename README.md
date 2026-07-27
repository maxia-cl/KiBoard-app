# KiBoard — mobile app

**English** · [Español](README.es.md)

The key pad. A Flutter app that turns a phone or tablet into a **Stream Deck over WiFi**, paired
with a KiBoard host on the same local network.

- **Auto mode** — the pad follows the app in the foreground on the PC. ~100 profiles ship ready.
- **Manual mode** — decks the user builds: launch apps, fire macros, drive OBS.

It draws a **physical Stream Deck**: bezel, square LCD keys, stand and logo. No scrolling — what
does not fit lives on another page.

## Related repositories

| Repository | What it is | Visibility |
|---|---|---|
| [`KiBoard-protocol`](https://github.com/maxia-cl/KiBoard-protocol) | Message contract, visual tokens, fixtures, project docs | Private |
| [`KiBoard-windows-host`](https://github.com/maxia-cl/KiBoard-windows-host) | Windows host | Private |
| [`KiBoard-windows-host-releases`](https://github.com/maxia-cl/KiBoard-windows-host-releases) | Host installers and update feed | Public |

`KiBoard-protocol` is the **source of truth**. Change it first, then this repo.

## Status

**F0 done.** `KiBoard-protocol` is pinned as a git submodule at `KiBoard-protocol/` (tag
`v0.1.0-fp`); `lib/ui/tokens.g.dart` is regenerated from it with `tool/generate-tokens.ps1` /
`.sh` (Flutter has no npm-style prebuild hook, so this is a manual step after moving the pin).

The **phase FP mock-up** — the whole visual layer: bezel, keys, pagination, folders, short/long/
double press, discovery and pairing screens, the window switcher — runs on fixtures read straight
from the submodule, with no host communication, behind a `MockLayoutSource` that F3 swaps for the
real WebSocket client. `flutter analyze` and `flutter test` (including an end-to-end demo-flow
test) are clean.

## Stack

Flutter (Dart). Targets **Android → iOS**.

## Conventions

All code is English — identifiers, comments, commits, log output. User-facing strings live in
`.arb` files, never in code. Documents ship in English and Spanish (`NAME.md` / `NAME.es.md`).
See [`CONTRIBUTING.md`](https://github.com/maxia-cl/KiBoard-protocol/blob/main/CONTRIBUTING.md).
