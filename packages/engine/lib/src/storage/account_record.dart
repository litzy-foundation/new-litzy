// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Non-secret settings of one connected mail account.
///
/// A record never holds a credential: secrets stay in the operating system
/// keychain as required by R35 and R37.
library;

/// Stored account settings with their stable identifier.
typedef AccountRecord = ({
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
