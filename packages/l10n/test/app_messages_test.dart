// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:l10n/l10n.dart';
import 'package:test/test.dart';

import 'l10n_paths.dart';

void main() {
  late AppMessages messages;

  setUp(() {
    messages = AppMessages(
      FluentCatalog.parse(resourceText('data/l10n/en.ftl')),
    );
  });

  test('every typed message resolves from the versioned resource', () {
    final rendered = <String>[
      messages.appTitle,
      messages.channelsTitle,
      messages.topicsTitle,
      messages.conversationTitle,
      messages.ownThreads,
      messages.unreadMail,
      messages.awaitingReply,
      messages.allTopics,
      messages.noChannels,
      messages.noTopics,
      messages.noConversation,
      messages.patchBadge,
      messages.topicCount(2),
      messages.quotedContext(3),
      messages.diffSummary(4),
      messages.composerPreview('list', messages.none),
      messages.backAction,
      messages.loading,
      messages.errorProfileNotOpen,
      messages.errorProfileOpenFailed,
      messages.errorChannelListFailed,
      messages.errorThreadListFailed,
      messages.errorThreadFailed,
      messages.errorTransportTimeout,
      messages.errorTransportClosed,
      messages.errorUnexpectedFailure,
      messages.errorUnknown,
      messages.emptyView,
      messages.passwordPrompt('user@example.com'),
      messages.passwordRequired,
      messages.accountUnsupportedAuth,
      messages.setupTitle,
      messages.setupDescription,
      messages.setupEmailLabel,
      messages.setupPasswordLabel,
      messages.setupConnectAction,
      messages.setupSkipAction,
      messages.setupDiscovering,
      messages.setupConnecting,
      messages.setupConnected,
      messages.setupInvalidAddress,
      messages.setupError,
      messages.setupEndpoints('imap.example.com', 'smtp.example.com'),
      messages.setupClearAction,
    ];

    expect(rendered, everyElement(isNotEmpty));
  });

  test('placeholders render named values', () {
    expect(messages.topicCount(7), contains('7'));
    expect(
      messages.composerPreview('git list', messages.none),
      contains('git list'),
    );
  });

  test('topic counts describe every message in the conversation', () {
    expect(messages.topicCount(2), 'This topic contains 2 messages.');
  });

  test('an absent key raises a typed error', () {
    final catalog = FluentCatalog.parse('');

    expect(
      () => catalog.message('missing-key'),
      throwsA(isA<MissingMessageException>()),
    );
  });

  test('an absent placeholder raises a typed error', () {
    final catalog = FluentCatalog.parse('greeting = Hello { \$name }.');

    expect(
      () => catalog.message('greeting'),
      throwsA(isA<MissingPlaceholderException>()),
    );
  });

  test('a duplicate key is rejected during parsing', () {
    final lineFeed = String.fromCharCode(10);
    final source = ['same = First', 'same = Second'].join(lineFeed);

    expect(
      () => FluentCatalog.parse(source),
      throwsA(isA<FluentParseException>()),
    );
  });
}
