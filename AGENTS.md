# Agent Working Agreement

These rules apply to every repository unless a more specific instruction takes precedence.

## Branches

- Work on a dedicated feature branch. Do not develop directly on `main`, `master`, or another protected branch.
- Use a descriptive branch name such as `feat/add-export`, `fix/session-timeout`, or `docs/update-guide`.
- Keep each branch focused on one coherent change.

## Commits

- Commit regularly when a coherent unit of work is complete. Every commit must be meaningful and independently understandable.
- Use a clear, concise, single-line commit subject. Prefer Conventional Commit prefixes where they fit, for example `feat: add CSV export`.
- Do not put an agent name, assistant name, `Co-authored-by` trailer for an agent, or other automated attribution in a commit subject or body.
- Explicitly sign every commit and include a `Signed-off-by` trailer, for example: `git commit -S -s -m "feat: add CSV export"`.
- Every three to five commits, or when a change needs context, add a short commit body explaining the why, impact, or notable trade-off. The subject remains one line.
- Do not bundle unrelated cleanup, formatting, generated files, or refactors into a feature commit.

## Changelog

- Update `CHANGELOG.md` before every commit.
- Add an entry with the commit date, human author, short hash, and a two- to three-line description of the change and its impact.
- Keep entries in reverse chronological order within the appropriate section.

## Validation Before Committing

- Identify the repository's existing CI/CD workflow and relevant test or validation command before committing.
- Make changes first, then run the focused validation once immediately before committing. Avoid repeatedly running the same broad suite during implementation unless a failure requires it.
- Run the closest available check for the change. If no focused check exists, run the project test suite, build, lint, or CI-equivalent command that is available.
- Do not commit known failures. If validation cannot run, record the reason in the commit body and changelog entry.

## Review Before Commit

- Inspect the staged diff and confirm it contains only the intended change and its changelog update.
- Confirm the commit subject is one line, the commit is signed, includes a `Signed-off-by` trailer, and has no agent attribution.