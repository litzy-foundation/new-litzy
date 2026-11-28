// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// Request identifiers and error codes used by the Flutter client.
final class AppRequestKeys {
  const AppRequestKeys._();

  /// Identifier of the profile open request.
  static const String openProfile = 'app.open-profile';

  /// Machine-readable marker written after the first load completes.
  static const String ready = 'app.ready';

  /// Key of a loaded channel identifier in acceptance output.
  static const String channel = 'app.channel';

  /// Key of the loaded topic count in acceptance output.
  static const String topics = 'app.topics';

  /// Key of the startup error in acceptance output.
  static const String failure = 'app.failure';

  /// Prefix of channel list requests.
  static const String listChannels = 'app.list-channels';

  /// Prefix of topic list requests.
  static const String listThreads = 'app.list-threads';

  /// Prefix of conversation requests.
  static const String showThread = 'app.show-thread';

  /// Code used when the engine returns an unexpected response type.
  static const String unexpectedResponse = 'unexpected_response';

  /// Code used when the local profile cannot be opened at startup.
  static const String profileOpenFailed = 'profile_open_failed';

  /// Code used when a request does not receive an answer in time.
  static const String transportTimeout = 'transport_timeout';

  /// Code used when the local engine transport closes during a request.
  static const String transportClosed = 'transport_closed';

  /// Code used when an exception has no more specific reading code.
  static const String unexpectedFailure = 'unexpected_failure';

  /// Code returned when no local profile is open.
  static const String profileNotOpen = 'profile_not_open';

  /// Code returned when the channel list cannot be read.
  static const String channelListFailed = 'channel_list_failed';

  /// Code returned when the topic list cannot be read.
  static const String threadListFailed = 'thread_list_failed';

  /// Code returned when a conversation cannot be read.
  static const String threadFailed = 'thread_failed';
}
