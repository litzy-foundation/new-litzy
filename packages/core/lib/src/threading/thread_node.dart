// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// One node in a reconstructed thread forest.
library;

import 'threadable_input.dart';

/// A node that either carries a real message or marks a missing parent.
final class ThreadNode {
  /// Creates a node with [children] already attached in order.
  ThreadNode(this.messageId, this.message, List<ThreadNode> children)
    : _children = List.unmodifiable(children) {
    for (final child in _children) {
      child._parent = this;
    }
  }

  /// Identifier of the message or of the missing parent container.
  final String messageId;

  /// The message carried by this node, or null for a dummy container.
  final ThreadableInput? message;

  ThreadNode? _parent;

  final List<ThreadNode> _children;

  /// Parent of this node, or null when it is a root.
  ThreadNode? get parent => _parent;

  /// Children in reference order.
  List<ThreadNode> get children => _children;

  /// Whether no message sits on this node.
  bool get isDummy => message == null;

  /// Number of ancestor links between this node and its root.
  int get depth {
    var depth = 0;
    var parent = _parent;
    while (parent != null) {
      depth++;
      parent = parent._parent;
    }
    return depth;
  }

  /// Depth-first pre-order walk of this subtree.
  Iterable<ThreadNode> walk() sync* {
    yield this;
    for (final child in _children) {
      yield* child.walk();
    }
  }

  /// Number of real messages in this subtree.
  int get messageCount => walk().where((node) => !node.isDummy).length;
}
