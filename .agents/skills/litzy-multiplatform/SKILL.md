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

Platform-specific code belongs in packaging and in small native ports such
as keychain access. Business rules stay in the engine and are reached
through the typed protocol. iOS builds are manual on the maintainer's Apple
machine, Android builds locally and Windows MSIX on a free hosted runner.
Before a release, acceptance tests run the real engine on at least one
desktop target.
