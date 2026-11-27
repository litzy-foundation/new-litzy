// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Reports command-line input that cannot be mapped to a typed request.
final class CliUsageException implements Exception {
  /// Creates a usage error with a readable [message].
  const CliUsageException(this.message);

  /// Explanation of the invalid input.
  final String message;

  @override
  String toString() => 'usage error: $message';
}

/// One operation requested by the user.
sealed class CliCommand {
  /// Creates a command.
  const CliCommand();
}

/// Checks that the engine isolate answers.
final class PingCommand extends CliCommand {
  /// Creates a ping command.
  const PingCommand();
}

/// Refreshes a catalogue channel through the engine.
final class SyncCommand extends CliCommand {
  /// Creates a sync command for one catalogue source.
  const SyncCommand(this.cataloguePath, this.sourceId);

  /// Path of the declarative source catalogue.
  final String cataloguePath;

  /// Stable identifier of the source to refresh.
  final String sourceId;
}

/// Searches subjects and bodies through the full-text index.
final class SearchCommand extends CliCommand {
  /// Creates a search command for [terms].
  const SearchCommand(this.terms);

  /// Full-text query terms.
  final String terms;
}

/// Reads one thread in pre-order.
final class ThreadCommand extends CliCommand {
  /// Creates a thread command for [rootId].
  const ThreadCommand(this.rootId);

  /// Identifier of the thread root.
  final String rootId;
}

/// A parsed invocation with its profile location and requested operation.
final class ParsedCliCommand {
  /// Creates a parsed command with optional local paths.
  const ParsedCliCommand({
    this.databasePath,
    this.blobsDirectory,
    required this.command,
  });

  /// Path of the SQLite profile, or null for a command that needs no data.
  final String? databasePath;

  /// Optional folder for raw message content.
  final String? blobsDirectory;

  /// Operation to execute.
  final CliCommand command;
}

/// Parses command-line arguments without touching the engine.
ParsedCliCommand parseCommandLine(List<String> arguments) {
  final options = <String, String>{};
  final positional = <String>[];
  for (var index = 0; index < arguments.length; index++) {
    final token = arguments[index];
    if (token.startsWith('--')) {
      if (index + 1 >= arguments.length ||
          arguments[index + 1].startsWith('--')) {
        throw CliUsageException('$token needs a value');
      }
      options[token.substring(2)] = arguments[++index];
    } else {
      positional.add(token);
    }
  }
  if (positional.isEmpty) throw const CliUsageException('no command given');
  final name = positional.removeAt(0);
  final database = options['database'];
  if (name != 'ping' && (database == null || database.isEmpty)) {
    throw const CliUsageException('--database is required for data commands');
  }
  if (positional.length > 1) {
    throw const CliUsageException('a command takes at most one argument');
  }
  final argument = positional.isEmpty ? null : positional.single;
  final blobs = options['blobs'];

  switch (name) {
    case 'ping':
      if (argument != null) {
        throw const CliUsageException('ping takes no argument');
      }
      return ParsedCliCommand(
        databasePath: database,
        blobsDirectory: blobs,
        command: const PingCommand(),
      );
    case 'sync':
      final catalogue = options['catalogue'];
      final source = options['source'];
      if (catalogue == null ||
          catalogue.isEmpty ||
          source == null ||
          source.isEmpty) {
        throw const CliUsageException('sync needs --catalogue and --source');
      }
      if (argument != null) {
        throw const CliUsageException('sync takes no argument');
      }
      return ParsedCliCommand(
        databasePath: database,
        blobsDirectory: blobs,
        command: SyncCommand(catalogue, source),
      );
    case 'search':
      if (argument == null || argument.isEmpty) {
        throw const CliUsageException('search needs query terms');
      }
      return ParsedCliCommand(
        databasePath: database,
        blobsDirectory: blobs,
        command: SearchCommand(argument),
      );
    case 'thread':
      if (argument == null || argument.isEmpty) {
        throw const CliUsageException('thread needs a root identifier');
      }
      return ParsedCliCommand(
        databasePath: database,
        blobsDirectory: blobs,
        command: ThreadCommand(argument),
      );
    default:
      throw CliUsageException('unknown command $name');
  }
}
