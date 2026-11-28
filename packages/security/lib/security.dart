// Copyright (c) 2026 Alessio Attilio and the litzy contributors
/// The in-app credential flow for Litzy front-ends.
///
/// R37 requires credentials to be acquired inside the application, and R35
/// requires the operating system keychain to hold them. This package provides
/// the ports, the vault that connects them and the Linux libsecret adapter.
/// Mobile and desktop Flutter adapters belong in the client package, and fakes
/// belong in tests.
library;

export 'src/credential_vault.dart';
export 'src/libsecret_store.dart';
export 'src/oauth_provider.dart';
export 'src/secret_store.dart';
