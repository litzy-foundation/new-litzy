// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// DNS service record resolver over UDP.
///
/// The resolver reads the system nameserver where that is available. It is a
/// hint only: ADR-0025 marks SRV endpoints as unverified because DNS is not
/// authenticated.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'discovery_exception.dart';
import 'dns_srv_resolver.dart';

/// Resolves SRV records with a single UDP query to the system nameserver.
final class UdpDnsSrvResolver implements DnsSrvResolver {
  /// Creates a resolver, optionally with an explicit nameserver for fixtures.
  const UdpDnsSrvResolver({this.nameserver, this.port = 53});

  /// IPv4 address of the resolver, or null to read the system configuration.
  final String? nameserver;

  /// UDP port of the resolver.
  final int port;

  static const int _srvType = 33;
  static const int _internetClass = 1;
  static const int _pointer = 0xC0;
  static const int _maxNameJumps = 32;

  @override
  Future<List<SrvRecord>> resolve(String name, {Duration? timeout}) async {
    final address = nameserver ?? _systemNameserver();
    if (address == null) {
      throw const DiscoveryException(
        'dns_unavailable',
        'no DNS resolver is configured on this host',
      );
    }
    final deadline = timeout ?? const Duration(seconds: 3);
    final transactionId = Random().nextInt(1 << 16);
    final query = _query(transactionId, name);
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    final completer = Completer<Datagram>();
    final subscription = socket.listen((event) {
      if (event == RawSocketEvent.read && !completer.isCompleted) {
        final datagram = socket.receive();
        if (datagram != null) completer.complete(datagram);
      }
    });
    try {
      final sent = socket.send(query, InternetAddress(address), port);
      if (sent != query.length) {
        throw const DiscoveryException(
          'dns_unavailable',
          'the DNS query could not be sent',
        );
      }
      final datagram = await completer.future.timeout(
        deadline,
        onTimeout: () => throw const DiscoveryException(
          'discovery_timeout',
          'the DNS query timed out',
        ),
      );
      return _records(datagram.data, transactionId);
    } finally {
      subscription.cancel();
      socket.close();
    }
  }

  Uint8List _query(int transactionId, String name) {
    final bytes = BytesBuilder(copy: false);
    bytes.add([
      transactionId >> 8,
      transactionId & 0xFF,
      0x01,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
    ]);
    for (final label in name.split('.')) {
      if (label.isEmpty || label.length > 63) {
        throw const DiscoveryException(
          'invalid_email',
          'the service name is not a valid DNS name',
        );
      }
      bytes.add([label.length]);
      bytes.add(ascii.encode(label));
    }
    bytes.add([
      0x00,
      _srvType >> 8,
      _srvType & 0xFF,
      _internetClass >> 8,
      _internetClass & 0xFF,
    ]);
    return bytes.takeBytes();
  }

  List<SrvRecord> _records(Uint8List bytes, int transactionId) {
    if (bytes.length < 12) {
      throw const DiscoveryException(
        'dns_failed',
        'the DNS answer was truncated',
      );
    }
    final responseId = (bytes[0] << 8) | bytes[1];
    if (responseId != transactionId) {
      throw const DiscoveryException(
        'dns_failed',
        'the DNS answer did not match the query',
      );
    }
    final questions = (bytes[4] << 8) | bytes[5];
    final answers = (bytes[6] << 8) | bytes[7];
    var offset = 12;
    for (var index = 0; index < questions; index++) {
      offset = _skipName(bytes, offset);
      offset += 4;
    }
    final records = <SrvRecord>[];
    for (var index = 0; index < answers; index++) {
      offset = _skipName(bytes, offset);
      if (offset + 10 > bytes.length) break;
      final type = (bytes[offset] << 8) | bytes[offset + 1];
      final length = (bytes[offset + 8] << 8) | bytes[offset + 9];
      offset += 10;
      final end = offset + length;
      if (type != _srvType || end > bytes.length || length < 7) {
        offset = end;
        continue;
      }
      final priority = (bytes[offset] << 8) | bytes[offset + 1];
      final weight = (bytes[offset + 2] << 8) | bytes[offset + 3];
      final port = (bytes[offset + 4] << 8) | bytes[offset + 5];
      final target = _name(bytes, offset + 6, end);
      records.add((
        priority: priority,
        weight: weight,
        port: port,
        target: target,
      ));
      offset = end;
    }
    records.sort((a, b) {
      final byPriority = a.priority.compareTo(b.priority);
      return byPriority != 0 ? byPriority : b.weight.compareTo(a.weight);
    });
    return List<SrvRecord>.unmodifiable(records);
  }

  int _skipName(Uint8List bytes, int offset) {
    var position = offset;
    var jumps = 0;
    while (position < bytes.length && jumps <= _maxNameJumps) {
      final length = bytes[position];
      if (length == 0) return position + 1;
      if ((length & _pointer) == _pointer) {
        return position + 2;
      }
      position += length + 1;
      jumps++;
    }
    throw const DiscoveryException('dns_failed', 'the DNS name was malformed');
  }

  String _name(Uint8List bytes, int offset, int end) {
    final labels = <String>[];
    var position = offset;
    var jumps = 0;
    while (position < end && jumps <= _maxNameJumps) {
      final length = bytes[position];
      if (length == 0) break;
      if ((length & _pointer) == _pointer) {
        if (position + 1 >= bytes.length) break;
        position = ((length & 0x3F) << 8) | bytes[position + 1];
        jumps++;
        continue;
      }
      final start = position + 1;
      final finish = start + length;
      if (finish > bytes.length) break;
      labels.add(String.fromCharCodes(bytes, start, finish));
      position = finish;
    }
    return labels.join('.');
  }

  String? _systemNameserver() {
    final file = File('/etc/resolv.conf');
    if (!file.existsSync()) return null;
    for (final line in file.readAsLinesSync()) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2 && parts.first == 'nameserver') {
        if (InternetAddress.tryParse(parts[1])?.type ==
            InternetAddressType.IPv4) {
          return parts[1];
        }
      }
    }
    return null;
  }
}
