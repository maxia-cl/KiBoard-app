# KiBoard privacy policy

Effective date: 3 September 2026

KiBoard turns an Android phone or tablet into a control surface for a Windows PC on the same local
network. KiBoard does not show ads, create accounts, or sell data. The Windows host uses Aptabase
for anonymous usage analytics as explained below.

## Data handled by the app

- **Local-network connection data:** the app discovers and connects to the KiBoard Windows host on
  the local network. Pairing tokens, the host address, and the host certificate are stored locally
  on the Android device so it can reconnect.
- **Microphone:** microphone access is used only when the user starts push-to-talk dictation.
  Android's configured speech-recognition service performs the transcription. KiBoard sends the
  resulting text to the paired Windows host over the local network; KiBoard does not send audio to
  a KiBoard-operated server.
- **Interaction data:** key presses and trackpad movement are sent to the paired Windows host to
  perform the requested action. The host creates analytics events containing the interaction type
  and functional context such as mode, position, press type, a built-in surface identifier,
  orientation, and result. Custom profiles are grouped into a single category. Typed or dictated
  text and action contents are not included in those events.

## Anonymous analytics

Events are sent by the Windows host to Aptabase's United States region. They include version,
language, operating system, interaction type, and a random identifier limited to the current host
process. They do not include application, window, device, deck, or profile names; custom labels or
actions; typed or dictated text; audio; local addresses; pairing codes or tokens; or certificates.

Aptabase states that it generates a daily server-side identifier from the IP address, user agent,
and a rotating salt, and retains events for up to five years. See
<https://aptabase.com/legal/privacy> and the host-specific policy at
<https://github.com/maxia-cl/KiBoard-windows-host/blob/main/PRIVACY.md>.

KiBoard does not sell data, show ads, or create persistent user profiles. Configuration remains on
the user's devices and local network. The exceptions are dictation processing by the configured
Android speech-recognition provider and the anonymous events described above.

## Retention and deletion

Pairing information remains on the Android device until the user disconnects, clears the app's
storage, or uninstalls KiBoard. Host configuration remains on the Windows PC until the user removes
it or uninstalls the host and deletes its data.

## Security

KiBoard pairs devices with a per-device token, uses encrypted WebSocket connections, and pins the
paired host certificate. Users should pair only with a PC they control and use a trusted local
network.

## Children

KiBoard is a general-purpose productivity tool and is not directed to children.

## Contact

Privacy questions and deletion requests can be opened at
<https://github.com/maxia-cl/KiBoard-app/issues>.

## Changes

Material changes will be published in this repository with a new effective date.
