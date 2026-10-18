// SPDX-FileCopyrightText: 2026 first-uninteresting-username
//
// SPDX-License-Identifier: GPL-3.0-or-later

const {execFileSync} = require('node:child_process');

function previousMonth(now) {
  const cutoff = new Date(now);
  const day = cutoff.getUTCDate();
  cutoff.setUTCDate(1);
  cutoff.setUTCMonth(cutoff.getUTCMonth() - 1);
  const lastDay = new Date(Date.UTC(
    cutoff.getUTCFullYear(), cutoff.getUTCMonth() + 1, 0,
  )).getUTCDate();
  cutoff.setUTCDate(Math.min(day, lastDay));
  return cutoff;
}

async function cleanup({github, context, core, now = new Date(), deleteBranch}) {
  const repo = context.repo;
  const cutoff = previousMonth(now);
  const {data: metadata} = await github.rest.repos.get(repo);
  const branches = await github.paginate(github.rest.repos.listBranches, {
    ...repo, per_page: 100,
  });
  const deleted = [];
  deleteBranch ??= (name, sha) => execFileSync('git', [
    'push', `--force-with-lease=refs/heads/${name}:${sha}`,
    'origin', `:refs/heads/${name}`,
  ], {stdio: 'pipe'});

  for (const branch of branches) {
    if (branch.name === 'main' || branch.name === metadata.default_branch || branch.protected) {
      continue;
    }
    // Check the pinned history, including recent ancestors behind an old tip.
    const {data: recent} = await github.rest.repos.listCommits({
      ...repo, sha: branch.commit.sha, since: cutoff.toISOString(), per_page: 1,
    });
    if (recent.length) continue;

    const {data: current} = await github.rest.repos.getBranch({...repo, branch: branch.name});
    if (current.protected || current.commit.sha !== branch.commit.sha) continue;
    const committed = Date.parse(current.commit.commit.committer?.date);
    if (!Number.isFinite(committed) || committed >= cutoff.getTime()) continue;

    // Re-read both metadata and all open PRs immediately before deletion.
    const {data: latest} = await github.rest.repos.get(repo);
    if (branch.name === latest.default_branch) continue;
    const pulls = await github.paginate(github.rest.pulls.list, {
      ...repo, state: 'open', per_page: 100,
    });
    const fullName = `${repo.owner}/${repo.repo}`.toLowerCase();
    const inUse = pulls.some(pr => [pr.head, pr.base].some(ref =>
      ref?.repo?.full_name?.toLowerCase() === fullName && ref.ref === branch.name,
    ));
    if (inUse) continue;

    // A concurrent push makes the lease fail instead of deleting the new work.
    await deleteBranch(branch.name, branch.commit.sha);
    deleted.push(branch.name);
    core.info(`Deleted ${branch.name} at ${branch.commit.sha}`);
  }
  await core.summary.addHeading('Stale branch cleanup')
    .addRaw(`Commit cutoff: ${cutoff.toISOString()}\n`)
    .addList(deleted.length ? deleted : ['No eligible branches'])
    .write();
  return deleted;
}

module.exports = cleanup;
module.exports.previousMonth = previousMonth;
