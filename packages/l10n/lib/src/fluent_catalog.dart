// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:convert';

import 'fluent_parse_exception.dart';
import 'missing_message_exception.dart';
import 'missing_placeholder_exception.dart';

/// Parses a Fluent resource and renders messages by key.
///
/// The parser supports simple messages and named placeholders. Plural forms
/// and attributes are deliberately absent because the current interface does
/// not use them and an unsupported construct must fail rather than render
/// incorrectly.
final class FluentCatalog {
  FluentCatalog._(this._messages);

  static final RegExp _entry = RegExp(r'^\s*([a-z][a-z0-9-]*)\s*=\s*(.*)$');
  static final RegExp _placeholder = RegExp(
    r'\{\s*\$\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}',
  );
  static const String _commentPrefix = '#';

  final Map<String, String> _messages;

  /// Parses [source] into an immutable message catalogue.
  factory FluentCatalog.parse(String source) {
    final messages = <String, String>{};
    for (final line in const LineSplitter().convert(source)) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith(_commentPrefix)) continue;
      final match = _entry.firstMatch(trimmed);
      if (match == null) {
        throw FluentParseException(line, 'the Fluent entry is malformed');
      }
      final key = match.group(1)!;
      if (messages.containsKey(key)) {
        throw FluentParseException(line, 'the key $key appears twice');
      }
      messages[key] = match.group(2)!;
    }
    return FluentCatalog._(Map.unmodifiable(messages));
  }

  /// Renders the message named [key] with named [arguments].
  ///
  /// Every placeholder in the message must have a matching argument. An
  /// unmatched placeholder is a programming error and throws a typed
  /// exception instead of displaying a raw token.
  String message(String key, [Map<String, Object> arguments = const {}]) {
    final template = _messages[key];
    if (template == null) throw MissingMessageException(key);
    return template.replaceAllMapped(_placeholder, (match) {
      final name = match.group(1)!;
      final value = arguments[name];
      if (value == null) throw MissingPlaceholderException(key, name);
      return value.toString();
    });
  }
}
