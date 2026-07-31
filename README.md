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

**FP through F6 done, F7 part-way.** `KiBoard-protocol` is pinned as a git submodule at
`KiBoard-protocol/`, tag `v0.3.0-f7`; `lib/ui/tokens.g.dart` is regenerated from it with
`tool/generate-tokens.ps1` / `.sh` (Flutter has no npm-style prebuild hook, so it is a manual step
after moving the pin).

- **F1** — `MdnsDiscovery` (the `nsd` package) browses `_kiboard._tcp`, and `PairingClient` does a
  real `pair_request`/`pair_challenge`/`pair_confirm` round trip for its own per-device token.
- **F2/F3** — the deck runs on the host's data over a live `WsLayoutSource`: sessions persist and
  the app boots straight into the deck, reconnect backs off behind a link banner, and a socket that
  goes quiet without erroring is called dead from the silence. Plus haptics, wakelock, the phone's
  own locale in `hello`, and the trackpad and dictation screens ported from v1.
- **F4/F5/F6** — a horizontal drag changes page (§4.4 `set_page`), the chrome moves to a side strip
  in landscape because height is what caps key size held sideways, and two-state keys needed **zero
  app changes**: what travels is an ordinary key plus `state.on`, which the key widget has painted
  as a green dot since F3.
- **F7 so far** — the deck picker (`hello_ack` has carried the deck list since F1 and the phone was
  discarding it, so manual mode could only ever land on `decks[0]`); a **typed address** for
  networks that never pass mDNS on, which goes through the ordinary §2 pairing screen rather than a
  second flow; and **certificate pinning** over `wss://` (§2.2).

Pinning stores the whole DER rather than a hash: strictly stronger, ~350 bytes in the saved session,
and no crypto package for the one comparison the app makes. A session saved before pinning adopts
what it sees once and pins after — first-use trust, the bargain SSH makes. This is a **breaking
change**: phone and host must be rebuilt and installed together. It also makes the app `dart:io`
only, so there is no web build.

Still open in F7: first-run onboarding, and the QR half of the manual-address fallback — the phone
has no scanner and no camera dependency at all.

`flutter analyze` clean, 35 tests passing.

## Stack

Flutter (Dart). Targets **Android → iOS**.

## Conventions

All code is English — identifiers, comments, commits, log output. User-facing strings live in
`.arb` files, never in code. Documents ship in English and Spanish (`NAME.md` / `NAME.es.md`).
See [`CONTRIBUTING.md`](https://github.com/maxia-cl/KiBoard-protocol/blob/main/CONTRIBUTING.md).
