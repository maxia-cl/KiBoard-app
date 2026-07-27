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

**F1 done** (F0 before it). `KiBoard-protocol` is pinned as a git submodule at `KiBoard-protocol/`
(tag `v0.1.0-fp`); `lib/ui/tokens.g.dart` is regenerated from it with `tool/generate-tokens.ps1` /
`.sh` (Flutter has no npm-style prebuild hook, so this is a manual step after moving the pin).

Discovery and pairing are now **real**: `MdnsDiscovery` (the `nsd` package) browses `_kiboard._tcp`
on the LAN, and `PairingClient` does an actual `pair_request`/`pair_challenge`/`pair_confirm` round
trip over a live WebSocket to get its own per-device token — verified against the compiled host in
`KiBoard-windows-host`, both at the wire-protocol level and by running the shipping Dart client
against it directly (`test/manual_pairing_smoke.dart`). The deck screen shown **after** pairing
still runs on `MockLayoutSource` fixtures, with no host communication — that's F2/F3's job.
`flutter analyze` and `flutter test` are clean (the widget tests inject fakes for `Discovery` and
`Pairing`, since neither mDNS nor a real socket exist in a test sandbox).

## Stack

Flutter (Dart). Targets **Android → iOS**.

## Conventions

All code is English — identifiers, comments, commits, log output. User-facing strings live in
`.arb` files, never in code. Documents ship in English and Spanish (`NAME.md` / `NAME.es.md`).
See [`CONTRIBUTING.md`](https://github.com/maxia-cl/KiBoard-protocol/blob/main/CONTRIBUTING.md).
