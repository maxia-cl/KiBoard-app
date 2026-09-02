# KiBoard privacy policy

Effective date: 1 September 2026

KiBoard turns an Android phone or tablet into a control surface for a Windows PC on the same local
network. KiBoard does not operate an analytics, advertising, account, or cloud data service.

## Data handled by the app

- **Local-network connection data:** the app discovers and connects to the KiBoard Windows host on
  the local network. Pairing tokens, the host address, and the host certificate are stored locally
  on the Android device so it can reconnect.
- **Microphone:** microphone access is used only when the user starts push-to-talk dictation.
  Android's configured speech-recognition service performs the transcription. KiBoard sends the
  resulting text to the paired Windows host over the local network; KiBoard does not send audio to
  a KiBoard-operated server.
- **Interaction data:** key presses, trackpad movement, and text entered through KiBoard are sent
  only to the paired Windows host to perform the requested action.

KiBoard does not sell data, show ads, create user profiles, or share personal data with the
developer. Data remains on the user's devices and local network, except where the user's Android
speech-recognition provider processes dictation under that provider's terms.

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
