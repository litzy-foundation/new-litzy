// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:core/core.dart';

import '../storage/local_database.dart';

/// Reports why a reply draft could not be prepared.
final class DraftException implements Exception {
  /// Creates an exception with a stable [code] and a readable [message].
  const DraftException(this.code, this.message);

  /// Stable failure code such as `empty_reply`.
  final String code;

  /// Explanation of the failure.
  final String message;

  @override
  String toString() => 'draft failed ($code): $message';
}

/// The quoted reply prepared by the engine.
typedef PreparedDraft = ({
  String draftId,
  String messageId,
  String subject,
  String body,
});

/// Builds and stores local reply drafts without sending mail.
///
/// R17 requires reply inside the application, while R26 places outbound
/// transport in a separate slice. Keeping quoting and storage here means both
/// front-ends prepare the same reply and never touch SQLite directly.
final class DraftService {
  /// Creates a draft service over the local profile.
  const DraftService({required this.database});

  /// Local profile holding the source message and the draft.
  final LocalDatabase database;

  /// Stores a quoted reply to [messageId] and returns its content.
  PreparedDraft create(String messageId, String body) {
    final original = database.messageOf(messageId);
    if (original == null) {
      throw const DraftException(
        'message_not_found',
        'the message is not in the open profile',
      );
    }
    final written = body.trim();
    if (written.isEmpty) {
      throw const DraftException('empty_reply', 'a reply must contain text');
    }
    final subject = original.subject.startsWith('Re:')
        ? original.subject
        : 'Re: ${original.subject}';
    final quoted = original.body
        .split(TextTokens.lineFeed)
        .map((line) => '${TextTokens.quoteMarker} $line')
        .join(TextTokens.lineFeed);
    final prepared =
        '$written${TextTokens.lineFeed}${TextTokens.lineFeed}'
        'On ${original.fromAddress} wrote:${TextTokens.lineFeed}$quoted';
    final draftId = 'draft:$messageId';
    database.saveDraft(
      draftId,
      messageId,
      subject,
      prepared,
      DateTime.now().millisecondsSinceEpoch,
    );
    return (
      draftId: draftId,
      messageId: messageId,
      subject: subject,
      body: prepared,
    );
  }
}
