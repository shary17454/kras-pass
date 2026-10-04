import assert from 'node:assert/strict';
import {Tournament} from './tournament.js';

// Recorded host results from run 37230877167, intended head 0a60b58.
// Only the preceding standings are restored; the final uses live gameplay.
export const FAWDA_FINAL_SEED = 1993721724;
export function restoreFawdaFinal(room) {
  assert.equal(room.roster.length, 4);
  assert.equal(room.epoch, 0);
  assert.equal(room.config.game, 'fawda');
  const settings = {mode: 'points', target: 3, rotation: 'manual', points: [5, 3, 2, 1],
    entries: ['storm_ring', 'vortex_ring', 'vortex_ring', 'storm_ring']
      .map(arena => ({game: 'fawda', arena}))};
  const tournament = new Tournament(4, settings, FAWDA_FINAL_SEED);
  const recordedScores = [[8, 2, 9, 4], [9, 2, 8, 8], [8, 8, 8, 8]];
  recordedScores.forEach((scores, index) => {
    tournament.next();
    tournament.record(index + 1, scores);
  });
  assert.deepEqual(tournament.contenders, [0, 2]);
  assert.equal(tournament.complete, false);
  room.tournament = tournament;
  room.epoch = 3;
  return tournament.view();
}

export function assertFawdaNetworkEvidence(results, checkpoint = false) {
  assert.ok(results.length >= 2);
  for (const result of results) {
    assert.ok(Number.isInteger(result.matches) && result.matches > 0);
    assert.equal(result.fawda_worlds.length, result.matches);
    assertWireState(result.fawda_worlds, results[0].fawda_worlds);
    if (!checkpoint) {
      for (const kind of ['drop', 'pickup', 'throw', 'explode']) {
        assert.equal(result.fawda_event_coverage[kind], true, `real ${kind} coverage is required`);
      }
    }
  }
  if (checkpoint) {
    assert.ok(results[0].tournament.champions.length > 0);
    assert.ok(results[0].tournament.champions.every(slot => [0, 2].includes(slot)));
    assert.deepEqual(results[0].tournament.points, [11, 5, 11, 8]);
    assert.equal(results[0].fawda_worlds[0].arena, 'storm_ring');
    assert.equal(results[0].fawda_worlds[0].seed, FAWDA_FINAL_SEED);
  }
}

function assertWireState(actual, expected, path = 'fawda_worlds') {
  if (typeof expected === 'number') {
    assert.equal(typeof actual, 'number', `${path} must agree with the host`);
    // A guest JSON-decodes and re-encodes Godot's decimal floats once more.
    // Discrete integer identities/counters remain exact; only sub-picounit
    // float serialization noise is tolerated.
    if (Number.isInteger(expected)) assert.equal(actual, expected, `${path} must agree with the host`);
    else assert.ok(Number.isFinite(actual) && Math.abs(actual - expected) <= 1e-12,
      `${path} must agree with the host`);
    return;
  }
  if (expected === null || typeof expected !== 'object') {
    assert.deepEqual(actual, expected, `${path} must agree with the host`);
    return;
  }
  assert.ok(actual !== null && typeof actual === 'object', `${path} must agree with the host`);
  assert.equal(Array.isArray(actual), Array.isArray(expected), `${path} must agree with the host`);
  assert.deepEqual(Object.keys(actual).sort(), Object.keys(expected).sort(), `${path} must agree with the host`);
  for (const key of Object.keys(expected)) assertWireState(actual[key], expected[key], `${path}.${key}`);
}
