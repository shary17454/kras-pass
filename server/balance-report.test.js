import test from 'node:test';
import assert from 'node:assert/strict';
import { summarizeBalance } from '../tools/balance-report.mjs';

const commit = 'a'.repeat(40);
const options = { commit, run: '42', gameIds: ['one', 'two'] };
function entry(id) {
  return {
    source: { commit, run: '42', game: id, mode: 'natural', runs: 24, difficultyRuns: 12, smokeRuns: 2 },
    checkout: `${commit}\n`,
    report: {
      sample_mode: 'natural',
      games: [{ id, sample_mode: 'natural', attempted_runs: 24, runs: 24,
        difficulty_attempted: 12, difficulty_completed: 12, severity: 0, flags: [], wins_by_character: { nabta: 3 } }],
      mutator_smoke: [{ id, mutated_ok: true, chaos_ok: true, severity: 0, flags: [] }],
    },
  };
}

test('complete campaign counts actual qualified matches but does not certify release', () => {
  const result = summarizeBalance([entry('one'), entry('two')], options);
  assert.equal(result.matchesCompleted, 76);
  assert.equal(result.complete, true);
  assert.equal(result.characterWins.nabta, 6);
  assert.equal(result.releaseReady, false);
  assert.equal(result.balanceReviewComplete, false);
});
test('partial campaign names missing games explicitly', () => {
  const result = summarizeBalance([entry('one')], { ...options, partial: true });
  assert.equal(result.complete, false);
  assert.deepEqual(result.missing, ['two']);
  assert.throws(() => summarizeBalance([entry('one')], options), /Missing/);
});
test('warnings survive aggregation instead of becoming green readiness', () => {
  const one = entry('one');
  one.report.games[0].severity = 1;
  one.report.games[0].flags = ['character advantage'];
  assert.deepEqual(summarizeBalance([one, entry('two')], options).reviews,
    [{ game: 'one', flags: ['character advantage'] }]);
});
for (const [name, mutate] of [
  ['wrong source', e => { e.source.commit = 'b'.repeat(40); }],
  ['wrong checkout', e => { e.checkout = 'b'.repeat(40); }],
  ['mixed run', e => { e.source.run = '43'; }],
  ['clipped window', e => { e.report.sample_mode = 'clipped'; }],
  ['incomplete baseline', e => { e.report.games[0].runs = 23; }],
  ['incomplete difficulty', e => { e.report.games[0].difficulty_completed = 11; }],
  ['failed smoke', e => { e.report.mutator_smoke[0].chaos_ok = false; }],
  ['critical flag', e => { e.report.games[0].severity = 2; }],
  ['unlabelled warning', e => { e.report.games[0].flags = ['character advantage']; }],
  ['malformed warning', e => { e.report.games[0].flags = [{}]; e.report.games[0].severity = 1; }],
  ['wrong game', e => { e.report.games[0].id = 'two'; }],
  ['invalid wins', e => { e.report.games[0].wins_by_character.nabta = -1; }],
]) {
  test(`rejects ${name}`, () => {
    const one = entry('one');
    mutate(one);
    assert.throws(() => summarizeBalance([one, entry('two')], options));
  });
}
test('rejects duplicate reports even in partial mode', () => {
  assert.throws(() => summarizeBalance([entry('one'), entry('one')], { ...options, partial: true }));
});
test('rejects unregistered source and invalid expected identity', () => {
  assert.throws(() => summarizeBalance([entry('three')], { ...options, partial: true }));
  assert.throws(() => summarizeBalance([], { ...options, commit: 'short' }));
});

const characterIds = Array.from({ length: 8 }, (_, i) => `character_${i}`);
function pairedEntry(id) {
  const value = entry(id);
  value.source.difficultyPolicy = 'matched_seed_character';
  value.source.difficultyRuns = 16;
  const game = value.report.games[0];
  game.difficulty_attempted = game.difficulty_completed = 16;
  game.difficulty_pairing = 'matched_seed_character';
  game.difficulty_samples = Array.from({ length: 16 }, (_, i) => ({
    seed: 4242 + Math.floor(i / 2) * 97, character: characterIds[Math.floor(i / 2)],
    expert_slots: i % 2 === 0 ? [0, 1] : [2, 3], completed: true,
  }));
  return value;
}
const pairedOptions = { ...options, characterIds, requirePaired: true };
test('paired campaign verifies all roster members and adjusted match counts', () => {
  const result = summarizeBalance([pairedEntry('one'), pairedEntry('two')], pairedOptions);
  assert.equal(result.matchesCompleted, 84);
  assert.equal(result.difficultyPairingVerified, true);
});
test('legacy evidence stays explicitly unpaired and cannot qualify a paired campaign', () => {
  assert.equal(summarizeBalance([entry('one'), entry('two')], options).difficultyPairingVerified, false);
  assert.throws(() => summarizeBalance([entry('one'), entry('two')], pairedOptions));
});
for (const [name, mutate] of [
  ['world seed', e => { e.report.games[0].difficulty_samples[1].seed++; }],
  ['character', e => { e.report.games[0].difficulty_samples[1].character = 'other'; }],
  ['seat orientation', e => { e.report.games[0].difficulty_samples[1].expert_slots = [0, 1]; }],
  ['completion', e => { e.report.games[0].difficulty_samples[1].completed = false; }],
  ['roster coverage', e => { e.report.games[0].difficulty_samples[14].character = e.report.games[0].difficulty_samples[15].character = characterIds[0]; }],
]) {
  test(`rejects mismatched paired ${name}`, () => {
    const one = pairedEntry('one'); mutate(one);
    assert.throws(() => summarizeBalance([one, pairedEntry('two')], pairedOptions));
  });
}
