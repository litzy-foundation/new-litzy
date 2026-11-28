// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:test/test.dart';
import 'package:engine/engine.dart';

void main() {
  test('the default catalogue names the Git list from versioned YAML', () {
    final defaults = DefaultCatalogue.resolve();

    expect(defaults.sourceId, 'git');
    expect(defaults.cataloguePath.endsWith('lists.yaml'), isTrue);
    expect(File(defaults.cataloguePath).existsSync(), isTrue);
  });

  test('the default catalogue loads the Git source without credentials', () {
    final defaults = DefaultCatalogue.resolve();
    final sources = CatalogLoader.load(defaults.cataloguePath);

    final git = sources.singleWhere((source) => source.id == defaults.sourceId);

    expect(git.listId, 'git@vger.kernel.org');
    expect(git.inboxBaseUrl.isNotEmpty, isTrue);
  });
}
