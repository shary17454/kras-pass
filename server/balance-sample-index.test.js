import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { indexBalanceSamples } from '../tools/balance-sample-index.mjs';
import { balanceSourceFingerprint } from '../tools/balance-source.mjs';

const sourceFingerprint = 'a'.repeat(64);
const options = { sourceFingerprint, gameIds: ['crumble', 'race'] };
function entry(label, flags = []) {
  return { label, report: {
    simulation_source_start: sourceFingerprint, simulation_source_end: sourceFingerprint,
    engine_version: '4.7.1-stable (official)', sample_mode: 'natural', seed_offset: 1200000,
    games: [{ id: 'crumble', sample_mode: 'natural', runs: 96, attempted_runs: 96,
      difficulty_completed: 48, difficulty_attempted: 48,
      difficulty_pairing: 'matched_seed_character', severity: flags.length ? 1 : 0, flags }],
  } };
}
const index = entries => indexBalanceSamples(entries, options);

test('later clean recheck cannot erase an earlier current warning', () => {
  for (const entries of [[entry('bad', ['spawn advantage']), entry('clean')],
    [entry('clean'), entry('bad', ['spawn advantage'])]]) {
    const result = index(entries);
    assert.deepEqual(result.games[0].flags, ['spawn advantage']);
    assert.equal(result.games[0].samples.length, 2);
    assert.equal(result.games[0].requiresBalanceReview, true);
    assert.equal(result.releaseReady, false);
  }
});

test('clean current evidence still requires device review and attestation', () => {
  const result = index([entry('clean')]);
  assert.equal(result.games[0].hasEligibleSample, true);
  assert.equal(result.games[0].requiresDeviceReview, true);
  assert.equal(result.campaignAttestationVerified, false);
  assert.equal(result.games[1].requiresBalanceReview, true);
  assert.equal(result.releaseReady, false);
});

test('stale or mid-run changed sources are retained but cannot qualify', () => {
  for (const key of ['simulation_source_start', 'simulation_source_end']) {
    const old = entry('old', ['old warning']);
    old.report[key] = 'b'.repeat(64);
    const result = index([old, entry('current')]);
    assert.equal(result.games[0].samples[0].eligible, false);
    assert.equal(result.games[0].samples[0].current, false);
    assert.deepEqual(result.games[0].samples[0].flags, ['old warning']);
    assert.deepEqual(result.games[0].flags, []);
  }
});

test('incomplete current warning remains visible instead of being dropped', () => {
  const bad = entry('unfinished', ['spawn advantage']);
  bad.report.games[0].attempted_runs++;
  const game = index([bad, entry('clean')]).games[0];
  assert.equal(game.samples[0].eligible, false);
  assert.deepEqual(game.flags, ['spawn advantage']);
  assert.equal(game.requiresBalanceReview, true);
});

test('bad flags, severity, engine, mode and difficulty fail eligibility', () => {
  const changes = [e => { e.report.games[0].flags = null; },
    e => { e.report.games[0].severity = 1; },
    e => { e.report.engine_version = 'old'; },
    e => { e.report.sample_mode = 'clipped'; },
    e => { e.report.games[0].difficulty_completed = 0; }];
  for (const change of changes) {
    const bad = entry('bad'); change(bad);
    const game = index([bad]).games[0];
    assert.equal(game.hasEligibleSample, false);
    assert.equal(game.requiresBalanceReview, true);
  }
});

test('duplicate reports and unknown or duplicate games are rejected', () => {
  assert.throws(() => index([entry('same'), entry('same')]), /duplicate report/);
  const unknown = entry('unknown'); unknown.report.games[0].id = 'unknown';
  assert.throws(() => index([unknown]), /Unknown/);
  const duplicate = entry('duplicate'); duplicate.report.games.push(duplicate.report.games[0]);
  assert.throws(() => index([duplicate]), /duplicate game/);
});

test('overlapping seeds are retained separately without invented match totals', () => {
  const result = index([entry('first'), entry('repeat')]);
  assert.equal(result.games[0].samples.length, 2);
  assert.equal('matchesCompleted' in result, false);
  assert.equal('runs' in result.games[0], false);
});

test('empty evidence cannot claim balance or release readiness', () => {
  const result = index([]);
  assert(result.games.every(game => game.requiresBalanceReview && !game.hasEligibleSample));
  assert.equal(result.releaseReady, false);
  assert.throws(() => indexBalanceSamples([], { ...options, sourceFingerprint: 'invalid' }), /identity/);
});

test('CLI reads the actual catalogue and pins the current checkout itself', t => {
  const root = fileURLToPath(new URL('../', import.meta.url));
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'kras-sample-index-'));
  t.after(() => fs.rmSync(directory, { recursive: true, force: true }));
  const report = entry('cli', ['spawn advantage']).report;
  const fingerprint = balanceSourceFingerprint(root);
  report.simulation_source_start = report.simulation_source_end = fingerprint;
  report.games[0].id = 'crumble_court';
  const filename = path.join(directory, 'report.json');
  fs.writeFileSync(filename, JSON.stringify(report));
  const output = execFileSync(process.execPath, [path.join(root, 'tools/balance-sample-index.mjs'),
    root, filename], { encoding: 'utf8' });
  const result = JSON.parse(output);
  assert.equal(result.games.length, 39);
  assert.equal(result.sourceFingerprint, fingerprint);
  assert.deepEqual(result.games.find(game => game.id === 'crumble_court').flags, ['spawn advantage']);
  fs.writeFileSync(filename, '{bad json');
  assert.throws(() => execFileSync(process.execPath,
    [path.join(root, 'tools/balance-sample-index.mjs'), root, filename], { stdio: 'pipe' }));
});
