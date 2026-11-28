// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Resolves the writable SQLite path for the local profile on every target.
///
/// The declarative configuration supplies only the file name. The operating
/// system support directory is the writable root, as required by R1 and R14.
Future<String> resolveProfilePath(
  String databaseFile, {
  Future<Directory> Function()? supportDirectory,
}) async {
  final directory =
      await (supportDirectory ?? getApplicationSupportDirectory)();
  return '${directory.path}${Platform.pathSeparator}$databaseFile';
}
