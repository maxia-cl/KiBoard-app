import 'dart:ui';

/// The WebSocket URL for a host address, which may be a hostname, an IPv4 literal or an IPv6 one.
///
/// Never build this by interpolating `'ws://$ip:$port'`. mDNS regularly resolves a host to its
/// IPv6 address, and a bare IPv6 literal is full of colons, so the parser reads the first one as
/// the port separator and throws `FormatException: Invalid port`. Observed on a real phone, where
/// pairing worked or failed depending on which address family mDNS happened to answer with. The
/// `Uri` constructor adds the brackets IPv6 requires.
Uri wsUri(String host, int port) => Uri(scheme: 'ws', host: host, port: port);

/// The host's default port (protocol §1). Only needed when the address was typed by hand — mDNS
/// carries the real one, and a host on another port has to be typed with it.
const int defaultHostPort = 8770;

/// An address a user typed instead of picking a discovered host (R1: mDNS is a convenience, never
/// the only way in). Returns null when the text cannot be read as an address, so the caller can
/// say so rather than dial something it guessed.
///
/// Accepts `192.168.1.11`, `192.168.1.11:8770`, `desktop.local`, `[::1]:8770`, and a pasted
/// `ws://host:port` — someone reading the PC's screen may well copy the whole URL.
({String host, int port})? parseHostAddress(String input) {
  var text = input.trim();
  if (text.isEmpty) return null;
  // A pasted URL is a reasonable thing to arrive here; strip the scheme rather than reject it.
  text = text.replaceFirst(RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://'), '');
  text = text.split('/').first;
  if (text.isEmpty) return null;

  String host;
  int? port;
  if (text.startsWith('[')) {
    final close = text.indexOf(']');
    if (close < 2) return null;
    host = text.substring(1, close);
    if (!_isIPv6(host)) return null;
    final rest = text.substring(close + 1);
    if (rest.isNotEmpty) {
      if (!rest.startsWith(':')) return null;
      port = int.tryParse(rest.substring(1));
      if (port == null) return null;
    }
  } else if (text.split(':').length > 2) {
    // Two or more colons and no brackets: only an IPv6 literal looks like this. It cannot also
    // carry a port, and reading the last group as one would quietly dial somewhere else — the same
    // class of bug `wsUri` exists to avoid. It has to BE one, though: taking any colon-heavy string
    // on faith sent `wsUri` a FormatException instead of telling the user their typo.
    if (!_isIPv6(text)) return null;
    host = text;
  } else {
    final parts = text.split(':');
    host = parts.first;
    if (parts.length == 2) {
      port = int.tryParse(parts[1]);
      if (port == null) return null;
    }
  }
  // A host with a space in it is a sentence, not an address.
  if (host.isEmpty || host.contains(RegExp(r'\s'))) return null;
  if (port != null && (port < 1 || port > 65535)) return null;
  return (host: host, port: port ?? defaultHostPort);
}

/// `Uri.parseIPv6Address` rather than `dart:io`'s `InternetAddress`, so this stays usable in a web
/// build of the app (phase FP shipped one to show the UI over a link).
bool _isIPv6(String text) {
  try {
    Uri.parseIPv6Address(text);
    return true;
  } on FormatException {
    return false;
  }
}

/// The language tag sent in `hello`, so the host serves its ~100-profile catalogue translated
/// (protocol §2). Taken from the phone, not hardcoded: the PC's own language is irrelevant — the
/// labels are read on the phone, by whoever is holding it.
///
/// Reduced to the base language because that is what the host's table is keyed on; `es-419` and
/// `es-ES` both want Spanish.
String deviceLocale() {
  final tag = PlatformDispatcher.instance.locale.languageCode;
  return tag.isEmpty ? 'en' : tag.toLowerCase();
}

/// A host found on the LAN via mDNS (protocol/README.md §1). Replaces the FP-era
/// `MockDiscovery`'s fake entries with real `_kiboard._tcp` TXT record fields.
class DiscoveredHost {
  final String id;
  final String name;
  final String os;
  final String mode;
  final bool pairingOpen;
  final String ip;
  final int port;

  const DiscoveredHost({
    required this.id,
    required this.name,
    required this.os,
    required this.mode,
    required this.pairingOpen,
    required this.ip,
    required this.port,
  });

  /// A host the user typed the address of (R1). Nothing is known about it beyond where it is: the
  /// name comes back in `pair_ack`, and `pairingOpen` is assumed true so the attempt is actually
  /// made — if the host is closed it answers `pairing_closed`, which the pairing screen already
  /// explains. Guessing "closed" here would refuse to try, which is worse than a clear error.
  factory DiscoveredHost.typed({required String host, required int port}) => DiscoveredHost(
    id: '',
    name: port == defaultHostPort ? host : '$host:$port',
    os: '',
    mode: '',
    pairingOpen: true,
    ip: host,
    port: port,
  );
}
