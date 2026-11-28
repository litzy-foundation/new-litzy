// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Shared interpretation of RFC 5322 headers for ingested messages.
///
/// Keeping these rules in one place lets Mode C and local import build the
/// same thread shape without duplicating parsing decisions.
library;

/// Extracts a message identifier from a header value.
String headerIdentifier(String? value) =>
    value?.replaceAll(RegExp(r'[<>\s]'), '') ?? '';

/// Parses a date header into epoch seconds, or zero when it is unparseable.
int headerEpoch(String? value) {
  final parsed = value == null ? null : DateTime.tryParse(value);
  return parsed == null ? 0 : parsed.millisecondsSinceEpoch ~/ 1000;
}

/// Resolves the thread root of a message from its references and reply header.
String headerThreadRoot({
  required String messageId,
  required String inReplyTo,
  required String references,
  required Map<String, String> roots,
}) {
  final parent = headerIdentifier(inReplyTo);
  final firstReference = headerIdentifier(
    RegExp(r'<[^>]+>').firstMatch(references)?.group(0),
  );
  if (firstReference.isNotEmpty) return firstReference;
  if (parent.isNotEmpty && roots.containsKey(parent)) return roots[parent]!;
  return messageId;
}
