# Google Play Data safety — KiBoard 2.0.2

Prepared from the actual KiBoard Host 2.0.2 traffic and the current Google Play definitions. Keep
this document aligned with `PRIVACY.md` and the host privacy policy.

## Collection and security

| Play Console question | Answer |
| --- | --- |
| Does the app collect or share any required user data types? | **Yes** |
| Is all collected data encrypted in transit? | **Yes**. Android connects to the host through certificate-pinned WSS and the host sends analytics over HTTPS. |
| Can users request that their data be deleted? | **No**. Events contain no account or persistent identifier and cannot be associated with a person for selective deletion. |
| Does the app support account creation? | **No** |
| Does the app contain ads? | **No** |

## Data type to select

`App activity` → `App interactions`

| Field | Answer |
| --- | --- |
| Collected? | **Yes** |
| Shared? | **No**. Aptabase is a service provider processing analytics on KiBoard's behalf. |
| Processed ephemerally? | **No**. Aptabase retains aggregated events. |
| Required? | **Optional**. Users can disable Analytics in the host settings and continue using KiBoard. |
| Purpose | **Analytics** |

Do not select location, personal or financial information, contacts, files, photos, audio, web
history, installed apps, crash logs, or device identifiers. KiBoard sends fixed event identifiers
and coarse functional context only. It does not send app/window/device/deck/profile names, custom
labels or actions, entered or dictated text, audio, or pairing data.

## Review notes

- Aptabase's `sessionId` is random and lasts only for the current host process. It is not a phone,
  PC, or user identifier.
- Dictation uses the speech-recognition service selected by Android. KiBoard neither stores audio
  nor sends it to KiBoard servers; the resulting text travels encrypted only to the paired PC.
- Button presses travel to the PC over an encrypted local-network connection. Google excludes
  end-to-end encrypted transfers when only sender and recipient can read the data.
- Update this form before shipping any future crash reporting, accounts, ads, KiBoard backend, or
  additional analytics fields.

Verification sources: official Google Play Data safety guidance and Aptabase's privacy policy.
