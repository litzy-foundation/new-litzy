// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:protocol/protocol.dart';

import '../storage/local_database.dart';

/// The engine's read-only verdict on one snapshot of inbox messages.
final class AuditReport {
  /// Creates a report with the messages in each verdict category.
  const AuditReport({
    required this.residual,
    required this.unmanaged,
    required this.quarantined,
  });

  /// List mail that remains in the inbox under an active policy.
  final List<InboxMessage> residual;

  /// List mail from a source with no stored policy.
  final List<InboxMessage> unmanaged;

  /// Messages held deliberately in the quarantine ledger.
  final List<InboxMessage> quarantined;
}

/// Classifies inbox mail against the policies stored in the local profile.
///
/// R15 requires the engine, not a front-end, to decide what counts as residual
/// list mail. The service only reads SQLite state and never touches a mailbox,
/// as required by ADR-0008.
final class AuditService {
  /// Creates an audit service over the local profile.
  const AuditService({required this.database});

  /// Local profile holding policies and the quarantine ledger.
  final LocalDatabase database;

  /// Classifies [messages] without changing the profile.
  AuditReport inspect(List<InboxMessage> messages) {
    final quarantined = database.quarantinedIds.toSet();
    final residual = <InboxMessage>[];
    final unmanaged = <InboxMessage>[];
    final held = <InboxMessage>[];
    for (final message in messages) {
      final listId = message.listId;
      if (listId == null || listId.isEmpty) continue;
      if (quarantined.contains(message.messageId)) {
        held.add(message);
      } else if (database.rawPolicyOf(listId) == null) {
        unmanaged.add(message);
      } else {
        residual.add(message);
      }
    }
    return AuditReport(
      residual: residual,
      unmanaged: unmanaged,
      quarantined: held,
    );
  }
}
