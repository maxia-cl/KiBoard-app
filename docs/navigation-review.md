# Navigation review

**English** · [Español](navigation-review.es.md)

A UI review of the app's whole navigation flow, done 2026-08-06 against `feat/launcher-feedback`.
Findings are ranked by **(users affected × severity)** rather than by taste, using an assumed cohort
of 100 users. It is a plan to work through, not a report to file: each phase is a coherent piece of
work and the phases are ordered so that earlier ones defuse later ones.

## The assumed cohort

The ranking depends on this, and **it is assumed, not measured**. Stated so it can be argued with.

| Segment | n | Basis |
|---|---|---|
| First run, never paired | 100 | everyone, once |
| Background the app and return later | 90 | it is a phone |
| PC asleep or WiFi dropped mid-session | 90 | phone in pocket, PC sleeps |
| Use landscape at least sometimes | 70 | it is a keypad |
| Rotate during a session | 60 | |
| One-handed at least sometimes | 55 | |
| Multi-page decks | 55 | the Launcher deck alone paginates |
| Spanish UI | 40 | the product ships bilingual |
| More than one deck | 30 | |
| Network drops multicast (guest WiFi, ISP routers) | 25 | the code calls this the common case |
| Will change PC, reinstall the host, or get a new DHCP lease | 25 | over a year of use |
| System font ≥ 1.3× | 20 | Android population |
| Host not installed/running at first scan | 15 | ordinary install-order mistake |
| Red-green colour deficient | 6 | ~8% of men |
| TalkBack | 2 | |

## One finding was checked and thrown out

The review reported that round-tripping the Auto/Manual toggle loses the selected deck, because
`setMode` omits `deckId` when it is null (`lib/net/ws_layout_source.dart:325`). It does not: the
host only touches `s.deck_id` when the message carries one
(`KiBoard-windows-host/src-tauri/src/net/ws.rs:606`), and the session remembers its own. Reviewing
the phone without reading the host produced a plausible bug that is not there. **Worth remembering
as a method note: a finding about a protocol round trip is not confirmed until both ends are read.**

Verified by hand before planning: zero `PopScope`/`WillPopScope` and zero
`AppLifecycleListener`/`didChangeAppLifecycleState` in `lib/`; the strip order really does invert
between orientations; 17 translated strings (not 19) are never referenced.

---

## Phase 1 — the chain that feeds itself

These three trigger each other: the backwards page swipe is eaten by the system back gesture, that
becomes a back press, back closes the app, and reopening costs the splash hold and lands in the
15-second retry wait. **Fixing the first defuses the chain**, so the order matters.

### 1.1 Back on the deck closes the app, or strands you in discovery

`critical` · `95/100` · `lib/ui/boot_screen.dart`, `lib/ui/pair/pairing_code_screen.dart`

There is no `PopScope` anywhere, so back does whatever the route stack happens to hold — and the
stack differs by how you arrived:

- **Relaunch, already paired.** `BootScreen` returns `DeckScreen` as a *widget* inside an
  `AnimatedSwitcher`, not as a route, so the deck is the root. Back finds nothing to pop and Android
  closes the app.
- **The session in which you paired.** `PairingCodeScreen` is pushed over `BootScreen`, and success
  does `pushReplacement`. The stack becomes `[BootScreen showing DiscoverScreen, DeckScreen]`. Back
  pops to a discovery list you already finished, with no route forward to the deck. Force-quitting
  is the only way out.

Back is the one gesture every Android user has in muscle memory, and the deck is a surface people
poke at while looking at a monitor.

**Fix.** `PopScope` on the deck with one explicit policy — first back warns, a second within two
seconds leaves — and `pushAndRemoveUntil` after pairing so the deck is always the root and the two
cases converge.

### 1.2 The page swipe fights the Android back gesture

`critical` · `55/100` · `lib/ui/deck/deck_screen.dart`

The horizontal-drag `GestureDetector` covers the bezel edge to edge. On Android 10+ gesture
navigation a left-edge swipe belongs to the system, and Flutter declares no exclusion rects — so
"swipe right to go back a page" started near the left edge is taken by the system and becomes 1.1.
Landscape is accidentally protected by immersive mode, at the cost of popping the system bars over
the deck instead.

**Fix.** Declare system-gesture exclusion rects for the deck's edges, or inset the drag target by
`MediaQuery.systemGestureInsets` and accept a dead zone. Needs a device to confirm the width.

### 1.3 Coming back from the background waits up to 15 s before trying

`major` · `90/100` · `lib/net/ws_layout_source.dart`

Reconnect backoff is `500ms × 2^attempt` capped at 15 s, and the attempt counter only resets on a
successful connect. After the PC has been off for an hour the counter sits at its ceiling, so
unlocking the phone shows a stale deck and "Offline — retrying…" for up to fifteen seconds before
the app even attempts a connection. It is indistinguishable from the permanent failure in 2.1.

Being offline is a normal state for this screen and that is deliberate. **Not retrying is not the
same as being offline.**

**Fix.** An `AppLifecycleListener` that, on resume, cancels the pending retry, resets the counter and
connects immediately.

---

## Phase 2 — dead ends

### 2.1 There is no way to forget a PC

`critical` · `25/100` · `lib/ui/settings_sheet.dart` (by absence), `lib/net/ws_layout_source.dart`,
`lib/net/pinned_socket.dart`

`SavedSession.clear()` is only ever called when the *host* acts — a fatal `hello` rejection, or the
revoked banner. The user cannot. Three ways in:

- **The IP changes.** `WsLayoutSource.ip` is final and reconnect re-dials the stored address
  forever. There is no re-discovery.
- **The host is reinstalled** and its certificate regenerated. `PinnedSocket` refuses it, and the
  failure is deliberately non-fatal, so the app retries a certificate it will never accept.
- **A different PC.** No exit at all.

In all three the banner is identical to the ordinary "the PC is asleep" one, so nothing tells the
user this will not recover. The only cure is clearing the app's storage from Android settings.

**Fix.** A "Forget this PC" row in Settings — clear the session, then `pushAndRemoveUntil` to
discovery. Separately, a certificate mismatch should say so instead of borrowing the sleeping-PC
copy: that is the one case where pairing again is the answer.

### 2.2 The window switcher can spin forever

`major` · `45/100` · `lib/ui/windows/window_switcher_screen.dart`, `lib/ui/deck/deck_screen.dart`

`listWindows` times out by throwing, and nothing catches it, so `_loading` is never cleared: an
eight-second wait, then a spinner that never ends. The deck also pushes the screen without awaiting
the press and without checking the link, so an offline host lands you in a screen that cannot load.
A host reporting zero windows gets an empty grid and no sentence.

The close button is outside the loading branch, so the screen is at least escapable.

**Fix.** Catch the failure and render the same "waiting for your PC" treatment the deck already uses,
with a retry. Add an empty state. Do not push the screen at all when the session is not online.

### 2.3 The empty state blames the network for an unstarted host

`major` · `15/100` · `lib/ui/pair/discover_screen.dart`

The no-hosts state explains multicast and offers "Scan again" and "Enter its address". It never says
*install and run KiBoard on the PC*. For someone who found the phone app first — the natural order —
every route offered is a dead end. The manual explains it perfectly and sits three levels away
behind a cog they have never opened.

**Fix.** Lead with the host check before the network explanation, and link the manual from here.

---

## Phase 3 — consistency and legibility

### 3.1 The strip inverts Settings and Mode when you rotate

`major` · `60/100` · `lib/ui/deck/deck_screen.dart`

Portrait is Decks / Mode / Settings; landscape is Decks / Settings / Mode. Both buttons are the same
size with an icon and a word, so reaching for the mode toggle in landscape opens a modal sheet over
the deck. On a product whose whole stated value is muscle memory, the chrome reorders itself when the
phone turns.

**Fix.** Build the three buttons once into a list and let each orientation lay the same list out.
That also removes the duplicated call sites, so they cannot drift again.

### 3.2 The page dots are the only "where am I", and they fail contrast twice

`major` · `55/100`, hard failure for 6 · `lib/ui/deck/device_bezel.dart`, `lib/ui/tokens.g.dart`

The active dot is the brand red on the bezel's dark end — roughly 1.7:1 — and the inactive one is
about 2.1:1. Both are under the 3:1 floor for a meaningful indicator, and **active and inactive
differ by about 1.2:1 in luminance**: the only thing separating them is hue, dark red against dark
grey. They are also 8 px marks read at arm's length while looking at a monitor.

The dots additionally look like a paginator and are not tappable.

**Fix.** Make the active/inactive difference more than hue — lightness, size or a ring — and add a
`2/4` label next to them; the count is already in hand. Consider making them tappable, since the
host owns the page and this is just another `set_page`.

### 3.3 Seventeen translated strings are never wired up

`major` · `40/100` · `lib/l10n/app_en.arb` and its call sites

`noPcsWhy`, `addressHint`, `notAnAddress`, `wantsToConnect`, `enterCode`, `pairFailed`,
`waitingForHost`, `waitingForHostHint`, `openWindows`, `rightClick`, `listening`, `holdAndSpeak`,
`micNeeded`, `micDenied`, `noSpeech`, `keyRefused`, `noAnswer` are defined and translated in both
locales and referenced nowhere. The English is inlined at the call sites instead — including the
discovery empty state, which is the single most important screen for a stuck user.

For a Spanish user on a multicast-blocking router, the only screen that could unstick them is in a
language they may not read.

**Fix.** Wire them up; the translations exist. Then a CI check that fails on unreferenced keys, or
this comes back.

### 3.4 Raw protocol error codes are shown to the user

`minor` · `35/100` · `lib/ui/deck/deck_screen.dart`

A refused press puts the protocol code straight into a snackbar, so the user reads
`unknown_action`. `keyRefused` already exists in the `.arb` for exactly this. The pairing screen
already does the right thing with its own codes and can be copied.

### 3.5 The host's `toast` message is dropped

`minor` · `20/100` · `lib/net/ws_layout_source.dart`

Protocol §4.4 defines a host→phone `toast`, and the app never filters for it. It is the host's only
channel for narrating what it did, which matters precisely because the phone cannot know.

---

## Phase 4 — accessibility

### 4.1 There is no accessibility layer at all

`major for those affected` · `2/100` · `lib/ui/deck/key_widget.dart`, `lib/ui/deck/key_grid.dart`

One `Semantics` in the whole app, on the wordmark. Consequences: an icon-only key announces nothing;
the on/current/launching states are purely visual; `onDoubleTap` on every key collides with
TalkBack's own activation gesture; and the page swipe is a raw drag with no semantic action, so
there is no accessible way to change page at all. The three close buttons have no tooltip.

**Fix.** Wrap each key in `Semantics` with its label, button and toggled state; add tooltips; expose
page change through `onIncrease`/`onDecrease` on the bezel.

### 4.2 The Settings sheet has no scroll view

`minor` · `20/100` · `lib/ui/settings_sheet.dart`

A plain `Column`. Six rows at a 1.3× system font in landscape will overflow with no way to reach the
bottom ones. Every other long surface in the app already scrolls, which makes this the odd one out.
The exact breakpoint needs a device; the missing scroll view is a code fact.

---

## Not settled by reading code

- Whether the left-edge page swipe actually loses to the system gesture, and how wide the dead zone
  is (1.2).
- **Folder navigation.** The phone models `KeyKind.folder` and never branches on it. If the host
  reports a folder under the same `source.id` at page 0, the page key does not change, the switcher
  does not animate, and the keys mutate in place with no motion. Open a folder against the real host
  and watch what arrives.
- Whether the Settings sheet really overflows, and at what text scale (4.2).
- TalkBack traversal order and the double-tap collision (4.1).
- What error codes the host sends in practice, and whether `toast` is used at all today.
- How many people install the phone app first. The 15/100 is a guess; one session with five people
  who have never seen the product would settle 2.3 and the manual's placement better than any
  amount of reading.

## What is already good — do not break it

- **The deck stays up while the host is asleep and says so in a sentence**, rather than spinning.
- **The typed address is always visible**, not only in the empty state, and it reuses the ordinary
  pairing flow instead of forking it.
- **Every pushed screen has both a close button and an edge-drag back**, and the trackpad releases a
  latched drag in `dispose`, so walking out cannot leave the PC's mouse button held.
- **The page cache is keyed on grid capacity, not shape**, so rotating does not throw it away.
- **The danger confirmation runs before every branch**, so it covers client-side keys and long and
  double presses too.
