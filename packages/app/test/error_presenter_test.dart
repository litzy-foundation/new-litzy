// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'package:app/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';

import 'app_test_helpers.dart';

void main() {
  late AppMessages messages;
  late ErrorPresenter presenter;

  setUp(() {
    messages = testBundle().messages;
    presenter = ErrorPresenter(messages);
  });

  test('every engine code selects its own localized sentence', () {
    expect(
      presenter.present(const ReadingFailure(AppRequestKeys.profileNotOpen)),
      messages.errorProfileNotOpen,
    );
    expect(
      presenter.present(const ReadingFailure(AppRequestKeys.profileOpenFailed)),
      messages.errorProfileOpenFailed,
    );
    expect(
      presenter.present(const ReadingFailure(AppRequestKeys.channelListFailed)),
      messages.errorChannelListFailed,
    );
    expect(
      presenter.present(const ReadingFailure(AppRequestKeys.threadListFailed)),
      messages.errorThreadListFailed,
    );
    expect(
      presenter.present(const ReadingFailure(AppRequestKeys.threadFailed)),
      messages.errorThreadFailed,
    );
    expect(
      presenter.present(const ReadingFailure(AppRequestKeys.transportTimeout)),
      messages.errorTransportTimeout,
    );
    expect(
      presenter.present(const ReadingFailure(AppRequestKeys.transportClosed)),
      messages.errorTransportClosed,
    );
    expect(
      presenter.present(const ReadingFailure(AppRequestKeys.unexpectedFailure)),
      messages.errorUnexpectedFailure,
    );
  });

  test('an unknown code selects the generic localized sentence', () {
    expect(
      presenter.present(const ReadingFailure('unmapped_failure')),
      messages.errorUnknown,
    );
  });
}
