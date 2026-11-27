# ADR-0007: Secrets in the operating system keychain

## Status

Accepted on 2026-11-28. This decision implements R18 and R35 and replaces
the earlier M5 plan of mTLS and tokens between front-end and engine.

## Context

The earlier security plan protected a network boundary between the client
and the engine. That boundary no longer exists, because the engine runs in
a separate isolate of the same process. The real secret material is the
user's IMAP and SMTP password, which rests on the user's disk. The
maintainer chose operating system keychain storage for that material.

## Decision

Credentials are kept with `flutter_secure_storage` on mobile and with
libsecret or the native equivalent on desktop. Environment variables remain
the source for local configuration and continuous integration, and the
git-ignored `.env` file may supply them during development. No token and no
mutual TLS certificate is used between the GUI or CLI and the engine. The
database remains encrypted at rest, and secrets are never written to logs,
fixtures or versioned files.

## Consequences

Password material is protected by the platform instead of by application
code, and the removal of the network hop reduces the attack surface. The
engine needs a small platform port for keychain access, which must be
faked in tests and implemented per platform. Credentials entered through
the environment are never persisted by the application unless the user
explicitly asks for that.
