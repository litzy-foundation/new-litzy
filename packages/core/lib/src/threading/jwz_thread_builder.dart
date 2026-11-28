// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// JWZ message threading rebuilt from the preserved local implementation.
///
/// The algorithm reconstructs conversation trees from message identifiers and
/// reference chains even when a parent is missing, a reference is truncated or
/// the same message is delivered twice. It remains a pure function of its
/// input so the engine and both front-ends can rely on deterministic output.
library;

import '../text_tokens.dart';
import 'thread_node.dart';
import 'threadable_input.dart';

/// Mutable working container used only while a forest is being built.
final class _ThreadContainer {
  _ThreadContainer(this.id);

  final String id;
  ThreadableInput? message;
  _ThreadContainer? parent;
  final List<_ThreadContainer> children = [];

  bool get isDummy => message == null;
}

/// Builds thread forests with the JWZ reference-linking algorithm.
final class JwzThreadBuilder {
  /// Builds the thread forest for [messages].
  ///
  /// When [groupRootsBySubject] is true, roots whose subjects match after
  /// reply-prefix removal are collected under a synthetic container.
  List<ThreadNode> build(
    Iterable<ThreadableInput> messages, {
    bool groupRootsBySubject = false,
  }) {
    final containers = <String, _ThreadContainer>{};
    final seenIdentifiers = <String>{};
    var synthesized = 0;

    for (final message in messages) {
      final identifier = message.identifierWithFallback(++synthesized);
      if (!seenIdentifiers.add(identifier)) {
        continue;
      }
      final container = containers.putIfAbsent(
        identifier,
        () => _ThreadContainer(identifier),
      );
      container.message = message;

      _ThreadContainer? previous;
      for (final reference in message.references) {
        if (reference.isEmpty || reference == identifier) {
          continue;
        }
        final referenced = containers.putIfAbsent(
          reference,
          () => _ThreadContainer(reference),
        );
        if (previous != null &&
            referenced.parent == null &&
            !identical(referenced, previous) &&
            !_hasAncestor(referenced, previous) &&
            !_hasAncestor(previous, referenced)) {
          _addChild(previous, referenced);
        }
        previous = referenced;
      }
      if (previous != null &&
          !identical(previous, container) &&
          container.parent == null &&
          !_hasAncestor(container, previous) &&
          !_hasAncestor(previous, container)) {
        _addChild(previous, container);
      }
    }

    final roots = <_ThreadContainer>[];
    for (final candidate in containers.values.where(
      (item) => item.parent == null,
    )) {
      final kept = _prune(candidate);
      if (kept != null) {
        roots.add(kept);
      }
    }

    final selected = groupRootsBySubject ? _groupBySubject(roots) : roots;
    return [for (final root in selected) _toNode(root)];
  }

  static final RegExp _replyPrefix = RegExp(
    r'^\s*(re|fwd|fw)(\[\d+\])?:\s*',
    caseSensitive: false,
  );

  static bool _hasAncestor(
    _ThreadContainer candidate,
    _ThreadContainer ancestor,
  ) {
    var parent = candidate.parent;
    while (parent != null) {
      if (identical(parent, ancestor)) return true;
      parent = parent.parent;
    }
    return false;
  }

  static void _addChild(_ThreadContainer parent, _ThreadContainer child) {
    parent.children.add(child);
    child.parent = parent;
  }

  static _ThreadContainer? _prune(_ThreadContainer container) {
    final kept = <_ThreadContainer>[];
    for (final child in container.children) {
      final pruned = _prune(child);
      if (pruned != null) {
        pruned.parent = container;
        kept.add(pruned);
      }
    }
    container.children
      ..clear()
      ..addAll(kept);

    if (container.isDummy) {
      if (container.children.isEmpty) return null;
      if (container.children.length == 1) {
        final only = container.children.first;
        only.parent = null;
        return only;
      }
    }
    return container;
  }

  static ThreadNode _toNode(_ThreadContainer container) => ThreadNode(
    container.id,
    container.message,
    [for (final child in container.children) _toNode(child)],
  );

  static String _strippedSubject(String? subject) =>
      (subject ?? '').replaceAll(_replyPrefix, '').trim().toLowerCase();

  static List<_ThreadContainer> _groupBySubject(List<_ThreadContainer> roots) {
    final bySubject = <String, List<_ThreadContainer>>{};
    for (final root in roots) {
      bySubject
          .putIfAbsent(_strippedSubject(root.message?.subject), () => [])
          .add(root);
    }

    final grouped = <_ThreadContainer>[];
    final consumed = <_ThreadContainer>{};
    for (final entry in bySubject.entries) {
      final group = entry.value
          .where((item) => !consumed.contains(item))
          .toList();
      if (group.length < 2) {
        grouped.addAll(group);
        continue;
      }

      _ThreadContainer? canonical;
      for (final candidate in group) {
        final subject = candidate.message?.subject ?? '';
        if (subject.trim().toLowerCase() == entry.key) {
          canonical = candidate;
          break;
        }
      }
      canonical ??= group.first;

      final syntheticIdentifier =
          '${TextTokens.angleOpen}${TextTokens.groupIdentifier}'
          '${TextTokens.atSign}${TextTokens.localhost}${TextTokens.angleClose}';
      final groupRoot = _ThreadContainer(syntheticIdentifier)
        ..message = ThreadableInput(null, const [], subject: entry.key);
      groupRoot.children.add(canonical);
      canonical.parent = groupRoot;
      for (final other in group) {
        if (identical(other, canonical)) continue;
        consumed.add(other);
        groupRoot.children.add(other);
        other.parent = groupRoot;
      }
      consumed.add(canonical);
      grouped.add(groupRoot);
    }
    return grouped;
  }
}
