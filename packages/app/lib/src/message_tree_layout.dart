// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:protocol/protocol.dart';

/// Computes the visual depth of each message in a reconstructed conversation.
final class MessageTreeLayout {
  /// Creates a layout calculator with no mutable state.
  const MessageTreeLayout();

  /// Returns a depth by message identifier for [messages].
  ///
  /// A missing parent or a reference cycle is treated as a root, so the
  /// presenter never throws while drawing data that the engine accepted.
  Map<String, int> depthsFor(List<MessageData> messages) {
    final byId = <String, MessageData>{
      for (final message in messages) message.id: message,
    };
    final depths = <String, int>{};

    for (final message in messages) {
      var depth = 0;
      final visited = <String>{message.id};
      var parentId = message.parentId;
      while (parentId != null &&
          byId.containsKey(parentId) &&
          visited.add(parentId)) {
        depth++;
        parentId = byId[parentId]!.parentId;
      }
      depths[message.id] = depth;
    }
    return Map.unmodifiable(depths);
  }
}
