// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:core/core.dart';
import 'package:test/test.dart';

ThreadableInput message(
  String id,
  List<String> references, {
  String? subject,
}) => ThreadableInput(id, references, subject: subject);

String indent(ThreadNode node) =>
    TextTokens.space * (2 * node.depth) +
    (node.isDummy ? '*${node.messageId}' : node.messageId);

List<String> forest(List<ThreadNode> roots) => [
  for (final root in roots)
    for (final node in root.walk()) indent(node),
];

void main() {
  final builder = JwzThreadBuilder();

  test('a reference chain produces one linear thread', () {
    final roots = builder.build([
      message('<a@x>', []),
      message('<b@x>', ['<a@x>']),
      message('<c@x>', ['<a@x>', '<b@x>']),
    ]);
    expect(forest(roots), ['<a@x>', '  <b@x>', '    <c@x>']);
  });

  test('two replies to one parent remain separate branches', () {
    final roots = builder.build([
      message('<a@x>', []),
      message('<b@x>', ['<a@x>']),
      message('<c@x>', ['<a@x>']),
      message('<d@x>', ['<a@x>', '<c@x>']),
    ]);
    final root = roots.single;
    expect(root.children.map((node) => node.messageId), ['<b@x>', '<c@x>']);
    expect(root.children.last.children.single.messageId, '<d@x>');
  });

  test('a missing parent with two children stays as a dummy container', () {
    final roots = builder.build([
      message('<c1@x>', ['<missing-root@x>']),
      message('<c2@x>', ['<missing-root@x>']),
    ]);
    expect(forest(roots), ['*<missing-root@x>', '  <c1@x>', '  <c2@x>']);
  });

  test('a dummy parent with one child is promoted', () {
    final roots = builder.build([
      message('<child@x>', ['<missing-root@x>']),
    ]);
    expect(forest(roots), ['<child@x>']);
    expect(roots.single.messageCount, 1);
  });

  test('a reference cycle does not hang or lose messages', () {
    final roots = builder.build([
      message('<a@x>', ['<b@x>']),
      message('<b@x>', ['<a@x>']),
      message('<c@x>', ['<a@x>', '<b@x>']),
    ]);
    expect(forest(roots), ['<b@x>', '  <a@x>', '  <c@x>']);
  });

  test('a duplicate delivery is idempotent', () {
    final roots = builder.build([
      message('<a@x>', []),
      message('<a@x>', []),
      message('<b@x>', ['<a@x>']),
    ]);
    expect(roots.single.messageId, '<a@x>');
    expect(roots.single.messageCount, 2);
    expect(roots.single.children.single.messageId, '<b@x>');
  });

  test('a missing identifier receives a synthetic value', () {
    final roots = builder.build([
      ThreadableInput(null, []),
      message('<b@x>', []),
    ]);
    expect(roots, hasLength(2));
    expect(
      roots.first.messageId,
      startsWith('${TextTokens.angleOpen}${TextTokens.missingPrefix}'),
    );
  });

  test('empty input yields an empty forest', () {
    expect(builder.build([]), isEmpty);
  });

  test('matching subjects are grouped under one synthetic root', () {
    final roots = builder.build([
      message('<t1@x>', [], subject: 'gpu hang on amdgpu'),
      message('<t2@x>', [], subject: 'Re: gpu hang on amdgpu'),
      message('<t3@x>', [], subject: 'Re: gpu hang on amdgpu'),
      message('<other@x>', [], subject: 'completely different topic'),
    ], groupRootsBySubject: true);
    final group = roots.singleWhere(
      (node) => node.messageId.contains(TextTokens.groupIdentifier),
    );
    expect(group.messageId, contains(TextTokens.groupIdentifier));
    expect(group.children.map((node) => node.messageId).toSet(), {
      '<t1@x>',
      '<t2@x>',
      '<t3@x>',
    });
    expect(roots.any((node) => node.messageId == '<other@x>'), isTrue);
  });

  test('a deep chain preserves its depth', () {
    final messages = [message('<l0@x>', [])];
    for (var index = 1; index <= 15; index++) {
      messages.add(message('<l$index@x>', ['<l${index - 1}@x>']));
    }
    final root = builder.build(messages).single;
    var node = root;
    var depth = 0;
    while (node.children.isNotEmpty) {
      node = node.children.single;
      depth++;
    }
    expect(depth, 15);
    expect(root.messageCount, 16);
  });
}
