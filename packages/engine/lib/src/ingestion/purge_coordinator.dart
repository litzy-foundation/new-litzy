// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../storage/local_blob_store.dart';
import '../storage/local_database.dart';
import 'mailbox_action.dart';
import 'mailbox_port.dart';

/// One message considered for mailbox separation.
final class PurgeCandidate {
  /// Creates a candidate from its mailbox and persisted identifiers.
  const PurgeCandidate({
    required this.uid,
    required this.messageId,
    required this.checksum,
  });

  /// Mailbox unique identifier used by the IMAP action.
  final String uid;

  /// Identifier of the persisted message.
  final String messageId;

  /// Digest that must match both the database and the local blob store.
  final String checksum;
}

/// The verified result of the first phase of a purge decision.
final class PreparedPurge {
  /// Creates a preparation with its verified and quarantined candidates.
  const PreparedPurge({
    required this.id,
    required this.listId,
    required this.accepted,
    required this.quarantined,
    required this.digest,
  });

  /// Caller-provided identifier of this decision.
  final String id;

  /// List whose policy governs the second phase.
  final String listId;

  /// Candidates that passed verification.
  final List<PurgeCandidate> accepted;

  /// Candidates kept aside because verification failed.
  final List<PurgeCandidate> quarantined;

  /// SHA-256 digest binding the accepted candidates to the preparation.
  final String digest;
}

/// The result of applying a verified preparation.
sealed class PurgeOutcome {
  /// Creates an outcome.
  const PurgeOutcome();
}

/// Reports the mailbox action that was applied.
final class PurgeApplied extends PurgeOutcome {
  /// Creates an applied outcome with the action name and affected identifiers.
  const PurgeApplied(this.action, this.uids);

  /// Stable name of the applied action.
  final String action;

  /// Unique identifiers affected by the action.
  final List<String> uids;
}

/// Reports why a preparation was not applied.
final class PurgeRejected extends PurgeOutcome {
  /// Creates a rejected outcome with a readable reason.
  const PurgeRejected(this.reason);

  /// Explanation of the rejection.
  final String reason;
}

/// Applies mailbox separation behind a two-phase, checksum-gated decision.
///
/// The first phase verifies persistence and quarantines doubtful messages.
/// The second phase rechecks the digest and the bytes before touching the
/// mailbox, then applies the policy chosen for that list, as required by
/// R15 and ADR-0008.
final class PurgeCoordinator {
  /// Creates a coordinator over the local store and a mailbox port.
  const PurgeCoordinator({
    required this.database,
    required this.blobs,
    required this.mailbox,
  });

  /// Local store holding messages, policies and preparations.
  final LocalDatabase database;

  /// Content-addressed store holding the verified bytes.
  final LocalBlobStore blobs;

  /// Mailbox port on which the second phase acts.
  final MailboxPort mailbox;

  /// Verifies candidates, quarantines doubtful ones and records the digest.
  Future<PreparedPurge> prepare(
    String decisionId,
    String listId,
    List<PurgeCandidate> candidates,
  ) async {
    final accepted = <PurgeCandidate>[];
    final quarantined = <PurgeCandidate>[];
    for (final candidate in candidates) {
      if (_isVerified(candidate)) {
        accepted.add(candidate);
      } else {
        quarantined.add(candidate);
      }
    }
    database.quarantine(
      quarantined.map((candidate) => candidate.messageId).toList(),
    );
    final digest = _digest(accepted);
    database.recordPreparation(decisionId, listId, digest);
    return PreparedPurge(
      id: decisionId,
      listId: listId,
      accepted: accepted,
      quarantined: quarantined,
      digest: digest,
    );
  }

  /// Applies a preparation once, after rechecking its digest and content.
  Future<PurgeOutcome> commit(PreparedPurge plan) async {
    final recorded = database.preparationDigestOf(plan.id);
    if (recorded == null || recorded != _digest(plan.accepted)) {
      return const PurgeRejected('preparation is missing or altered');
    }
    if (database.isPreparationConsumed(plan.id)) {
      return const PurgeRejected('preparation was already consumed');
    }
    if (plan.accepted.isEmpty) {
      return const PurgeRejected('no verified messages in preparation');
    }
    for (final candidate in plan.accepted) {
      if (!_isVerified(candidate)) {
        return PurgeRejected(
          'checksum verification failed for ${candidate.messageId}',
        );
      }
    }

    final uids = plan.accepted.map((candidate) => candidate.uid).toList();
    final action = mailboxActionFromStorage(database.rawPolicyOf(plan.listId));
    try {
      switch (action) {
        case MailboxAction.moveToIngested:
          await mailbox.moveToFolder(
            uids,
            database.policyFolderOf(plan.listId) ?? 'Litzy/Ingested',
          );
        case MailboxAction.markSeen:
          await mailbox.markSeen(uids);
        case MailboxAction.expunge:
          await mailbox.expunge(uids);
      }
    } catch (error) {
      return PurgeRejected('mailbox action failed: $error');
    }
    database.consumePreparation(plan.id);
    return PurgeApplied(action.storageName, uids);
  }

  bool _isVerified(PurgeCandidate candidate) {
    if (candidate.checksum.isEmpty) return false;
    if (database.checksumOf(candidate.messageId) != candidate.checksum) {
      return false;
    }
    return blobs.verify(candidate.checksum);
  }

  static String _digest(List<PurgeCandidate> candidates) {
    final canonical = candidates
        .map(
          (candidate) =>
              '${candidate.messageId}:${candidate.uid}:${candidate.checksum}',
        )
        .join('|');
    return sha256.convert(utf8.encode(canonical)).toString();
  }
}
