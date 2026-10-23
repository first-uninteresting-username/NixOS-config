---
name: merge-prs
description: Merge open pull requests in this repository one at a time, rebasing each onto main and waiting for the required CI check before merging with a merge commit. Use only when the user explicitly asks to merge PRs, land the PR queue, or merge specific PR numbers.
disable-model-invocation: true
---

# Merge pull requests

Land open pull requests into `main` serially. Invoking this skill authorizes merging the
selected PRs; it does not authorize bypassing the ruleset, editing PR code, or resolving
conflicts.

With no further instructions, select every eligible open PR. Otherwise select only the PRs
the user names (numbers, branch names, labels, or a description).

## Repository constraints

- The `main-protection` ruleset allows only the **merge** method, and requires the
  `all-systems-passed` check (GitHub Actions) on a branch that is **up to date** with `main`.
  Every merge therefore makes all other PRs stale, and their CI must run again.
- Update branches by **rebasing** onto `main`, never by merging `main` into them. Merge with a
  normal merge commit. Never squash, never use `--rebase`, `--admin`, or `--auto`.
- `all-systems-passed` comes from the `Flake build` workflow and takes 5–20 minutes (longer
  for full runs). A new push cancels the previous run for that PR.
- The repository deletes head branches after merge, and GitHub retargets PRs stacked on them
  to `main`.
- `auto-merge.yaml` may merge bot dependency PRs on its own once CI passes. Treat a PR
  that becomes merged while waiting as merged.

## 1. Build the queue

```bash
git fetch origin main
gh pr list --state open --limit 100 --json number,title,headRefName,baseRefName,isDraft,author,isCrossRepository,labels,reviewDecision,mergeable,mergeStateStatus,headRefOid
```

Exclude, and report why:

- drafts, and PRs labeled `do-not-merge`, `wip`, or similar;
- PRs whose review decision is `CHANGES_REQUESTED`;
- cross-repository (fork) PRs, which need manual review;
- PRs not targeting `main` unless their base PR is also in the queue (queue them after it).

Order the queue by PR number, oldest first, with stacked PRs after their base. Show the
queue and the exclusions to the user, then proceed without waiting for confirmation.

## 2. Process one PR at a time

Rebase only the PR at the head of the queue. Rebasing others early wastes CI because each
merge makes them stale again.

For each PR `N`:

1. **Refresh.** `gh pr view N --json state,headRefOid,baseRefName,mergeable,mergeStateStatus`.
   Skip it if it is no longer open.
2. **Rebase if stale.** If the head does not contain current `origin/main`
   (`git fetch origin main` then compare, or `mergeStateStatus` is `BEHIND`):

   ```bash
   gh pr update-branch N --rebase
   ```

   If GitHub reports conflicts, skip the PR and record the conflict; do not resolve it
   unless the user asks. After the rebase, read the new `headRefOid`.
   If the PR is already up to date and `all-systems-passed` passed on its head, merge it
   at once.
3. **Wait for CI.** Run the wait script as a background command if your environment
   supports one and notifies you when it exits; otherwise run it in the foreground with the
   longest allowed command timeout and run it again if it is cut off. Do not write your own
   `sleep` loops:

   ```bash
   python3 .agents/skills/merge-prs/wait-for-ci.py N --sha <head-sha>
   ```

   It polls every 90 seconds, times out after 90 minutes, and exits with:

   | Exit | Meaning | Action |
   | --- | --- | --- |
   | 0 | `all-systems-passed` succeeded on that SHA | merge |
   | 1 | check failed; failed jobs are listed | see step 5 |
   | 2 | timed out | inspect the run with `gh run list`; rerun the wait or skip |
   | 3 | PR closed or merged elsewhere | record and continue |
   | 4 | someone pushed to the PR | restart from step 1 |

4. **Merge** only the SHA that passed:

   ```bash
   gh pr merge N --merge --match-head-commit <head-sha>
   ```

   Keep the default merge commit subject, which uses the PR title. If GitHub rejects the
   merge because `main` moved, return to step 1. Confirm with
   `gh pr view N --json state,mergeCommit`, then `git fetch origin main`.
5. **On failure**, read the failure: `gh run view <run-id> --log-failed | tail -n 80`.
   - Infrastructure errors (runner loss, network timeouts, cache or download failures): rerun
     once with `gh run rerun <run-id> --failed`, then wait again.
   - Otherwise skip the PR, summarize the failing job and error, and continue with the next.
     Do not push fixes unless the user asks.

Continue until the queue is empty. Work through skipped PRs only if the user asks.

## 3. Report

List merged PRs with merge commit SHAs, and skipped PRs with the reason and a link. Note
that rebased branches were force-pushed, so local checkouts of them have diverged; update
them with `git fetch` and `git reset --hard origin/<branch>` after checking for local work.
