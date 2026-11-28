// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Selection in the channel pane of the reading interface.
enum ReadingView {
  /// Topics from every persisted channel.
  all,

  /// Topics started by the user.
  own,

  /// Messages that are still unread.
  unread,

  /// Threads that await a reply.
  awaitingReply,

  /// Topics from one named channel.
  channel,
}
