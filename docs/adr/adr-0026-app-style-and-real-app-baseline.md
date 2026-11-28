# ADR-0026: App style and real-app baseline

## Status

Accepted on 2026-11-28. This decision implements R54 and refines R13, R46 and
R49 without changing their requirements.

## Context

The maintainer stated: "definsci lo stile stesso dell'app definisci il
necessario per renderla un app vera e propria" and "non saprei, vedi tu il modo
migliore". ADR-0020 defines the reading model, and ADR-0022 fixes the package
boundary, but neither defines the visual identity of Litzy. The first client
has channels, topics and a read-only conversation, yet a user cannot treat it
as a complete application: there is no account setup, no settings surface, no
onboarding state and no declared style beyond two colours in a small theme
file.

A style defined in widgets would drift between the five targets and would
contradict R47, which requires keys instead of literal values and declarative
data under `data/`. A real application also needs more than a screen: it needs
identity, lifecycle states, an account path and deterministic handling of
offline and failure conditions. Those needs must be stated once so that work
is not repeated in every slice, as the maintainer asked with "conferme a non
finire poi" in R46.

## Decision

The visual style is named Quiet Workshop. It is a restrained, text-first
style for technical correspondence: neutral surfaces, high contrast for
reading, one accent reserved for unread and activity state, monospace type
only for patches and quoted raw mail, and motion limited to short state
changes. Colour, spacing, type, radius, elevation, density and motion are
roles in the existing `data/ui/theme.yaml`, which becomes the single token
file. The two current colour tokens move into that file with the other roles
so one fact has one home. Widgets reference token keys and Fluent message
keys; they do not contain literal colours, sizes, durations or interface
text.

The style is adaptive by construction. Desktop shows the three reading panes
of R46 and resizes them around a declared minimum. Mobile shows one pane with
a localized back action. Touch targets, text scaling, semantics labels,
focus order, contrast and reduced motion are part of the token contract, not
an optional polish pass. Platform work stays in packaging and in small native
ports such as keychain access, as required by R1.

The baseline for a real application is defined as follows. The client has an
identity with a name, an icon and a version on every target. It offers an
account setup path that takes only an email address and follows ADR-0025, a
settings surface for the local profile, language, density and per-list
mailbox policy, and onboarding and empty states written in Fluent resources.
It shows sync status and allows retry, keeps cached mail readable offline,
and never performs a destructive mailbox action while offline. Search, triage
and thread navigation are available from the interface, not only from the
CLI. The composer and outbound sending remain the separate S8 slice, and
import and export remain S12, so neither is claimed as present before it is
implemented. Credentials can be added, rotated and forgotten through the
platform keychain, and profile data has an explicit export path with no
automatic deletion. No telemetry is collected.

Each item in that baseline is tracked in the roadmap with its own slice and
problem entry. A compiled binary is exercised by the agent before a target is
called covered, as required by R50, and a target that cannot be exercised on
the available host is reported as unverified.

## Consequences

One token file gives every platform the same style, and a visual change is a
data edit reviewed once rather than a search through widgets. The interface
can grow without a new confirmation cycle because the layout, the tokens and
the baseline are already decided. Accessibility and localization are part of
the first implementation of each screen, which avoids a later rewrite.

The baseline is deliberately larger than the current read-only slice. Until
the account setup, settings and composer slices land, documentation describes
them as planned rather than present, so the discoverability text of R49 stays
truthful. Moving the existing theme colours into a single token file changes
the app asset loader and needs a targeted test. The macOS, Windows, Android
and iOS representations of the style remain unverified on this machine and
are reported as such rather than assumed.
