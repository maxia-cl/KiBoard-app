import 'dart:ui';

/// The WebSocket URL for a host address, which may be a hostname, an IPv4 literal or an IPv6 one.
///
/// Never build this by interpolating `'ws://$ip:$port'`. mDNS regularly resolves a host to its
/// IPv6 address, and a bare IPv6 literal is full of colons, so the parser reads the first one as
/// the port separator and throws `FormatException: Invalid port`. Observed on a real phone, where
/// pairing worked or failed depending on which address family mDNS happened to answer with. The
/// `Uri` constructor adds the brackets IPv6 requires.
Uri wsUri(String host, int port) => Uri(scheme: 'ws', host: host, port: port);

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
}
