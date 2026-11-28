// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:app/app.dart';
import 'package:core/core.dart';
import 'package:engine/engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';
import 'package:material_ui/material_ui.dart';
import 'package:protocol/protocol.dart';
import 'package:yaml/yaml.dart';

/// Initializes the binding used by declarative asset loading in tests.
void initializeAppTests() {
  TestWidgetsFlutterBinding.ensureInitialized();
}

/// Builds a theme without animated ink, which widget tests cannot rasterize.
ThemeData testTheme() => ThemeData(splashFactory: NoSplash.splashFactory);

/// Finds the workspace root from the current test working directory.
Directory litzyRoot() {
  var directory = Directory.current;
  while (true) {
    final manifest = File(
      '${directory.path}${Platform.pathSeparator}pubspec.yaml',
    );
    if (manifest.existsSync() &&
        manifest.readAsStringSync().contains('- packages/app')) {
      return directory;
    }
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  throw StateError('the Litzy root was not found');
}

/// Reads a versioned file through its path under the workspace root.
String resourceText(String relativePath) =>
    File('${litzyRoot().path}${Platform.pathSeparator}$relativePath')
        .readAsStringSync();

/// Builds the declarative bundle used by widget tests.
AppBundle testBundle() {
  return AppBundle(
    messages: AppMessages(
      FluentCatalog.parse(resourceText('data/l10n/en.ftl')),
    ),
    layout: LayoutConfig.fromYaml(resourceText('data/ui/layout.yaml')),
    theme: ThemeConfig.fromYaml(resourceText('data/ui/theme.yaml')),
    markers: SubjectMarkers.fromYaml(
      resourceText('data/ui/subject_markers.yaml'),
    ),
    profile: ProfileConfig.fromYaml(resourceText('data/app/profile.yaml')),
  );
}

/// Returns the Git channel declared by the versioned default catalogue.
ChannelView defaultGitChannel() {
  final defaults = DefaultCatalogue.resolve();
  final source = CatalogLoader.load(defaults.cataloguePath)
      .singleWhere((candidate) => candidate.id == defaults.sourceId);
  final channel = ChannelMapper.fromSource(source);
  return (
    id: channel.id,
    listId: channel.listId,
    label: channel.label,
    protocol: channel.protocol,
    endpoint: channel.endpoint,
  );
}

/// Reads the recorded public-inbox thread used by the GUI tests.
List<MessageData> fixtureMessages() {
  final rawMessages = LocalMailParser.parseMbox(
    resourceText('data/fixtures/git_public_inbox_thread.mbox'),
  );
  final rootId = _identifier(rawMessages.first.headers['message-id']!);
  return [
    for (final raw in rawMessages)
      MessageData(
        id: _identifier(raw.headers['message-id']!),
        listId: _identifier(raw.headers['list-id']!),
        subject: raw.headers['subject']!,
        fromAddress: raw.headers['from']!,
        dateEpoch: headerEpoch(raw.headers['date']),
        parentId: raw.headers['in-reply-to'] == null
            ? null
            : _identifier(raw.headers['in-reply-to']!),
        threadRootId: rootId,
        body: raw.body,
        checksum: raw.checksum,
      ),
  ];
}

/// Summarises the recorded thread for a fake reading source.
List<ThreadSummary> fixtureSummaries() {
  final messages = fixtureMessages();
  final root = messages.first;
  return [
    (
      rootId: root.id,
      listId: root.listId,
      subject: root.subject,
      messageCount: messages.length,
      lastActivityEpoch: messages.last.dateEpoch,
    ),
  ];
}

/// Reads the synthetic body fixture used by the rendering tests.
({String quotedContext, String prose, List<String> diffLines})
guiBodyFixture() {
  final document = loadYaml(resourceText('data/fixtures/gui_body_blocks.yaml'));
  if (document is! YamlMap || document['version'] != 1) {
    throw StateError('the GUI body fixture has an unsupported version');
  }
  final quotedContext = document['quoted_context'];
  final prose = document['prose'];
  final diffLines = document['diff_lines'];
  if (quotedContext is! String ||
      prose is! String ||
      diffLines is! List ||
      diffLines.any((line) => line is! String)) {
    throw StateError('the GUI body fixture is malformed');
  }
  return (
    quotedContext: quotedContext,
    prose: prose,
    diffLines: List<String>.from(diffLines),
  );
}

String _identifier(String value) => value
    .replaceAll(TextTokens.angleOpen, '')
    .replaceAll(TextTokens.angleClose, '')
    .trim();
