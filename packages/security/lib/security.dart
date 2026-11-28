// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// The in-app credential flow for Litzy front-ends.
///
/// R37 requires credentials to be acquired inside the application, and R35
/// requires the operating system keychain to hold them. This package provides
/// the ports and the vault that connects them; platform adapters belong in
/// packaging code and fakes belong in tests.
library;

export 'src/credential_vault.dart';
export 'src/oauth_provider.dart';
export 'src/secret_store.dart';
