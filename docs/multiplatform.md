# Multiplatform

Litzy targets every desktop and mobile platform from one Flutter codebase,
as required by R1. The interface is adaptive: a master-detail layout with
three columns on desktop and a single stack with navigation on mobile. The
engine and the protocol are shared, so platform work is confined to
packaging and to small native plugins such as keychain access.

| Target | Packaging format | Notes |
| :--- | :--- | :--- |
| Linux | AppImage, Flatpak | First desktop target |
| macOS | DMG | Needs macOS tooling for signing |
| Windows | MSIX | Built on a hosted Windows runner |
| Android | APK | Built locally |
| iOS | IPA | Manual build on the maintainer's Apple machine |

The web is out of scope until the maintainer decides otherwise, as recorded
in Q1 of `requirements.md`. iOS builds stay manual because the project does
not pay for a macOS runner; a hosted Windows runner is free and can build
the MSIX package.

Platform-specific code is limited to the keychain port required by ADR-0007
and to the embedding of the engine isolate. No business rule is duplicated
per platform, and no platform receives a reduced feature set except where
the operating system forbids an operation. Acceptance tests run the real
engine on at least one desktop target before a release is published.
