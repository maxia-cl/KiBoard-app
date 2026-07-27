import 'dart:async';
import 'dart:convert';

import 'package:nsd/nsd.dart' as nsd;

import 'discovered_host.dart';
import 'discovery.dart';

/// Real `_kiboard._tcp` mDNS browsing (protocol/README.md §1). The `nsd` package choice is
/// harvested from the `nervous-swirles-1ed28b` worktree, already validated there against the
/// Rust `mdns-sd` advertiser (see KiBoard-windows-host's net/discovery.rs).
class MdnsDiscovery implements Discovery {
  /// Browses for the given window and returns whatever hosts answered. mDNS is unreliable by
  /// nature (multicast, no delivery guarantee) — callers should offer QR/manual IP as a fallback
  /// (R1), never rely on this alone.
  @override
  Future<List<DiscoveredHost>> discover({Duration window = const Duration(seconds: 4)}) async {
    final found = <String, DiscoveredHost>{};
    nsd.Discovery? discovery;
    try {
      discovery = await nsd.startDiscovery('_kiboard._tcp');
      discovery.addServiceListener((service, status) {
        if (status != nsd.ServiceStatus.found) return;
        final host = _parse(service);
        if (host != null) found[host.id] = host;
      });
      await Future.delayed(window);
    } catch (_) {
      // No mDNS on this network, or the platform denied the permission: return what we have
      // (possibly nothing) — the caller falls back to QR/manual IP.
    } finally {
      if (discovery != null) await nsd.stopDiscovery(discovery);
    }
    return found.values.toList();
  }

  DiscoveredHost? _parse(nsd.Service service) {
    final txt = service.txt;
    final host = service.host;
    final port = service.port;
    if (txt == null || host == null || port == null) return null;
    String? field(String key) {
      final bytes = txt[key];
      return bytes == null ? null : utf8.decode(bytes, allowMalformed: true);
    }

    final id = field('id');
    if (id == null || field('v') != '2') return null; // not a v2 host we understand
    return DiscoveredHost(
      id: id,
      name: field('name') ?? service.name ?? 'KiBoard',
      os: field('os') ?? 'unknown',
      mode: field('mode') ?? 'auto',
      pairingOpen: field('pair') == 'open',
      ip: host,
      port: port,
    );
  }
}
