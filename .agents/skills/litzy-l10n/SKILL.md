---
name: litzy-l10n
description: REQUIRED for user-visible text, Fluent resource files or changes to the l10n package. Implements R11 for the interface.
---

# Litzy localisation

All user-visible strings live in the `l10n` package as Fluent resources.
No interface text is hard-coded in the GUI or the CLI, including command
output, error messages, labels and keyboard hints. A new string is added to
the resource file before it is used, and a missing key is a build or runtime
error rather than a raw identifier shown to the user. If the `l10n` package is
absent from a slice, create it with the first string or leave the string out
of the slice.

Messages are complete English sentences with placeholders named for their
meaning. Do not put markup, protocol names or implementation details into a
user-facing message. Keep the same vocabulary across the GUI and the CLI so
that both front-ends feel like one application. Source comments and resource
comments are English as required by R11.

The `l10n` package owns the Fluent parser and typed message keys. Versioned
resources live under `data/l10n` and are declared as Flutter assets by the
client, so the resource file is the source of truth on every platform. Widgets
call a typed key and never construct a sentence from fragments. A missing key
raises a typed error instead of showing the key to a user.
