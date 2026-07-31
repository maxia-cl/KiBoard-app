// TLS for the test fakes, since §2.2 made `wss://` the only transport the client will speak.
//
// Two things are needed and neither is about the tests' subject:
//
//   1. A certificate. This one is throwaway and self-signed for 127.0.0.1 — it exists only so a
//      `HttpServer.bindSecure` in this repo can answer a handshake. It is not a secret and it is
//      not the host's; the real one is minted per installation into `cert.der`.
//   2. A real `HttpClient`. `flutter_test` installs an `HttpOverrides` that hands back a MOCK one,
//      which answers every request with `UnsupportedError: Mocked response` — including the
//      WebSocket upgrade. Anything that opens a socket has to opt out of that.
import 'dart:io';

// ponytail: PEM inline rather than a fixture file — one import beats a file the test runner has to
// find, and rotating it means re-running the openssl line in the comment below.
//
//   openssl req -x509 -newkey rsa:2048 -nodes -keyout k.pem -out c.pem -days 36500 \
//     -subj "/CN=localhost" -addext "subjectAltName=IP:127.0.0.1,DNS:localhost"
const _cert = '''
-----BEGIN CERTIFICATE-----
MIIDJzCCAg+gAwIBAgIUWlPtGnhD+/f7UEEMAtvBsrUPA/swDQYJKoZIhvcNAQEL
BQAwFDESMBAGA1UEAwwJbG9jYWxob3N0MCAXDTI2MDczMTAyMDE0M1oYDzIxMjYw
NzA3MDIwMTQzWjAUMRIwEAYDVQQDDAlsb2NhbGhvc3QwggEiMA0GCSqGSIb3DQEB
AQUAA4IBDwAwggEKAoIBAQCq5SF9/Qs9vhAdOIYcU/fzXzNQC5moFRhZvU6iqjLZ
zD+2cIIXHLEue0jjD5Hc9aUaRavXEkSPAynsvovXUtiYjz5J/+fW1iVLICO4v2JN
+at2xmaHr9CUyWJm3OB6VTNS9PNxT3a13va0GW30KUKkI/d/AuVI9MCYEhoVjuSK
WsVHkD9sSi8E5PG8brJxO9mrv9QZaAkoFidM+wZB1XYNx9YDrXt8S6T3q+PjZJAA
8iO2V0HqWPRcZ5ahvxGW0vktS5n70M3vBWaMDxihtc8gRQwUiJJVE+CWDEXmSP1g
5Qz4CJewc8zmDkSCN2dMt0KPOg/4r20mjguv1Vs7rrzzAgMBAAGjbzBtMB0GA1Ud
DgQWBBS2UifBPFISaxmFhsCtAH717PeXhzAfBgNVHSMEGDAWgBS2UifBPFISaxmF
hsCtAH717PeXhzAPBgNVHRMBAf8EBTADAQH/MBoGA1UdEQQTMBGHBH8AAAGCCWxv
Y2FsaG9zdDANBgkqhkiG9w0BAQsFAAOCAQEABgASWXgD0Qa0i/3w0/bqL+NmqX7u
R5waCiEGYUgHO2gSP2NpWkkXawYNZ9r6KKwKMoK3KfUO2mBQbIjLsOqQMkjaDxKn
tbjD6Jf5IXGSRqeyD3Kpuh2k495Ja9ztu8lkvjOkx9CNVT3dmSE2vMkDtbAhme2I
YxGJBHJPby0FBgOf141adeZ6vieZQLpdeUe9eQ0eTuPogNCfaS5rIxxR04PLsDFW
zYJD3Lo3yho3ysgbjI6jrMoxLRu4caYt+tya4cI0BmEF9KfloxPAckN0QckTBUxD
G+wwe2/EjWnnAVpIA/SEUuxdGqQk6sTs12Oe82+HMMviOwqL1jxyUVjQjQ==
-----END CERTIFICATE-----
''';

const _key = '''
-----BEGIN PRIVATE KEY-----
MIIEvwIBADANBgkqhkiG9w0BAQEFAASCBKkwggSlAgEAAoIBAQCq5SF9/Qs9vhAd
OIYcU/fzXzNQC5moFRhZvU6iqjLZzD+2cIIXHLEue0jjD5Hc9aUaRavXEkSPAyns
vovXUtiYjz5J/+fW1iVLICO4v2JN+at2xmaHr9CUyWJm3OB6VTNS9PNxT3a13va0
GW30KUKkI/d/AuVI9MCYEhoVjuSKWsVHkD9sSi8E5PG8brJxO9mrv9QZaAkoFidM
+wZB1XYNx9YDrXt8S6T3q+PjZJAA8iO2V0HqWPRcZ5ahvxGW0vktS5n70M3vBWaM
Dxihtc8gRQwUiJJVE+CWDEXmSP1g5Qz4CJewc8zmDkSCN2dMt0KPOg/4r20mjguv
1Vs7rrzzAgMBAAECggEABpGOCwCp6PKgPe9JQFd95U3YdBAuFMbSy8g5+IigMbzn
CgUjCu5gZQ/6Cjgz/BE5Clx5MWgTWIffmajtSRZ3Gs4Or9t1Ns2+WzfeB6Dbj3G0
RHl1wWthkgZ3kMqWmj0iHuMpZEaQoobyZpO/pS3c0OBNCAW9eGNn77Bqbj+yyxqH
/FIpRBWNrFcPESK21/+6Y+bbtywGtVI6KG+sbBm02cJGoZunPExYcErSk5fP36/e
dkubXHCmjzF0g149KFiQG+nUYKUZId4whiYLtbEIRUAS3CT/98cm4kkEaTwlqsHR
aLNDYS1QzC6W5deFaOkJdrTEvHyCe0e3lFZCOeqM8QKBgQDShlaYkftKrmi6ivLA
Uqxqv8Ud6iXDmepPPaTVcOzxzkeOtiIvKbxNGCwuWDt2n9g+FN85gBsTXTf90411
kdeKTG4pmt3MaJCB1WDbX/VOIBXUkUytOVm750/VNlaI7ACX6cNTsimDCkFhLRvf
5XpsFHKyLd30plWqmmzbwNuz6QKBgQDPz1YmRNUQqIakUlUGRVLs4ERUNmYojmGO
agFyl5PDncx1qCrEjYvqJuqifzsKL6J4KTyDlTqgeql6b86SGiYsD4SwQRdpSlyq
jFh63rD1b/CaX8e5IEnHCgH7/j7Jh1bfgkLRhBAo+3gFVXiyJQhcJWNR4DyW6KxZ
ws0nWdFsewKBgQCFxRzDR4dAlgAwAFhtglrSXdZ3wq+KUYPEJCxX/7Bfma54bRzd
kQx4hFKWhDQMlVcHY6XP2KnbrREF9WXeffRSiWw6fZBP8WVZSmeIHbo2kUat0kHB
lD6DmmBs32EvEZ7y6HPX+85K2LpgcBRVOXCHupqCw4hUi1jF1egz3qD7+QKBgQCU
QsOe9/rfMK0m7UqV972rHHIDdvA5vSNi/MRdokEdDicCRmGE68vH2c4K8yUHJmcO
vbTb2AsE1Z62qLBDUn6rbsLnEPmH+DLWxtyVhO3RnfSV3wHaVWvtonk59PGMzI8x
VXkgi80PwCGoBIvg5UTqoQ4UKxxvOj9EpxPBIHamowKBgQC/7P7Ky0QPCWwvrZtc
pWQ4CiNb7cu1HlCv2ZKt+m2xwJxJdGuw77m75Ii7dWwi5f7lLsvlzmzegXTVg9m/
VarACkmPGLpRl43265Q+8araVzU0YM3PtgX+khl32iGEfemtFX9sNJtDrTcoURa5
DUpKPfmfRbv7P33mt0W8bH4Umg==
-----END PRIVATE KEY-----
''';

/// The context a fake host serves with.
SecurityContext fakeHostContext() => SecurityContext()
  ..useCertificateChainBytes(_cert.codeUnits)
  ..usePrivateKeyBytes(_key.codeUnits);

/// Runs [body] with a REAL `HttpClient`, undoing `flutter_test`'s mock for the duration.
///
/// Without this every socket the code under test opens answers `UnsupportedError: Mocked
/// response`, which is neither a connection nor a failure the app could ever see in the field.
Future<void> withRealSockets(Future<void> Function() body) =>
    HttpOverrides.runZoned(body, createHttpClient: (c) => HttpClient(context: c));
