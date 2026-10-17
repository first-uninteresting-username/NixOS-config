// SPDX-FileCopyrightText: 2026 first-uninteresting-username
//
// SPDX-License-Identifier: GPL-3.0-or-later

const {test} = require('node:test');
const assert = require('node:assert/strict');
const cleanup = require('../cleanup-branches.cjs');

function fixture({name = 'stale', protectedBranch = false, recent = [],
  changed = false, pulls = [], date = '2026-08-01T00:00:00Z', failure = false} = {}) {
  const branch = {name, protected: protectedBranch, commit: {sha: 'old'}};
  const deleted = [];
  const summary = {addHeading() {return this;}, addRaw() {return this;},
    addList() {return this;}, async write() {}};
  const repos = {
    get: async () => ({data: {default_branch: 'main'}}),
    listBranches: 'branches',
    listCommits: async () => ({data: recent}),
    getBranch: async () => ({data: {...branch, commit: {
      sha: changed ? 'new' : 'old', commit: {committer: {date}},
    }}}),
  };
  return {deleted, args: {
    github: {rest: {repos, pulls: {list: 'pulls'}},
      paginate: async endpoint => {
        if (failure && endpoint === 'pulls') throw Error('API unavailable');
        return endpoint === 'branches' ? [branch] : pulls;
      }},
    context: {repo: {owner: 'owner', repo: 'repo'}},
    core: {info() {}, summary}, now: new Date('2026-10-17T07:17:00Z'),
    deleteBranch: async (...args) => deleted.push(args),
  }};
}

test('delete only the observed stale head, including branches from closed PRs', async () => {
  const {args, deleted} = fixture();
  assert.deepEqual(await cleanup(args), ['stale']);
  assert.deepEqual(deleted, [['stale', 'old']]);
});

for (const options of [
  {name: 'main'}, {protectedBranch: true}, {recent: [{sha: 'recent-ancestor'}]},
  {changed: true}, {date: null}, {date: '2026-09-17T07:17:00Z'},
  {pulls: [{draft: true, head: {ref: 'stale', repo: {full_name: 'owner/repo'}}}]},
  {pulls: [{base: {ref: 'stale', repo: {full_name: 'owner/repo'}}}]},
]) {
  test(`preserve ineligible branch: ${JSON.stringify(options)}`, async () => {
    const {args, deleted} = fixture(options);
    await cleanup(args);
    assert.deepEqual(deleted, []);
  });
}

test('API failure cannot authorize deletion', async () => {
  const {args, deleted} = fixture({failure: true});
  await assert.rejects(cleanup(args), /API unavailable/);
  assert.deepEqual(deleted, []);
});

test('calendar month cutoff clamps month ends and handles leap years', () => {
  assert.equal(cleanup.previousMonth(new Date('2026-03-31T07:17:00Z')).toISOString(),
    '2026-02-28T07:17:00.000Z');
  assert.equal(cleanup.previousMonth(new Date('2024-03-31T07:17:00Z')).toISOString(),
    '2024-02-29T07:17:00.000Z');
});
