import test from 'node:test';
import assert from 'node:assert/strict';
import { summarizeBalance, balanceReportDigest, captureTestSchedule } from '../tools/balance-report.mjs';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { balanceSourceFingerprint } from '../tools/balance-source.mjs';

const commit = 'a'.repeat(40);
const fingerprint = '1'.repeat(64);
const options = { commit, run: '42', gameIds: ['one', 'two'] };
function entry(id) {
  return {
    source: { commit, run: '42', game: id, mode: 'natural', runs: 24, difficultyRuns: 12, smokeRuns: 2 },
    checkout: `${commit}\n`,
    report: {
      engine_version: '4.7.1-stable (official)',
      simulation_source_start: fingerprint,
      simulation_source_end: fingerprint,
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
  assert.equal(result.sourceFingerprint, fingerprint);
  assert.equal(result.engineVersion, '4.7.1-stable (official)');
  assert.equal(result.sourceConsistencyVerified, true);
});
test('partial campaign names missing games explicitly', () => {
  const result = summarizeBalance([entry('one')], { ...options, partial: true });
  assert.equal(result.complete, false);
  assert.deepEqual(result.missing, ['two']);
  assert.equal(result.sourceConsistencyVerified, false);
  assert.throws(() => summarizeBalance([entry('one')], options), /Missing/);
});
test('targeted arena evidence cannot be presented as the default campaign', () => {
  const one = entry('one');
  one.report.arena_override = 'tank_oasis';
  assert.throws(() => summarizeBalance([one, entry('two')], options), /Targeted arena/);
  one.report.arena_override = '';
  assert.equal(summarizeBalance([one, entry('two')], options).complete, true);
});
test('warnings survive aggregation instead of becoming green readiness', () => {
  const one = entry('one');
  one.report.games[0].severity = 1;
  one.report.games[0].flags = ['character advantage'];
  assert.deepEqual(summarizeBalance([one, entry('two')], options).reviews,
    [{ game: 'one', flags: ['character advantage'] }]);
});

test('explicit legacy roster policy remains compatible with ordinary campaigns', () => {
  const one = entry('one');
  one.report.games[0].roster_policy = 'adjacent_rotation';
  assert.equal(summarizeBalance([one, entry('two')], options).complete, true);
});
for (const policy of ['seeded_partition_seat_rotation', 'unknown', null, 0]) {
  test(`diagnostic roster policy ${policy} cannot replace ordinary campaign evidence`, () => {
    const one = entry('one');
    one.report.games[0].roster_policy = policy;
    assert.throws(() => summarizeBalance([one, entry('two')], options), /roster policy/i);
  });
}

for (const [name, mutate] of [
  ['missing start', e => { delete e.report.simulation_source_start; }],
  ['missing end', e => { delete e.report.simulation_source_end; }],
  ['short fingerprint', e => { e.report.simulation_source_start = e.report.simulation_source_end = 'short'; }],
  ['non-hex fingerprint', e => { e.report.simulation_source_start = e.report.simulation_source_end = 'z'.repeat(64); }],
  ['changed source', e => { e.report.simulation_source_end = '2'.repeat(64); }],
  ['different source across games', e => { e.report.simulation_source_start = e.report.simulation_source_end = '2'.repeat(64); }],
  ['missing engine', e => { delete e.report.engine_version; }],
  ['wrong engine', e => { e.report.engine_version = '4.6-stable (official)'; }],
]) {
  test(`rejects campaign ${name}`, () => {
    const one = entry('one'); mutate(one);
    assert.throws(() => summarizeBalance([one, entry('two')], options));
  });
}

test('source pin cannot be replaced by an internally consistent different fingerprint', () => {
  assert.throws(() => summarizeBalance([entry('one'), entry('two')], {
    ...options, sourceFingerprint: '2'.repeat(64),
  }));
});

test('matching explicit source pin remains accepted without declaring release readiness', () => {
  const result = summarizeBalance([entry('one'), entry('two')], { ...options, sourceFingerprint: fingerprint });
  assert.equal(result.sourceFingerprint, fingerprint);
  assert.equal(result.sourceConsistencyVerified, true);
  assert.equal(result.releaseReady, false);
});

test('empty partial evidence does not invent a verified engine or source', () => {
  const result = summarizeBalance([], { ...options, partial: true });
  assert.equal(result.sourceFingerprint, null);
  assert.equal(result.engineVersion, null);
  assert.equal(result.sourceConsistencyVerified, false);
});

for (const sourceFingerprint of ['', 1, 'short', 'z'.repeat(64)]) {
  test(`rejects invalid expected fingerprint ${sourceFingerprint}`, () => {
    assert.throws(() => summarizeBalance([entry('one'), entry('two')], { ...options, sourceFingerprint }));
  });
}

for (const engineVersion of ['', ' ', null, 4.7]) {
  test(`rejects invalid expected engine ${engineVersion}`, () => {
    assert.throws(() => summarizeBalance([entry('one'), entry('two')], { ...options, engineVersion }));
  });
}
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

function offsetEntry(id, offset) {
  const value = pairedEntry(id);
  value.source.seedOffset = value.report.seed_offset = value.report.games[0].seed_offset = offset;
  value.report.games[0].baseline_seeds = Array.from({length: 24}, (_, i) => offset + 9001 + i * 613);
  value.report.mutator_smoke[0].mutated_seed = offset + 5501;
  value.report.mutator_smoke[0].chaos_seed = offset + 5502;
  for (const sample of value.report.games[0].difficulty_samples) sample.seed += offset;
  return value;
}
test('independent campaign records offset and still verifies matched pairs', () => {
  const result = summarizeBalance([offsetEntry('one', 100000), offsetEntry('two', 100000)], {...pairedOptions, seedOffset: 100000});
  assert.equal(result.seedOffset, 100000);
  assert.equal(result.difficultyPairingVerified, true);
  assert.equal(result.releaseReady, false);
});
for (const [name, mutate] of [
  ['source offset', e => { e.source.seedOffset = 0; }],
  ['report offset', e => { delete e.report.seed_offset; }],
  ['game offset', e => { e.report.games[0].seed_offset++; }],
  ['baseline missing', e => { delete e.report.games[0].baseline_seeds; }],
  ['baseline replayed', e => { e.report.games[0].baseline_seeds[0] = 9001; }],
  ['mutator replayed', e => { e.report.mutator_smoke[0].mutated_seed = 5501; }],
  ['chaos missing', e => { delete e.report.mutator_smoke[0].chaos_seed; }],
  ['both difficulty seeds replayed', e => { e.report.games[0].difficulty_samples[0].seed = e.report.games[0].difficulty_samples[1].seed = 4242; }],
]) {
  test(`rejects independent campaign ${name}`, () => {
    const one = offsetEntry('one', 100000); mutate(one);
    assert.throws(() => summarizeBalance([one, offsetEntry('two', 100000)], {...pairedOptions, seedOffset: 100000}));
  });
}
for (const seedOffset of [-1, 1.5, 1000000001, NaN, Infinity]) {
  test(`rejects invalid expected seed offset ${seedOffset}`, () => {
    assert.throws(() => summarizeBalance([], {...options, seedOffset}));
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
const bossOptions = { ...pairedOptions, bossGameIds: ['one'] };
function bossEntry() {
  const value = offsetEntry('one', 0);
  const game = value.report.games[0];
  game.boss_outcomes = game.baseline_seeds.map(seed => ({ seed, outcome: 'defeated' }));
  game.boss_defeated_runs = 24;
  game.boss_survived_runs = game.boss_unknown_runs = 0;
  game.difficulty_samples.forEach(sample => { sample.boss_outcome = 'survived'; });
  value.report.mutator_smoke[0].mutated_boss_outcome = 'survived';
  value.report.mutator_smoke[0].chaos_boss_outcome = 'defeated';
  return value;
}
test('boss completion requires explicit seeded objective evidence', () => {
  const summary = summarizeBalance([bossEntry(), pairedEntry('two')], bossOptions);
  assert.equal(summary.complete, true);
  assert.deepEqual(summary.bossComparisons, [{ game: 'one', difficulty: { defeated: 0, survived: 16 },
    stress: { mutated: 'survived', chaos: 'defeated' } }]);
});
for (const [name, mutate] of [
  ['missing outcomes', g => { delete g.boss_outcomes; }],
  ['missing counter', g => { delete g.boss_defeated_runs; }],
  ['negative counter', g => { g.boss_survived_runs = -1; }],
  ['fractional counter', g => { g.boss_defeated_runs = 23.5; }],
  ['string counter', g => { g.boss_defeated_runs = '24'; }],
  ['counter mismatch', g => { g.boss_defeated_runs = 23; g.boss_survived_runs = 1; }],
  ['short outcomes', g => { g.boss_outcomes.pop(); }],
  ['duplicate seed', g => { g.boss_outcomes[1].seed = g.boss_outcomes[0].seed; }],
  ['wrong seed', g => { g.boss_outcomes[0].seed++; }],
  ['malformed outcome', g => { g.boss_outcomes[0] = null; }],
  ['unknown objective', g => { g.boss_outcomes[0].outcome = 'unknown'; g.boss_defeated_runs = 23; g.boss_unknown_runs = 1; }],
  ['invalid objective', g => { g.boss_outcomes[0].outcome = 'finished'; }],
]) {
  test(`rejects boss evidence ${name}`, () => {
    const one = bossEntry(); mutate(one.report.games[0]);
    assert.throws(() => summarizeBalance([one, pairedEntry('two')], bossOptions), /boss/i);
  });
}
test('surviving every boss match requires a retained review warning', () => {
  const one = bossEntry(); const game = one.report.games[0];
  game.boss_outcomes.forEach(sample => { sample.outcome = 'survived'; });
  game.boss_defeated_runs = 0; game.boss_survived_runs = 24;
  assert.throws(() => summarizeBalance([one, pairedEntry('two')], bossOptions), /boss/i);
  game.flags = ['boss never defeated in baseline sample']; game.severity = 1;
  const summary = summarizeBalance([one, pairedEntry('two')], bossOptions);
  assert.deepEqual(summary.reviews, [{ game: 'one', flags: game.flags }]);
  assert.equal(summary.releaseReady, false);
  game.boss_outcomes[0].outcome = 'defeated'; game.boss_defeated_runs = 1; game.boss_survived_runs = 23;
  assert.throws(() => summarizeBalance([one, pairedEntry('two')], bossOptions), /boss/i);
});
test('boss outcomes must use the configured independent campaign offset', () => {
  const one = bossEntry();
  const independent = offsetEntry('one', 100000);
  Object.assign(independent.report.games[0], {
    boss_outcomes: one.report.games[0].boss_outcomes,
    boss_defeated_runs: 24, boss_survived_runs: 0, boss_unknown_runs: 0,
  });
  independent.report.games[0].difficulty_samples.forEach(sample => { sample.boss_outcome = 'survived'; });
  independent.report.mutator_smoke[0].mutated_boss_outcome = 'survived';
  independent.report.mutator_smoke[0].chaos_boss_outcome = 'survived';
  assert.throws(() => summarizeBalance([independent, offsetEntry('two', 100000)],
    { ...bossOptions, seedOffset: 100000 }), /boss/i);
  independent.report.games[0].boss_outcomes.forEach(sample => { sample.seed += 100000; });
  assert.equal(summarizeBalance([independent, offsetEntry('two', 100000)],
    { ...bossOptions, seedOffset: 100000 }).complete, true);
});
for (const [name, mutate] of [
  ['missing difficulty outcome', e => { delete e.report.games[0].difficulty_samples[0].boss_outcome; }],
  ['unknown difficulty outcome', e => { e.report.games[0].difficulty_samples[0].boss_outcome = 'unknown'; }],
  ['null difficulty sample', e => { e.report.games[0].difficulty_samples[0] = null; }],
  ['missing mutated outcome', e => { delete e.report.mutator_smoke[0].mutated_boss_outcome; }],
  ['unknown chaos outcome', e => { e.report.mutator_smoke[0].chaos_boss_outcome = 'unknown'; }],
  ['invalid mutated outcome', e => { e.report.mutator_smoke[0].mutated_boss_outcome = true; }],
]) {
  test(`rejects boss comparison ${name}`, () => {
    const one = bossEntry(); mutate(one);
    assert.throws(() => summarizeBalance([one, pairedEntry('two')], bossOptions));
  });
}
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

// Synthetic result records, not gameplay simulations. Construct the affine blocks
// from the parity definition independently, then rotate each quartet through seats.
function balancedEntry(id, runs = 56, seedOffset = 200000) {
  const value = offsetEntry(id, seedOffset);
  const game = value.report.games[0];
  const difficulty = Math.max(16, 2 * Math.ceil(runs / 4));
  value.source.runs = value.report.runs_per_game = game.attempted_runs = game.runs = runs;
  value.source.difficultyRuns = game.difficulty_attempted = game.difficulty_completed = difficulty;
  value.source.testScheduleStart = captureTestSchedule();
  value.source.testScheduleEnd = captureTestSchedule();
  value.report.arena_override = '';
  game.arena_id = `${id}_default`; game.round_window = 110;
  game.roster_policy = 'pair_balanced_affine_plane_rotation';
  game.pair_schedule = { cycle_length: 56, appearances_per_cycle: 28,
    appearances_per_seat_per_cycle: 7, pair_coappearances_per_cycle: 12 };
  game.baseline_seeds = Array.from({ length: runs }, (_, i) => seedOffset + 9001 + i * 613);
  game.baseline_rosters = [];
  for (let cycle = 0; cycle < Math.ceil(runs / 56); cycle++) {
    const labels = characterIds.map((_, i) => characterIds[(i + cycle) % 8]);
    for (let mask = 1; mask < 8; mask++) for (const side of [0, 1]) {
      const quartet = labels.filter((_, point) => (point & mask).toString(2).split('1').length % 2 === 1 - side);
      for (let seat = 0; seat < 4; seat++) game.baseline_rosters.push(quartet.map((_, i) => quartet[(i + seat) % 4]));
    }
  }
  game.baseline_rosters.length = runs;
  game.difficulty_samples = Array.from({ length: difficulty }, (_, i) => ({
    seed: seedOffset + 4242 + Math.floor(i / 2) * 97,
    character: characterIds[Math.floor(i / 2) % 8],
    expert_slots: i % 2 ? [2, 3] : [0, 1], completed: true,
    scores: i % 2 ? [2, 1, 4, 3] : [4, 3, 2, 1],
    places: i % 2 ? [3, 4, 1, 2] : [1, 2, 3, 4], details: [],
  }));
  game.difficulty_outcomes = { samples: difficulty, expert_wins: difficulty, easy_wins: 0,
    shared_first: 0, incomplete: 0, invalid: 0, expert_outright_win_share: 1 };
  game.wins_by_character = Object.fromEntries(characterIds.map(id => [id, runs / 8]));
  game.wins_by_slot = [runs / 4, runs / 4, runs / 4, runs / 4];
  Object.assign(game, { character_buckets: 8, character_bias: 0, slot_bias: 0,
    tie_rate: 0, avg_duration: 60, zero_score_runs: 0, expert_edge: 0.7 });
  return value;
}
function balancedOptions(entries, runs = entries[0].source.runs) {
  const seedOffset = entries[0].source.seedOffset;
  return { ...pairedOptions, sourceFingerprint: fingerprint, seedOffset,
    gameIds: entries.map(e => e.source.game),
    gameDefinitions: entries.map(e => ({ id: e.source.game, arenas: [`${e.source.game}_default`, 'private_arena'], duration: 110, scoring: 'lives' })),
    pairBalanced: { commit, run: '42', seedOffset, runs, simulationSource: fingerprint,
      testSchedule: captureTestSchedule(), reports: Object.fromEntries(entries.map(e => [e.source.game, balanceReportDigest(e.report)])) },
  };
}
function repin(e, opts) { opts.pairBalanced.reports[e.source.game] = balanceReportDigest(e.report); }

function baselineWithTies(game, ties, winnerCount) {
  game.wins_by_slot = [0, 0, 0, 0];
  game.wins_by_character = Object.fromEntries(characterIds.map(id => [id, 0]));
  game.baseline_rosters.forEach((roster, index) => {
    const winners = index < ties ? winnerCount : 1;
    for (let i = 0; i < winners; i++) {
      const slot = (index + i) % 4;
      game.wins_by_slot[slot]++;
      game.wins_by_character[roster[slot]]++;
    }
  });
  const total = Object.values(game.wins_by_character).reduce((sum, value) => sum + value, 0);
  game.slot_bias = Math.max(...game.wins_by_slot) / total - 0.25;
  game.character_bias = Math.max(...Object.values(game.wins_by_character)) / total - 0.125;
  game.tie_rate = Number((ties / game.runs).toPrecision(15));
  game.flags = game.tie_rate > 0.4 ? [`ties ${Math.round(game.tie_rate * 100)}% of the time`] : [];
  game.severity = game.flags.length ? 1 : 0;
}

for (const winnerCount of [2, 3, 4]) for (const ties of [1, 14, 56]) {
  test(`genuine ${ties} ties with ${winnerCount} shared winners retain every win credit`, () => {
    const one = balancedEntry('one'); baselineWithTies(one.report.games[0], ties, winnerCount);
    const opts = balancedOptions([one]);
    const result = summarizeBalance([one], opts);
    assert.equal(Object.values(result.characterWins).reduce((sum, value) => sum + value, 0), 56 + ties * (winnerCount - 1));
    assert.equal(result.complete, true);
    assert.equal(result.releaseReady, false);
  });
}
for (const [name, tieRate, actualTies, winners] of [
  ['positive ties with no extra winners', 0.25, 0, 2],
  ['fractional tie count', 0.01, 0, 2],
  ['extra winners without ties', 0, 14, 2],
  ['too many extra winners for ties', 0.25, 15, 4],
]) {
  test(`fresh digest cannot conceal ${name}`, () => {
    const one = balancedEntry('one'); const game = one.report.games[0];
    baselineWithTies(game, actualTies, winners);
    game.tie_rate = tieRate;
    const opts = balancedOptions([one]); repin(one, opts);
    assert.throws(() => summarizeBalance([one], opts), /balanced metrics/);
  });
}

function fractionalDifficultyEntry() {
  const one = balancedEntry('one'); const game = one.report.games[0];
  game.difficulty_samples.forEach((sample, i) => {
    const expertWin = i === 0;
    if (i < 3) {
      const firstPairWins = expertWin === (i % 2 === 0);
      sample.places = firstPairWins ? [1, 2, 3, 4] : [3, 4, 1, 2];
      sample.scores = sample.places.map(place => 5 - place);
    } else {
      sample.places = [1, 1, 1, 1]; sample.scores = [1, 1, 1, 1];
    }
  });
  game.expert_edge = 213 / 430;
  game.flags = ['expert bots no better than easy']; game.severity = 1;
  // Literal serialized output, not JS's more precise JSON.stringify(1 / 3).
  game.difficulty_outcomes = JSON.parse('{"samples":28,"expert_wins":1,"easy_wins":2,"shared_first":25,"incomplete":0,"invalid":0,"expert_outright_win_share":0.333333333333333}');
  one.report = JSON.parse(JSON.stringify(one.report));
  return one;
}
test('Godot 15-digit serialized fractional outright share is not a false mismatch', () => {
  const one = fractionalDifficultyEntry();
  assert.notEqual(one.report.games[0].difficulty_outcomes.expert_outright_win_share, 1 / 3);
  const result = summarizeBalance([one], balancedOptions([one]));
  assert.equal(result.complete, true);
  assert.deepEqual(result.reviews, [{ game: 'one', flags: ['expert bots no better than easy'] }]);
  assert.equal(result.releaseReady, false);
});
for (const [name, mutate] of [
  ['wrong fraction', o => { o.expert_outright_win_share = 0.33333333334; }],
  ['null fraction despite outright wins', o => { o.expert_outright_win_share = null; }],
  ['missing fraction', o => { delete o.expert_outright_win_share; }],
  ['string fraction', o => { o.expert_outright_win_share = '0.333333333333333'; }],
  ['fractional counter', o => { o.expert_wins = 1 + 1e-13; }],
  ['string counter', o => { o.easy_wins = '2'; }],
  ['missing counter', o => { delete o.invalid; }],
  ['extra counter', o => { o.other = 0; }],
]) {
  test(`fraction tolerance never permits ${name} with a fresh digest`, () => {
    const one = fractionalDifficultyEntry(); mutate(one.report.games[0].difficulty_outcomes);
    const opts = balancedOptions([one]); repin(one, opts);
    assert.throws(() => summarizeBalance([one], opts), /difficulty outcomes/);
  });
}
test('all shared first places require exactly null outright share', () => {
  const one = fractionalDifficultyEntry(); const game = one.report.games[0];
  game.difficulty_samples.forEach(sample => { sample.places = [1, 1, 1, 1]; sample.scores = [1, 1, 1, 1]; });
  game.expert_edge = 0.5;
  game.difficulty_outcomes = { samples: 28, expert_wins: 0, easy_wins: 0, shared_first: 28,
    incomplete: 0, invalid: 0, expert_outright_win_share: null };
  const opts = balancedOptions([one]);
  assert.equal(summarizeBalance([one], opts).complete, true);
  for (const share of [0, 0.5, undefined]) {
    game.difficulty_outcomes.expert_outright_win_share = share; repin(one, opts);
    assert.throws(() => summarizeBalance([one], opts), /difficulty outcomes/);
  }
});

test('balanced zero seed offset still requires explicit baseline, difficulty and smoke seeds', () => {
  const one = balancedEntry('one', 56, 0); const opts = balancedOptions([one]);
  assert.equal(summarizeBalance([one], opts).complete, true);
  delete one.report.mutator_smoke[0].chaos_seed; repin(one, opts);
  assert.throws(() => summarizeBalance([one], opts), /mutator seed/);
});
test('empty partial balanced evidence never claims equal verified difficulty allocation', () => {
  const one = balancedEntry('one', 224); const opts = balancedOptions([one]);
  const result = summarizeBalance([], { ...opts, partial: true });
  assert.equal(result.difficultyAllocationEqual, false);
  assert.equal(result.difficultyPairingVerified, false);
  assert.equal(result.sourceConsistencyVerified, false);
  assert.equal(result.releaseReady, false);
});

for (const runs of [56, 112, 224]) {
  test(`explicit balanced ${runs} verifies cycles, derived difficulty and diagnostic-only status`, () => {
    const entries = [balancedEntry('one', runs), balancedEntry('two', runs)];
    const result = summarizeBalance(entries, balancedOptions(entries));
    assert.equal(result.matchesCompleted, 2 * (runs + Math.max(16, 2 * Math.ceil(runs / 4)) + 2));
    assert.equal(result.difficultyAllocationEqual, runs === 224);
    assert.equal(result.difficultyPairingVerified, true);
    assert.equal(result.complete, true);
    assert.equal(result.measurementOnly, true);
    assert.equal(result.balanceReviewComplete, false);
    assert.equal(result.releaseReady, false);
  });
  test(`default path never implicitly accepts balanced ${runs}`, () => {
    const entries = [balancedEntry('one', runs), balancedEntry('two', runs)];
    assert.throws(() => summarizeBalance(entries, pairedOptions));
  });
  test(`default adjacent policy cannot silently expand to ${runs} runs`, () => {
    const one = pairedEntry('one');
    one.source.runs = one.report.games[0].attempted_runs = one.report.games[0].runs = runs;
    one.report.games[0].roster_policy = 'adjacent_rotation';
    assert.throws(() => summarizeBalance([one], { ...pairedOptions, gameIds: ['one'] }));
  });
}
test('balanced 39-game manifest counts 13182 instances, never grants readiness', () => {
  const entries = Array.from({ length: 39 }, (_, i) => balancedEntry(`game_${i}`, 224));
  const result = summarizeBalance(entries, balancedOptions(entries));
  assert.equal(result.gamesCompleted, 39);
  assert.equal(result.matchesCompleted, 13182);
  assert.equal(result.releaseReady, false);
});
for (const runs of [0, 24, 55, 57, 111, 113, 225, 10024, 56.5, '56', NaN]) {
  test(`balanced runs ${runs} must be bounded integer multiples of 56`, () => {
    const one = balancedEntry('one'); const opts = balancedOptions([one]);
    opts.pairBalanced.runs = runs;
    assert.throws(() => summarizeBalance([one], opts));
  });
}

for (const [name, mutate] of [
  ['missing rosters', g => { delete g.baseline_rosters; }],
  ['short rosters', g => { g.baseline_rosters.pop(); }],
  ['extra rosters', g => { g.baseline_rosters.push(g.baseline_rosters[0]); }],
  ['null roster', g => { g.baseline_rosters[0] = null; }],
  ['duplicate character', g => { g.baseline_rosters[0][0] = g.baseline_rosters[0][1]; }],
  ['foreign character', g => { g.baseline_rosters[0][0] = 'other'; }],
  ['seat rotation', g => { g.baseline_rosters[1].reverse(); }],
  ['missing table', g => { delete g.pair_schedule; }],
  ['forged table', g => { g.pair_schedule.pair_coappearances_per_cycle = 11; }],
  ['extra table field', g => { g.pair_schedule.fake = true; }],
  ['unbalanced quartets', g => { for (let i = 4; i < 8; i++) g.baseline_rosters[i] = [...g.baseline_rosters[i - 4]]; }],
  ['missing seeds', g => { delete g.baseline_seeds; }],
  ['short seeds', g => { g.baseline_seeds.pop(); }],
  ['replayed seeds', g => { g.baseline_seeds[1] = g.baseline_seeds[0]; }],
  ['seed offset', g => { g.seed_offset++; }],
  ['missing difficulty', g => { delete g.difficulty_samples; }],
  ['short difficulty', g => { g.difficulty_samples.pop(); }],
  ['extra difficulty', g => { g.difficulty_samples.push(g.difficulty_samples[0]); }],
  ['wrong derived count', g => { g.difficulty_attempted = g.difficulty_completed = 16; }],
  ['null difficulty row', g => { g.difficulty_samples[0] = null; }],
  ['difficulty seed', g => { g.difficulty_samples[1].seed++; }],
  ['both difficulty seeds', g => { g.difficulty_samples[0].seed = g.difficulty_samples[1].seed = 1; }],
  ['difficulty character order', g => { g.difficulty_samples[0].character = g.difficulty_samples[1].character = characterIds[7]; }],
  ['difficulty reflection', g => { g.difficulty_samples[1].expert_slots = [0, 1]; }],
  ['unfinished difficulty', g => { g.difficulty_samples[0].completed = false; }],
  ['missing places', g => { delete g.difficulty_samples[0].places; }],
  ['missing scores', g => { delete g.difficulty_samples[0].scores; }],
  ['missing outcome summary', g => { delete g.difficulty_outcomes; }],
  ['forged outcome summary', g => { g.difficulty_outcomes.easy_wins = 1; }],
  ['invalid places', g => { g.difficulty_samples[0].places[0] = 0; }],
  ['placement share', g => { g.expert_edge = 0.9; }],
  ['missing win bucket', g => { delete g.wins_by_character[characterIds[0]]; }],
  ['foreign win bucket', g => { g.wins_by_character.other = 1; }],
  ['invalid slot counts', g => { g.wins_by_slot[0] = -1; }],
  ['bias mismatch', g => { g.character_bias = 0.2; }],
  ['missing metric', g => { delete g.tie_rate; }],
  ['hidden short duration', g => { g.avg_duration = 1; }],
  ['hidden ties', g => { g.tie_rate = 0.5; }],
  ['targeted arena', g => { g.arena_id = 'private_arena'; }],
  ['clipped natural window', g => { g.round_window = 14; }],
  ['legacy policy', g => { g.roster_policy = 'adjacent_rotation'; }],
]) {
  test(`balanced structural verification rejects ${name} even with a matching report digest`, () => {
    const one = balancedEntry('one'); const opts = balancedOptions([one]);
    mutate(one.report.games[0]); repin(one, opts);
    assert.throws(() => summarizeBalance([one], opts));
  });
}

test('cycle-local imbalance is rejected even when aggregate counts remain balanced', () => {
  const one = balancedEntry('one', 112); const opts = balancedOptions([one]);
  // Move two complementary quartets across cycles: global totals are unchanged.
  for (let i = 0; i < 4; i++) {
    [one.report.games[0].baseline_rosters[i], one.report.games[0].baseline_rosters[56 + i]] =
      [one.report.games[0].baseline_rosters[56 + i], one.report.games[0].baseline_rosters[i]];
  }
  repin(one, opts);
  assert.throws(() => summarizeBalance([one], opts), /distribution/);
});

test('equal character and seat appearances cannot conceal unequal pair coappearances', () => {
  const one = balancedEntry('one'); const opts = balancedOptions([one]);
  // Two complementary quartets still give every character one turn at every seat.
  // Repeating that partition instead of the next affine partition biases pairs only.
  for (let i = 0; i < 8; i++) one.report.games[0].baseline_rosters[8 + i] = [...one.report.games[0].baseline_rosters[i]];
  repin(one, opts);
  assert.throws(() => summarizeBalance([one], opts), /distribution/);
});

for (const [name, mutate] of [
  ['missing start schedule', e => { delete e.source.testScheduleStart; }],
  ['missing end schedule', e => { delete e.source.testScheduleEnd; }],
  ['changed schedule file', e => { e.source.testScheduleEnd.files['tests/balance_pair_schedule.gd'] = 'f'.repeat(64); }],
  ['custom entrypoint', e => { e.source.testScheduleStart.entrypoint = 'res://tests/balance_contact_trace.tscn'; }],
  ['source identity', e => { e.source.commit = 'b'.repeat(40); }],
  ['checkout identity', e => { e.checkout = 'b'.repeat(40); }],
  ['run identity', e => { e.source.run = '43'; }],
  ['source fingerprint', e => { e.report.simulation_source_start = e.report.simulation_source_end = '2'.repeat(64); }],
  ['engine', e => { e.report.engine_version = 'other'; }],
  ['targeted override', e => { e.report.arena_override = 'private_arena'; }],
  ['missing default override', e => { delete e.report.arena_override; }],
  ['extra game row', e => { e.report.games.push(structuredClone(e.report.games[0])); }],
  ['extra smoke row', e => { e.report.mutator_smoke.push(structuredClone(e.report.mutator_smoke[0])); }],
  ['changed mutated seed', e => { e.report.mutator_smoke[0].mutated_seed++; }],
  ['missing chaos seed', e => { delete e.report.mutator_smoke[0].chaos_seed; }],
  ['smoke warning', e => { e.report.mutator_smoke[0].flags = ['error']; e.report.mutator_smoke[0].severity = 2; }],
  ['wrong report runs', e => { e.report.runs_per_game = 24; }],
  ['source count', e => { e.source.runs = 24; }],
  ['source difficulty count', e => { e.source.difficultyRuns = 16; }],
  ['unpaired metadata', e => { delete e.source.difficultyPolicy; }],
  ['mixed source policy', e => { e.source.rosterPolicy = 'adjacent_rotation'; }],
  ['private scene metadata', e => { e.source.scene = 'res://private/measurement.tscn'; }],
  ['custom assets metadata', e => { e.source.assets = ['private.png']; }],
  ['source arena metadata', e => { e.source.arenaOverride = 'private_arena'; }],
  ['missing report offset', e => { delete e.report.seed_offset; }],
  ['missing source offset', e => { delete e.source.seedOffset; }],
]) {
  test(`balanced metadata rejects ${name}`, () => {
    const one = balancedEntry('one'); const opts = balancedOptions([one]);
    mutate(one); repin(one, opts);
    assert.throws(() => summarizeBalance([one], opts));
  });
}

test('balanced boss evidence retains objective gates and derived difficulty length', () => {
  const one = balancedEntry('one', 224); const game = one.report.games[0];
  const opts = balancedOptions([one]); opts.bossGameIds = ['one']; opts.gameDefinitions[0].boss = true;
  game.boss_outcomes = game.baseline_seeds.map(seed => ({ seed, outcome: 'survived' }));
  game.boss_defeated_runs = game.boss_unknown_runs = 0; game.boss_survived_runs = 224;
  game.flags = ['boss never defeated in baseline sample']; game.severity = 1;
  game.difficulty_samples.forEach(sample => { sample.boss_outcome = 'survived'; });
  one.report.mutator_smoke[0].mutated_boss_outcome = 'survived';
  one.report.mutator_smoke[0].chaos_boss_outcome = 'defeated';
  repin(one, opts);
  const result = summarizeBalance([one], opts);
  assert.equal(result.bossComparisons[0].difficulty.survived, 112);
  assert.equal(result.reviews[0].flags[0], 'boss never defeated in baseline sample');
  assert.equal(result.releaseReady, false);
  game.flags = []; game.severity = 0; repin(one, opts);
  assert.throws(() => summarizeBalance([one], opts), /boss/i);
});

test('balanced points games cannot suppress a zero-score warning even with a fresh digest', () => {
  const one = balancedEntry('one'); const opts = balancedOptions([one]);
  opts.gameDefinitions[0].scoring = 'points'; one.report.games[0].zero_score_runs = 1;
  repin(one, opts);
  assert.throws(() => summarizeBalance([one], opts), /zero-score/);
});

test('balanced CLI requires explicit pinned attestation and rejects private/unknown options', t => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'kras-balanced-report-'));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const project = new URL('../', import.meta.url);
  const catalogue = JSON.parse(fs.readFileSync(new URL('data/minigames.json', project), 'utf8')).games;
  const chars = JSON.parse(fs.readFileSync(new URL('data/characters.json', project), 'utf8')).characters.map(c => c.id);
  const pin = balanceSourceFingerprint(project.pathname);
  // Translate the synthetic records to the actual catalogue; no Godot is invoked.
  const one = JSON.parse(JSON.stringify(balancedEntry('duel_pit')).replace(/character_([0-7])/g, (_, i) => chars[Number(i)]));
  const definition = catalogue.find(game => game.id === 'duel_pit');
  one.report.games[0].arena_id = definition.arenas[0];
  one.report.simulation_source_start = one.report.simulation_source_end = pin;
  one.report.games[0].flags = ['character advantage']; one.report.games[0].severity = 1;
  const manifest = { commit, run: '42', runs: 56, seedOffset: 200000, simulationSource: pin,
    testSchedule: captureTestSchedule(), reports: { duel_pit: balanceReportDigest(one.report) } };
  const artifact = path.join(root, 'duel');
  fs.mkdirSync(path.join(artifact, 'balance-report'), { recursive: true });
  fs.writeFileSync(path.join(artifact, 'balance-source.json'), JSON.stringify(one.source));
  fs.writeFileSync(path.join(artifact, 'balance-checkout.txt'), one.checkout);
  fs.writeFileSync(path.join(artifact, 'balance-report/report.json'), JSON.stringify(one.report));
  const attestation = path.join(root, 'trusted.json'); fs.writeFileSync(attestation, JSON.stringify(manifest));
  const args = [new URL('../tools/balance-report.mjs', import.meta.url).pathname, artifact, commit, '42', '--partial', '--seed-offset=200000'];
  const invoke = extra => spawnSync(process.execPath, [...args, ...extra], { encoding: 'utf8', timeout: 10000 });
  const explicit = [`--source-fingerprint=${pin}`, `--pair-balanced-attestation=${attestation}`];
  const success = invoke(explicit);
  assert.equal(success.status, 0, success.stderr);
  const summary = JSON.parse(success.stdout);
  assert.equal(summary.complete, false); assert.equal(summary.releaseReady, false);
  assert.deepEqual(summary.reviews, [{ game: 'duel_pit', flags: ['character advantage'] }]);
  assert.equal(invoke([]).status, 1);
  assert.equal(invoke([explicit[1]]).status, 1);
  assert.equal(invoke([`--source-fingerprint=${'f'.repeat(64)}`, explicit[1]]).status, 1);
  assert.equal(invoke([...explicit, '--arena=private_arena']).status, 1);
  assert.equal(invoke([...explicit, '--assets=private']).status, 1);
  assert.equal(invoke([...explicit, explicit[1]]).status, 1);
  delete one.source.testScheduleStart; // Old evidence must not be auto-attested.
  fs.writeFileSync(path.join(artifact, 'balance-source.json'), JSON.stringify(one.source));
  assert.equal(invoke(explicit).status, 1);
});

test('original report digest prevents warning removal even with severity rewritten to zero', () => {
  const one = balancedEntry('one'); const game = one.report.games[0];
  game.flags = ['character advantage']; game.severity = 1;
  const opts = balancedOptions([one]);
  assert.deepEqual(summarizeBalance([one], opts).reviews, [{ game: 'one', flags: ['character advantage'] }]);
  game.flags = []; game.severity = 0;
  assert.throws(() => summarizeBalance([one], opts), /attestation/);
});
test('canonical report pin ignores object key order, never array or value changes', () => {
  assert.equal(balanceReportDigest({ b: 1, a: [2, 3] }), balanceReportDigest({ a: [2, 3], b: 1 }));
  assert.notEqual(balanceReportDigest({ a: [2, 3] }), balanceReportDigest({ a: [3, 2] }));
});
test('mixed policies, duplicate games, missing games and empty partial evidence cannot certify a campaign', () => {
  const entries = [balancedEntry('one'), balancedEntry('two')]; const opts = balancedOptions(entries);
  assert.throws(() => summarizeBalance([entries[0], offsetEntry('two', 200000)], opts));
  assert.throws(() => summarizeBalance([entries[0], entries[0]], { ...opts, partial: true }));
  assert.throws(() => summarizeBalance([entries[0]], opts), /Missing/);
  const partial = summarizeBalance([entries[0]], { ...opts, partial: true });
  assert.deepEqual(partial.missing, ['two']); assert.equal(partial.sourceConsistencyVerified, false);
  assert.equal(summarizeBalance([], { ...opts, partial: true }).complete, false);
  const legacy = pairedEntry('one'); legacy.report.games[0].pair_schedule = entries[0].report.games[0].pair_schedule;
  assert.throws(() => summarizeBalance([legacy], { ...pairedOptions, gameIds: ['one'] }), /roster/);
});
for (const [name, mutate] of [
  ['missing explicit source pin', o => { o.sourceFingerprint = null; }],
  ['attested source mismatch', o => { o.pairBalanced.simulationSource = '2'.repeat(64); }],
  ['commit mismatch', o => { o.pairBalanced.commit = 'b'.repeat(40); }],
  ['run mismatch', o => { o.pairBalanced.run = '43'; }],
  ['seed mismatch', o => { o.pairBalanced.seedOffset++; }],
  ['schedule mismatch', o => { o.pairBalanced.testSchedule.files['tests/balance_pair_schedule.gd'] = 'f'.repeat(64); }],
  ['extra attested file', o => { o.pairBalanced.testSchedule.files.other = 'f'.repeat(64); }],
  ['missing attested tool', o => { delete o.pairBalanced.testSchedule.files['tools/balance-report.mjs']; }],
  ['missing digest', o => { delete o.pairBalanced.reports.one; }],
  ['extra digest', o => { o.pairBalanced.reports.other = fingerprint; }],
  ['malformed digest', o => { o.pairBalanced.reports.one = 'short'; }],
  ['changed report digest', o => { o.pairBalanced.reports.one = '2'.repeat(64); }],
  ['missing catalogue', o => { o.gameDefinitions = []; }],
  ['missing scoring identity', o => { delete o.gameDefinitions[0].scoring; }],
  ['duplicate catalogue', o => { o.gameDefinitions.push(o.gameDefinitions[0]); }],
  ['missing characters', o => { o.characterIds = []; }],
]) {
  test(`balanced trust boundary rejects ${name}`, () => {
    const one = balancedEntry('one'); const opts = balancedOptions([one]); mutate(opts);
    assert.throws(() => summarizeBalance([one], opts));
  });
}
