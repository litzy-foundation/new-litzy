// Copyright (c) 2026 Alessio Attilio and the litzy contributors
part of 'message.dart';

/// Immutable topic summary used by a front-end's channel feed.
typedef ThreadSummary = ({
  String rootId,
  String listId,
  String subject,
  int messageCount,
  int lastActivityEpoch,
});
