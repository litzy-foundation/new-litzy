// Copyright (c) 2026 Alessio Attilio and the litzy contributors
part of 'message.dart';

/// Returns topic summaries ordered by last activity.
final class ThreadListResponse extends LmlpResponse {
  /// Creates a response with the listed [threads].
  const ThreadListResponse(super.id, this.threads);

  /// Topic summaries for the requested channels.
  final List<ThreadSummary> threads;
}
