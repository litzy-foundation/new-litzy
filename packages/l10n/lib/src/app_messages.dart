// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'fluent_catalog.dart';

/// Typed names for every sentence shown by the read-only Litzy client.
///
/// A widget calls one member of this class and never builds a sentence from
/// fragments. The resource file remains the only place that contains text.
final class AppMessages {
  /// Creates a typed view over [catalog].
  const AppMessages(this._catalog);

  static const String _appTitle = 'app-title';
  static const String _channelsTitle = 'channels-title';
  static const String _topicsTitle = 'topics-title';
  static const String _conversationTitle = 'conversation-title';
  static const String _ownThreads = 'own-threads';
  static const String _unreadMail = 'unread-mail';
  static const String _awaitingReply = 'awaiting-reply';
  static const String _allTopics = 'all-topics';
  static const String _noChannels = 'no-channels';
  static const String _noTopics = 'no-topics';
  static const String _noConversation = 'no-conversation';
  static const String _patchBadge = 'patch-badge';
  static const String _topicCount = 'topic-count';
  static const String _quotedContext = 'quoted-context';
  static const String _diffSummary = 'diff-summary';
  static const String _composerPreview = 'composer-preview';
  static const String _none = 'none';
  static const String _backAction = 'back-action';
  static const String _loading = 'loading';
  static const String _errorProfileNotOpen = 'error-profile-not-open';
  static const String _errorProfileOpenFailed = 'error-profile-open-failed';
  static const String _errorChannelListFailed = 'error-channel-list-failed';
  static const String _errorThreadListFailed = 'error-thread-list-failed';
  static const String _errorThreadFailed = 'error-thread-failed';
  static const String _errorTransportTimeout = 'error-transport-timeout';
  static const String _errorTransportClosed = 'error-transport-closed';
  static const String _errorUnexpectedFailure = 'error-unexpected-failure';
  static const String _errorUnknown = 'error-unknown';
  static const String _emptyView = 'empty-view';

  final FluentCatalog _catalog;

  /// Title of the application window.
  String get appTitle => _catalog.message(_appTitle);

  /// Heading of the channel pane.
  String get channelsTitle => _catalog.message(_channelsTitle);

  /// Heading of the topic pane.
  String get topicsTitle => _catalog.message(_topicsTitle);

  /// Heading of the conversation pane.
  String get conversationTitle => _catalog.message(_conversationTitle);

  /// Label of the cross-channel view for threads started by the user.
  String get ownThreads => _catalog.message(_ownThreads);

  /// Label of the cross-channel view for unread messages.
  String get unreadMail => _catalog.message(_unreadMail);

  /// Label of the cross-channel view for threads awaiting a reply.
  String get awaitingReply => _catalog.message(_awaitingReply);

  /// Label of the view that contains topics from every channel.
  String get allTopics => _catalog.message(_allTopics);

  /// Message shown when the profile contains no channels.
  String get noChannels => _catalog.message(_noChannels);

  /// Message shown when the selected view contains no topics.
  String get noTopics => _catalog.message(_noTopics);

  /// Message shown before a topic is selected.
  String get noConversation => _catalog.message(_noConversation);

  /// Badge shown on a topic that carries a patch.
  String get patchBadge => _catalog.message(_patchBadge);

  /// Description of the number of messages in one topic.
  String topicCount(int count) =>
      _catalog.message(_topicCount, {'count': count});

  /// Title of a folded block of quoted text.
  String quotedContext(int level) =>
      _catalog.message(_quotedContext, {'level': level});

  /// Summary shown above a rendered patch.
  String diffSummary(int count) =>
      _catalog.message(_diffSummary, {'count': count});

  /// Read-only preview of the recipients of a future reply.
  String composerPreview(String to, String cc) =>
      _catalog.message(_composerPreview, {'to': to, 'cc': cc});

  /// Word shown when a recipient list is empty.
  String get none => _catalog.message(_none);

  /// Label of the mobile action that returns to the previous pane.
  String get backAction => _catalog.message(_backAction);

  /// Message shown while the profile is loading.
  String get loading => _catalog.message(_loading);

  /// Message for an open profile failure.
  String get errorProfileNotOpen => _catalog.message(_errorProfileNotOpen);

  /// Message for a profile that could not be opened at startup.
  String get errorProfileOpenFailed =>
      _catalog.message(_errorProfileOpenFailed);

  /// Message for a channel read failure.
  String get errorChannelListFailed =>
      _catalog.message(_errorChannelListFailed);

  /// Message for a topic read failure.
  String get errorThreadListFailed => _catalog.message(_errorThreadListFailed);

  /// Message for a conversation read failure.
  String get errorThreadFailed => _catalog.message(_errorThreadFailed);

  /// Message for a request that exceeded its deadline.
  String get errorTransportTimeout => _catalog.message(_errorTransportTimeout);

  /// Message for an engine that closed during a request.
  String get errorTransportClosed => _catalog.message(_errorTransportClosed);

  /// Message for an exception without a more specific cause.
  String get errorUnexpectedFailure =>
      _catalog.message(_errorUnexpectedFailure);

  /// Message for an unexpected engine failure.
  String get errorUnknown => _catalog.message(_errorUnknown);

  /// Message shown when a cross-channel view has no matching topics.
  String get emptyView => _catalog.message(_emptyView);
}
