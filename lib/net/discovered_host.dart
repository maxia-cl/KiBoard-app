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
