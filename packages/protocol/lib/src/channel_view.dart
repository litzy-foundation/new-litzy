// Copyright (c) 2026 Alessio Attilio and the litzy contributors
part of 'message.dart';

/// Immutable view of a channel persisted in the local profile.
typedef ChannelView = ({
  String id,
  String listId,
  String label,
  String protocol,
  String endpoint,
});
