# Fixtures

Named test fixtures live here, as required by ADR-0004. Message fixtures
use descriptive names such as `lkml-thread` or `git-series`. A fixture is
pure data and never contains a credential. Tests load a fixture through a
helper instead of embedding raw message text in Dart source.

Local fixtures that must not be versioned belong in the git-ignored
`data/local` directory. Fixture servers used for NNTP, IMAP and
public-inbox acceptance tests are code in the test tree, not data in this
directory.
