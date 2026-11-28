// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Sealed body blocks produced by plain-text message analysis.
///
/// The subtypes live in separate files as parts of this library so the
/// analyzer can exhaustively switch over them while each public class keeps
/// one file and one reason to change.
library;

import '../text_tokens.dart';

part 'diff_block.dart';
part 'quote_block.dart';
part 'text_block.dart';

/// A block produced by body analysis.
sealed class BodyBlock {
  /// Creates a body block.
  const BodyBlock();
}
