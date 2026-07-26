# Mock data (phase FP only)

Copied, not pinned, from `KiBoard-protocol/{deck-tokens.json,fixtures/}` — see
`docs/implementation-plan.md` in that repo. The real submodule pin lands in **F0**; `F3` replaces
`MockLayoutSource` with `WsLayoutSource`, the real WebSocket client.

When F0 lands:

- Delete `assets/mock/` and this folder's copies.
- Add `KiBoard-protocol` as a git submodule.
- Generate `lib/ui/tokens.g.dart` from the pinned `deck-tokens.json` via
  `node <submodule>/generate-tokens.mjs lib/ui/tokens.g.dart <css-out>` as a prebuild step.
