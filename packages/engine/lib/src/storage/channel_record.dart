// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// The local row for a public list selected as a channel.
///
/// A channel is runtime state derived from the declarative catalogue, so it
/// lives in SQLite as required by R2 and ADR-0004. The protocol and endpoint
/// record which Mode C client can refresh it.
final class ChannelRecord {
  /// Creates a channel row.
  const ChannelRecord({
    required this.id,
    required this.listId,
    required this.label,
    required this.protocol,
    required this.endpoint,
  });

  /// Stable identifier taken from the catalogue source.
  final String id;

  /// RFC 2369 list identifier used to verify incoming messages.
  final String listId;

  /// Human-readable label shown by a front-end.
  final String label;

  /// Either `nntp` or `public_inbox`.
  final String protocol;

  /// Newsgroup or mirror address used to refresh the channel.
  final String endpoint;

  @override
  bool operator ==(Object other) =>
      other is ChannelRecord &&
      other.id == id &&
      other.listId == listId &&
      other.label == label &&
      other.protocol == protocol &&
      other.endpoint == endpoint;

  @override
  int get hashCode => Object.hash(id, listId, label, protocol, endpoint);
}
