// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Fluent message resources and typed keys shared by Litzy front-ends.
///
/// The Fluent file under `data/l10n` is the source of truth. Dart code names
/// keys only, as required by R47, and a missing key fails explicitly rather
/// than appearing in the interface.
library;

export 'src/app_messages.dart';
export 'src/fluent_catalog.dart';
export 'src/fluent_parse_exception.dart';
export 'src/missing_message_exception.dart';
export 'src/missing_placeholder_exception.dart';
