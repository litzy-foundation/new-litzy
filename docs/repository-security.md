# Repository security

This document defines the access model of the repository and is binding for
every contributor and agent. It implements R30, R31 and R38, which were
stated by the maintainer as permanent rules after the rebuild.

## The remote is local and starts from zero

The authoritative remote is a repository created from zero with the GitHub
CLI at `litzy-foundation/new-litzy`. The name is temporary and becomes
definitive when the maintainer renames it. It has no initial commit of its
own: the history begins with an empty root commit pushed from the local
working tree, so no earlier commit trailer can enter the rebuilt history.
The previous repository is kept as a local backup outside this tree, and no
local data is removed by the rebuild. A local bare repository at
`/home/kairosci/Projects/litzy-remote.git` remains as an offline mirror; it
is not the authoritative remote and has no server-side policy.

## Main is read-only

The `main` branch is protected on GitHub. Nothing writes to it except a
merge commit that represents an accepted pull request. Direct commits, force
pushes and deletions are rejected, including for administrators. The first
commit on `main` is the empty root that makes the branch addressable; it
contains no files and is not a content change.

Branch protection requires a pull request before merging and requires the
`pr-guard` status check to succeed. The required check comes from a GitHub
Actions workflow under `.github/workflows` and runs on every pull request.
It verifies that the base is `main`, that the head branch is named
`pr/<number>-<slug>` with the pull request number, that the branch has
exactly one commit, that the subject follows Conventional Commits, and that
no `Co-Authored-By` trailer names an agent, a model, a harness or an
automation account. A pull request that fails any of these conditions cannot
be merged.

The local bare mirror accepts any push and enforces nothing. No pre-receive
hook is versioned or installed, because the public GitHub remote cannot use
one and a rule that applies only to a mirror would be misleading, as decided
in R38 and ADR-0014. The merge history itself is the evidence that every
change came through a pull request: each new commit on `main` has two
parents, the first parent is the previous tip, and the subject names the
pull request.

## Pull request flow

A contributor works on a local topic branch such as `feat/s4-purge`. When
the change is ready, they push it to the remote under `pr/<number>-<slug>`
and open a pull request. After review the maintainer merges it into `main`
with a merge commit whose subject names the pull request. The required check
has already verified the shape of the branch and its single commit.

An agent follows the same flow. An agent never commits on `main`, never
pushes a topic branch directly onto `main`, and never opens a remote pull
request unless the maintainer explicitly asks for that action in the current
session. When an agent opens a pull request, it writes the brief body
described in R36 and adds no agent co-author.

## Agent authorship is rejected technically

The `pr-guard` check scans the single commit of every pull request for a
`Co-Authored-By` trailer naming an agent, a model, a harness or an automation
account. A matching commit fails the check and cannot be merged. Human
co-authors are allowed only when they are real people with real addresses.
Agents may describe their work in the commit body, but they never claim
authorship.

## Local data safety

No development step removes local data. A destructive rebuild requires a
verified local copy first. Runtime databases and user content are never
deleted to satisfy a test or to clean a working tree.

## Configuring the GitHub checks

The workflow is part of the versioned tree, so it reaches GitHub through the
same pull request flow as any other file. Branch protection is configured
with the GitHub CLI after the empty root commit has been pushed and the
workflow has landed. Use a JSON file with `gh api --input`, because the
nested objects are rejected when passed as separate form fields.

```bash
cat > /tmp/litzy-protection.json <<'JSON'
{
  "required_status_checks": {"strict": true, "contexts": ["pr-guard"]},
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
JSON
gh api -X PUT repos/litzy-foundation/new-litzy/branches/main/protection \
  --input /tmp/litzy-protection.json
```

No approving review is required. Review is still performed by the
maintainer, as recorded in R31; the technical gate is the pull request and
the required check. Deletion of a pull request branch is allowed, while
force pushes are refused as a second layer of protection for `main`.
