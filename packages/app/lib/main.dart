// Copyright (c) 2026 Alessio Attilio and the litzy contributors
import 'dart:io';

import 'package:engine/engine.dart';
import 'package:flutter/widgets.dart';
import 'package:protocol/protocol.dart';
import 'package:security/security.dart';

import 'app.dart';

/// Starts the Flutter client with a real in-process engine.
Future<void> main() async {
  late final AppBundle bundle;
  late final LmlpEngine engine;
  var engineStarted = false;
  final environment = Platform.environment;
  final reporter = AcceptanceReporter(
    environment[AppEnvironmentKeys.acceptance] == AppEnvironmentKeys.enabled,
  );
  try {
    WidgetsFlutterBinding.ensureInitialized();
    bundle = await AppBundle.load();
    final profilePath =
        environment[AppEnvironmentKeys.profilePath] ??
        await resolveProfilePath(bundle.profile.databasePath);
    final started = await EngineClient.start();
    engine = started;
    engineStarted = true;
    final opened = await started.send(
      OpenProfileRequest(AppRequestKeys.openProfile, profilePath),
    );
    if (opened is ErrorResponse) throw ReadingFailure(opened.code);
    if (opened is! AckResponse) {
      throw const ReadingFailure(AppRequestKeys.unexpectedResponse);
    }
    const vault = CredentialVault(
      store: FlutterSecureStorageStore(),
      providers: [],
    );
    runApp(
      LitzyApp(
        engine: engine,
        source: EngineReadingSource(engine),
        accountSource: EngineAccountSource(engine),
        vault: vault,
        bundle: bundle,
        onLoaded: reporter.report,
        onSetupRequired: reporter.reportSetupRequired,
      ),
    );
  } on Object catch (error) {
    reporter.reportFailure(error);
    if (engineStarted) await engine.close();
    throw mapReadingFailure(error);
  }
}
