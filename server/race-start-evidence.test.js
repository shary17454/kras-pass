import test from 'node:test';
import assert from 'node:assert/strict';
import {assertRaceStartEvidence} from './race-start-evidence.js';

function peers() {
  const history = [{seed: 6009614, arena: 'dune_circuit', positions: [[0, 1, 0], [2, 1, 0], [4, 1, 0], [6, 1, 0]]}];
  return Array.from({length: 4}, () => ({matches: 1, race_start_history: structuredClone(history)}));
}

test('accepts matching four-peer race starts', () => assertRaceStartEvidence(peers()));
test('rejects a peer lane permutation', () => {
  const results = peers();
  results[2].race_start_history[0].positions.reverse();
  assert.throws(() => assertRaceStartEvidence(results), /differ between peers/);
});
test('rejects absent round evidence', () => {
  const results = peers();
  delete results[1].race_start_history;
  assert.throws(() => assertRaceStartEvidence(results), /every race round/);
});
test('rejects duplicate positions and malformed coordinates even when all peers agree', () => {
  for (const invalid of [[0, 1, 0], [NaN, 1, 0], [1, 2]]) {
    const results = peers();
    for (const result of results) result.race_start_history[0].positions[1] = invalid;
    assert.throws(() => assertRaceStartEvidence(results));
  }
});
test('rejects missing arena, seed and incomplete round history', () => {
  for (const mutation of [round => { round.seed = 0; }, round => { round.arena = ''; }]) {
    const results = peers();
    for (const result of results) mutation(result.race_start_history[0]);
    assert.throws(() => assertRaceStartEvidence(results));
  }
  const results = peers();
  for (const result of results) result.matches = 2;
  assert.throws(() => assertRaceStartEvidence(results), /every race round/);
});
