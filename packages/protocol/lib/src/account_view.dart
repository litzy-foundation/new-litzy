// Copyright (c) 2026 Alessio Attilio and the litzy contributors
part of 'message.dart';

/// Immutable view of the non-secret settings of a connected account.
typedef AccountView = ({
  String id,
  String email,
  String imapHost,
  int imapPort,
  String smtpHost,
  int smtpPort,
  String authentication,
  String listId,
  int createdAt,
});
