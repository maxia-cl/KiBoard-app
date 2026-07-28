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
      // `startDiscovery` can HANG rather than fail when the platform's NSD service is left in a
      // bad state — observed right after an app restart orphaned a registration ("NsdService: id
      // N for 5 has no client mapping"). Unbounded, that leaves the screen spinning forever with
      // no way back; bounded, the caller simply gets an empty list and offers "Scan again".
      discovery = await nsd.startDiscovery('_kiboard._tcp').timeout(window);
      discovery.addServiceListener((service, status) {
        if (status != nsd.ServiceStatus.found) return;
        final host = _parse(service);
        if (host != null) found[host.id] = host;
      });
      await Future.delayed(window);
    } catch (_) {
      // No mDNS on this network, the platform denied the permission, or NSD hung: return what we
      // have (possibly nothing) — the caller falls back to QR/manual IP.
    } finally {
      if (discovery != null) {
        // Stopping can hang for the same reason. Never let cleanup block the result.
        try {
          await nsd.stopDiscovery(discovery).timeout(window);
        } catch (_) {}
      }
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
