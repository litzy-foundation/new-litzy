// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Named text values shared by deterministic domain algorithms.
///
/// Control characters and common markers are represented here so algorithm
/// files refer to keys rather than raw literals, as required by R47.
library;

/// Named values used when analysing or constructing message text.
final class TextTokens {
  const TextTokens._();

  /// Line feed character.
  static final String lineFeed = String.fromCharCode(10);

  /// Carriage return character.
  static final String carriageReturn = String.fromCharCode(13);

  /// Horizontal tab character.
  static final String horizontalTab = String.fromCharCode(9);

  /// Null character.
  static final String nullCharacter = String.fromCharCode(0);

  /// Ordinary space.
  static const String space = ' ';

  /// Citation marker used by email clients.
  static const String quoteMarker = '>';

  /// Opening angle bracket of a message identifier.
  static const String angleOpen = '<';

  /// Closing angle bracket of a message identifier.
  static const String angleClose = '>';

  /// At sign used in message identifiers and addresses.
  static const String atSign = '@';

  /// Colon used in header and marker prefixes.
  static const String colon = ':';

  /// Hyphen used in diff headers.
  static const String hyphen = '-';

  /// Plus sign used in diff headers.
  static const String plus = '+';

  /// Comma used in diff hunk ranges.
  static const String comma = ',';

  /// Prefix of a synthetic identifier for a missing message.
  static const String missingPrefix = 'litzy-missing-';

  /// Identifier of a synthetic grouping container.
  static const String groupIdentifier = 'litzy-thread-group';

  /// Host used by synthetic identifiers.
  static const String localhost = 'localhost';
}
