# ADR-0022: Read-only adaptive GUI packages

## Status

Accepted on 2026-11-28. This decision implements R1, R13, R45, R46 and R47
and refines ADR-0020.

## Context

The engine already answers typed requests for channels, topic summaries and
one reconstructed thread, but no Flutter client exists. The maintainer asked
to read `git@vger.kernel.org` in both the CLI and the GUI with tests that need
no credentials. The GUI must use the same in-process engine rather than a
second reading path. It must adapt to desktop and mobile, keep all
user-visible text in Fluent resources and keep declarative values out of Dart
source.

A Flutter package cannot consume the existing CLI binary without inventing a
local protocol, which R40 forbids. The client therefore needs direct access
to the typed engine contract and to the real `EngineClient` implementation.
The GUI also needs a small presentation layer so widgets never construct
protocol messages or interpret engine failures.

## Decision

Two packages are added to the workspace. The `l10n` package parses Fluent
resources and exposes typed message keys with placeholders. The `app` package
contains the Flutter client, depends on `protocol` and `engine`, and reaches
data through a `ReadingSource` port. `EngineReadingSource` implements that
port with typed requests; widget tests replace it with a fake. The production
entry point starts `EngineClient`, opens the local profile and passes that
engine into the application widget.

The application has three panes. Desktop lays out channels, topics and the
conversation side by side. Mobile shows one pane at a time and exposes a
localized back action. The layout breakpoint, theme tokens and subject markers
live in YAML under `data/`. The app declares those files as Flutter assets so
the source of truth stays declarative on every target. No width, colour, font
or patch marker is written as a value in Dart.

Topic rows come from `ThreadSummary`, and the conversation comes from
`ShowThreadRequest`. The `QuoteAndDiffAnalyzer` in `core` splits each message
body into prose, quoted context and diffs. Quote blocks fold by default and
diff blocks render with the monospace font and colour declared in YAML. Patch
prefixes are declarative as well, so the badge recognizes `[PATCH v2 1/3]` and
other numbered series. Topic rows describe the total message count reported by
the engine, which includes the conversation root. The cross-channel views are
visible in the sidebar, but topic summaries do not yet carry the flags needed
to filter them; they show an honest localized empty state until the triage
slice exposes those flags. The composer is represented only by a localized To
and Cc preview; no send action is wired until the outbound slice.

The declarative profile file supplies a database file name, not an absolute
path. The client resolves that name inside the platform application support
directory through `path_provider`, so the same code has a writable profile on
every supported desktop and mobile target. Request timeouts, closed transports
and untyped exceptions are converted to typed reading failures and localized
before they reach a widget. The whole startup sequence, including asset loading
and engine start, stays inside the same typed boundary. The literal-text test
scans widget constructors and label properties; internal exception messages are
not interface text.

Flutter 3.50.1 is pinned through mise, and the workspace SDK floor is lowered
to Dart 3.14.0 because that is the SDK bundled by the newest available Flutter
release. The Dart-only toolchain stays pinned to 3.14.1, which satisfies the
same constraint. The `test` dependency stays below 1.33.0 because Flutter
3.50.1 pins `test_api` 0.7.14. The Flutter assets point at the versioned files
under `data/`, so the client does not duplicate their contents. Flutter copies
out-of-package assets into `packages/app/data` while building, and that
generated directory is ignored.

Flutter 3.50 moves Material widgets out of the SDK into the `material_ui`
package, so the client depends on that package explicitly. The application uses
a theme without animated ink because the shader asset is not available in
headless widget tests. Melos analysis is split into a Dart step and a Flutter
step because the Dart analyzer cannot resolve a package that depends on the
Flutter SDK. The engine-backed widget test places isolate calls inside
`tester.runAsync`, which lets real isolate messages arrive while the widget
test binding is active.

## Consequences

The GUI and CLI now share the same verbs and the same profile, so a thread
read in one client is available in the other. Widget tests can exercise
navigation and rendering without a display, while an engine-backed test drives
the real isolate and SQLite database with local fixtures. Packaging still has
to place the Flutter assets beside the installed client on mobile and desktop;
no platform package or compiled GUI binary is built in this slice, so packaged
acceptance on a desktop target remains open. Localized error messages are
selected by engine error code, so an engine string is never shown directly.
The absence of a send action is deliberate and is recorded in the roadmap
rather than represented by an inert control.
