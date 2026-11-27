# Repository security

This document defines the access model of the repository and is binding for
every contributor and agent. It implements R30 and R31, which were stated
by the maintainer as permanent rules after the rebuild.

## The remote is local and starts from zero

The remote is a repository created from zero with the GitHub CLI at
`litzy-foundation/new-litzy`. The name is temporary and becomes definitive
when the maintainer renames it. It has no initial commit of its own: the
history begins with an empty root commit pushed from the local working tree,
so no earlier commit trailer can enter the rebuilt history. The previous
repository is kept as a local backup outside this tree, and no local data is
removed by the rebuild. A local bare repository at
`/home/kairosci/Projects/litzy-remote.git` remains as an offline mirror; it
is not the authoritative remote.

## Main is read-only

The `main` branch is protected. Nothing writes to it except a merge commit
that represents an accepted pull request. Direct commits, force pushes and
deletions are rejected. The first commit on `main` is the empty root that
makes the branch addressable; it contains no files and is not a content
change.

Protection is enforced in two layers. On GitHub, branch protection on
`main` requires a pull request with an approving review, blocks force pushes
and deletions, and applies to administrators as well. Locally, the
versioned `hooks/pre-receive` can be installed in a bare mirror to check a
push before any ref changes. An update to `main` is accepted only when the
new commit has exactly two parents, the first parent is the current tip of
`main`, and the subject has the form `Merge pull request #N from pr/...`.
That makes the merge history itself the evidence that every change came
through a pull request.

The hook also rejects pushes to arbitrary branches. Only `main`, branches
under `pr/` and version tags are accepted. This keeps the mirror focused on
pull requests and releases. On GitHub the equivalent discipline is that
every change arrives through a pull request and direct pushes to `main` are
rejected by branch protection.

## Pull request flow

A contributor works on a local topic branch such as `feat/s1-transport`.
When the change is ready, they push it to the remote under `pr/<number>-<slug>`.
That branch is the pull request. After review, the maintainer merges the
branch into a local `main` with a merge commit whose subject names the pull
request, then pushes `main`. The hook admits the merge and rejects any
attempt to bypass it.

An agent follows the same flow. An agent never commits on `main`, never
pushes a topic branch directly onto `main`, and never opens a remote pull
request unless the maintainer explicitly asks for it in the current
session.

## Agent authorship is rejected technically

The same hook scans every new commit for a `Co-Authored-By` trailer naming
an agent, a model, a harness or an automation account. A matching commit is
rejected before the ref moves. Human co-authors are allowed only when they
are real people with real addresses. Agents may describe their work in the
commit body, but they never claim authorship.

## Local data safety

No development step removes local data. A destructive rebuild requires a
verified local copy first. Runtime databases and user content are never
deleted to satisfy a test or to clean a working tree.

## Installing the hook

The versioned hook is the source of truth. It is installed with the
following command from the repository root after the bare remote is
created.

```bash
cp hooks/pre-receive /home/kairosci/Projects/litzy-remote.git/hooks/pre-receive
chmod +x /home/kairosci/Projects/litzy-remote.git/hooks/pre-receive
git -C /home/kairosci/Projects/litzy-remote.git config receive.denyNonFastForwards true
git -C /home/kairosci/Projects/litzy-remote.git config receive.denyDeletes false
```

The authoritative protection on GitHub is configured with the GitHub CLI
after the empty root commit has been pushed.

```bash
gh api -X PUT repos/litzy-foundation/new-litzy/branches/main/protection \
  -f required_status_checks='{"strict":true,"contexts":[]}' \
  -f enforce_admins=true \
  -f required_pull_request_reviews='{"required_approving_review_count":1,"dismiss_stale_reviews":true}' \
  -f restrictions=null \
  -f allow_force_pushes=false \
  -f allow_deletions=false
```

The second configuration line is deliberate: deletion of a pull request
branch is allowed, while non-fast-forward updates are refused as a second
layer of protection for `main`.
