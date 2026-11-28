// Copyright (c) 2026 Alessio Attilio and the litzy contributors
part of 'body_block.dart';

/// A patch payload with its file headers and hunk count.
final class DiffBlock extends BodyBlock {
  /// Creates a diff block from its verbatim payload and metadata.
  const DiffBlock(this.raw, this.fileHeaders, this.hunkHeaderCount);

  /// Verbatim diff payload.
  final String raw;

  /// File header values without their leading markers.
  final List<String> fileHeaders;

  /// Number of unified diff hunk headers found.
  final int hunkHeaderCount;
}
