/// Fake mDNS browse + pairing (protocol/README.md §1-2), for the FP discovery/pairing screens.
/// F1 replaces this with real `_kiboard._tcp` browsing and the real pair_request/pair_confirm flow.
class DiscoveredHost {
  final String id;
  final String name;
  final String os;
  const DiscoveredHost({required this.id, required this.name, required this.os});
}

class MockDiscovery {
  static const hosts = [
    DiscoveredHost(id: 'a1b2c3d4', name: "M3X's PC", os: 'win'),
    DiscoveredHost(id: 'f9e8d7c6', name: 'Living Room PC', os: 'win'),
  ];

  Future<List<DiscoveredHost>> discover() async {
    await Future.delayed(const Duration(milliseconds: 900));
    return hosts;
  }

  Future<bool> confirmCode(String code) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return code.length == 6;
  }
}
