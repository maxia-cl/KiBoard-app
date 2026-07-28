import 'discovered_host.dart';

/// Seam so tests can inject a fake instead of doing real mDNS I/O (which doesn't exist in a test
/// sandbox). [MdnsDiscovery] is the only real implementation.
abstract class Discovery {
  Future<List<DiscoveredHost>> discover();
}
