// Copyright (c) 2026 Alessio Attilio and the litzy contributors
part of 'message.dart';

/// Requests one reconstructed thread for display by a front-end.
final class ShowThreadRequest extends LmlpRequest {
  /// Creates a show request for [rootId].
  const ShowThreadRequest(super.id, this.rootId);

  /// Identifier of the thread root.
  final String rootId;
}
