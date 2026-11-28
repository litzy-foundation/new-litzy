---
name: litzy-multiplatform
description: REQUIRED for user interface or packaging work across the five Litzy targets. Implements R1 and the decisions in multiplatform.md.
---

# Litzy multiplatform

Every client feature is designed for Linux, macOS, Windows, Android and iOS
from one codebase. The interface is adaptive: master-detail on desktop and
a navigation stack on mobile. No platform is secondary, and a reduced
feature set is acceptable only when the operating system forbids the
operation. The web is out of scope until the maintainer decides otherwise.

The Quiet Workshop style is defined by tokens in `data/ui/theme.yaml`. Widgets
use token keys, Fluent text keys and a single adaptive layout resolver; they
never carry literal colours, sizes or durations. Semantics, focus order, text
scaling, contrast and reduced motion belong in each screen from the start.
A real client also needs identity, account setup, settings, onboarding, empty
states, sync status and offline behaviour, as recorded in ADR-0026.

Platform-specific code belongs in packaging and in small native ports such
as keychain access. Business rules stay in the engine and are reached
through the typed protocol. iOS builds are manual on the maintainer's Apple
machine, Android builds locally and Windows MSIX on a free hosted runner.
Before a release, acceptance tests run the real engine on at least one
desktop target. When a binary is built for a target, the agent launches that
binary in acceptance on the available host. Targets the agent cannot exercise
are recorded as unverified rather than covered, as required by R50.
