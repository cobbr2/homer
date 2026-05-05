# Plan: Personal GitHub repos — master / feature-branch organization

## Goal

Make **personal repositories** predictable for day-to-day work: a clear **`master`** (or aligned default branch) as integration, **feature branches** for work in progress, and a **consistent PR path** onto the canonical remote so merges are reviewable and repeatable. Align with Homer’s workflow expectations: **`origin`** on the canonical namespace (here: **`cobbr2/<repo>`**), **PRs targeting `master`**, secondary remotes (e.g. forks) **not** used as the merge target.

## Current principles (reference)

- Base branch for merge: **`master`** on **`origin`** (canonical).
- Use **PR discipline** when branch protection or team habit requires it; merge via normal Git/GitHub flow when ready.

## Scope

**In scope**

- Naming and default branch conventions across personal repos that should follow `master` + feature branches + PR to `master`.
- Remote layout: **`origin`** = canonical; other remotes optional and non-primary for merges.
- Light consistency (branch naming hints, documenting “how I work” per repo where it differs).

**Out of scope (for later)**

- Organization-wide automation (bulk GitHub API scripts) unless we add a follow-up plan.
- Repos that intentionally use `main` or another default; those get an explicit exception note rather than forced migration.

## Work items

1. **Inventory**  
   List active personal repos (GitHub + local clones). For each, record: default branch on GitHub, local `origin` URL, whether `master` exists and matches integration reality.

2. **Align default branch**  
   For repos in this workflow, set GitHub **default branch** to **`master`** if it is not already (or document why another default is kept).

3. **Align remotes**  
   Ensure **`origin`** points at the canonical repo (`cobbr2/...`). Fold or rename secondary remotes so there is no accidental PR/merge against a fork unless that is intentional.

4. **Branch protection (optional)**  
   Where useful, enable rules on `master` (e.g. require PR, no direct pushes) without blocking solo emergency fixes—tune per repo.

5. **Clean stale branches**  
   After merged PRs, prune remote tracking branches locally; optionally delete merged branches on GitHub for tidiness.

6. **Document exceptions**  
   Short note in this plan or per-repo: repos using `main`, archive-only repos, or shared repos with different rules.

## Success criteria

- Every “active” personal repo in this set either follows **`master` + feature branch + PR to `origin/master`** or has a **one-line documented exception**.
- No routine merge path goes through a non-canonical remote by mistake.

## Open questions

- Which repos are **strictly personal** vs **shared** (different rules)?
- Prefer **`gh`** CLI for bulk checks, or manual GitHub UI + local `git` only?

---

*Status: draft — expand inventory and exceptions as we execute.*
