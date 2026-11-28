// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Port for reading autoconfiguration documents over HTTPS.
///
/// The port keeps hostile redirect, size and timeout policy outside the
/// discovery algorithm so tests can supply deterministic fakes, as required by
/// ADR-0025.
library;

/// One autoconfiguration document with the address that actually served it.
typedef DiscoveryDocument = ({Uri finalUri, String body});

/// Reads one document while enforcing the limits passed by the caller.
abstract interface class DiscoveryHttpClient {
  /// Fetches [uri] with the given [timeout], [maxBytes] and [redirectBudget].
  ///
  /// Implementations reject a plaintext remote address, a redirect that
  /// changes origin or scheme, and a response larger than [maxBytes]. A
  /// plaintext loopback address is accepted only when the caller's policy
  /// explicitly allows fixtures.
  Future<DiscoveryDocument> get(
    Uri uri, {
    required Duration timeout,
    required int maxBytes,
    required int redirectBudget,
  });
}
