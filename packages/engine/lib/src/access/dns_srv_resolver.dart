// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Port for DNS service records used by mail autodiscovery.
///
/// DNS is an untrusted hint in ADR-0025: a record can point to any host, so the
/// service marks SRV endpoints as unverified. Tests replace this port with a
/// deterministic fake and never contact a real resolver.
library;

/// One DNS service record.
typedef SrvRecord = ({int priority, int weight, int port, String target});

/// Resolves SRV records for one service name.
abstract interface class DnsSrvResolver {
  /// Returns the records for [name], ordered by priority and weight.
  Future<List<SrvRecord>> resolve(String name, {Duration? timeout});
}
