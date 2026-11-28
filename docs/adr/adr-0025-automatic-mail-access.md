# ADR-0025: Automatic mail access for every provider

## Status

Accepted on 2026-11-28. This decision implements R53 and sharpens R10, R35,
R37 and R39. It supersedes the manual endpoint entry implied by ADR-0015,
which remains valid for the transport itself.

## Context

The maintainer stated: "assicurati di non fare minchiate nel passaggio critico :
l'accesso ; ricordo che devo poter accedere con tutti i provider mail ; io metto
l'email e l'app configura automaticamente tutto" and "no credenziali in chiaro,
no problemi di ogni tipo , no vulnerabilità eligibili". Access is the critical
step: a mistake there can expose a mailbox or send a credential to an attacker.

The current Mode B verb requires the caller to supply a host, a port, a list
identifier and a password. That works in a test but does not meet the stated
user experience. ADR-0007 owns secret storage, ADR-0015 owns the IMAP transport,
and ADR-0008 keeps list mail out of the personal mailbox. Discovery must fit
between those decisions without adding a provider table, because R10 forbids
provider special cases.

Unauthenticated DNS and hosted autoconfiguration documents are hostile inputs.
A naive implementation can be tricked into connecting to an attacker host,
following a redirect to plaintext, expanding external XML entities, reading an
unbounded response or injecting control characters into a command. Each of
those is an avoidable vulnerability and is therefore inside the scope of this
decision.

## Decision

The engine owns an account setup flow behind typed verbs. A discovery request
takes only an email address and returns non-secret endpoint settings with the
source and trust level of each endpoint. A connection request takes the same
address plus a credential supplied by the front-end, verifies the IMAP login
without changing any mailbox, and persists the non-secret settings in the
local SQLite profile. The front-end stores the credential in the operating
system keychain through `CredentialVault` before or after that verification,
never inside the engine isolate: a platform keychain adapter holds native
resources that an isolate cannot receive, so placing the vault in the engine
would either fail to send or force an unsafe process bridge. No credential
crosses the process boundary except through the in-process typed bus in
memory, and the credential value overrides string conversion so a logger
cannot print it.

Discovery is ordered by trust and has no provider exceptions. The domain after
the at sign is the only input used to build candidates. First the client reads
the HTTPS well-known autoconfiguration document at the provider domain, then
the HTTPS autoconfig subdomain document. Next it reads DNS SRV records for
implicit TLS submission and implicit TLS IMAP, and then the HTTPS Microsoft
Autodiscover document at the autodiscover subdomain or its SRV target. As a
last resort it derives the conventional hosts from the domain and reports them
as unverified rather than discovered.

A candidate is accepted only when it passes the policy in the declarative
file under `data/access`. The policy holds timeouts, response size limits,
allowed ports and the redirect budget, not provider names. A host outside the
email domain is accepted only when an authenticated HTTPS document names it.
Every remote connection requires TLS with ordinary certificate validation;
STARTTLS is mandatory when a candidate offers no implicit TLS port and fails
closed when the server does not offer it. Redirects are limited to same-origin
HTTPS hops; a scheme downgrade or a cross-origin redirect is a typed failure.
The HTTP client stops reading after the configured byte limit, and the XML
parser rejects document type declarations and external entities before it
builds a document. The email address, every host and every credential are
checked for control characters by the named validation function introduced
for R52.

Credentials come from a secure front-end flow. A GUI form collects the password
with obscured entry, and the CLI reads it from a terminal with echo disabled;
when standard input is a pipe no echo can occur, so the prompt reads the pipe
without changing terminal modes. The CLI writes its prompt to standard error so
standard output stays machine-readable. Both front-ends place the value in a
`CredentialVault` backed by a platform `SecretStore`, send it to the engine as
an in-memory typed value and keep it in the operating system keychain. The
secret is written after discovery and removed if login verification fails, so
a rejected account leaves no stored credential. There is no command-line flag,
environment variable, versioned file, fixture or log line that can carry a
password. ADR-0015's waiting CLI command is thereby satisfied on Linux through
libsecret and on every target with a Flutter plugin adapter in the GUI.

OAuth remains a separate slice under R55. A standards-based OAuth client needs
a registered client identifier, and deriving one per provider would create the
provider table that R10 forbids. The vault keeps its OAuth port, but this slice
does not claim to connect a provider that accepts only OAuth; P24 records that
limitation.

Failures are deterministic typed codes such as `invalid_email`,
`discovery_failed`, `untrusted_endpoint`, `insecure_transport`,
`unsupported_auth` and `keychain_unavailable`, and the front-ends select
localized messages by code. The design leaves room for manual entry of a host
and port when discovery cannot establish a trustworthy endpoint, but that
surface is not part of this slice. When it lands, those values will be
non-secret settings stored in SQLite under the same TLS and validation rules.

## Consequences

A user supplies an email address and one secure credential action instead of
knowing provider settings. New providers work without a code change because
the flow follows published standards rather than a maintained list. An
attacker who controls DNS, a web host or a redirect cannot downgrade the
transport, inject control characters, force an unbounded read or make the
client send a credential to a host outside the authenticated configuration.
Every discovered endpoint records its trust source so the interface can
distinguish a verified document from a derived guess.

Discovery can still fail for a provider that publishes none of the standard
records. That case produces a typed error rather than a silent guess, and manual
endpoint entry remains a later surface. Providers that accept a password need
no branch, because discovery derives their endpoints and the same secure form
or prompt supplies the credential. The shipped policy disables loopback
plaintext fixtures, and only an acceptance harness overrides it with a fixture
policy through a path environment variable. The HTTPS and DNS ports live in the
engine and are faked in tests, so no test needs a real provider or a real
secret. Both compiled clients are exercised against a local profile under R50,
and the CLI acceptance uses a temporary libsecret attribute set that is removed
afterwards. A provider that
accepts only OAuth cannot be connected in this slice, as recorded in P24 and
S15b, and no provider table is introduced to work around it.
