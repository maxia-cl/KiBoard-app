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

**Not started.** Next step is phase FP: the mock-up running on fixtures from `KiBoard-protocol`,
with no host communication. See the implementation plan in `KiBoard-protocol`.

## Stack

Flutter (Dart). Targets **Android → iOS**.

## Conventions

All code is English — identifiers, comments, commits, log output. User-facing strings live in
`.arb` files, never in code. Documents ship in English and Spanish (`NAME.md` / `NAME.es.md`).
See [`CONTRIBUTING.md`](https://github.com/maxia-cl/KiBoard-protocol/blob/main/CONTRIBUTING.md).
