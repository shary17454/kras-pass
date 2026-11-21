import assert from 'node:assert/strict';

export function assertRaceStartEvidence(results) {
  assert.ok(results.length > 1, 'race start evidence requires multiple peers');
  const history = results[0].race_start_history;
  assert.ok(Array.isArray(history) && history.length > 0, 'missing race start history');
  for (const result of results) {
    assert.equal(result.race_start_history?.length, result.matches, 'every race round needs start evidence');
    assert.deepEqual(result.race_start_history, history, 'race seed and assigned lanes differ between peers');
  }
  for (const round of history) {
    assert.ok(Number.isSafeInteger(round.seed) && round.seed > 0, 'invalid race seed');
    assert.ok(typeof round.arena === 'string' && round.arena.length > 0, 'missing race arena');
    assert.equal(round.positions?.length, 4, 'race requires four authored starts');
    for (const point of round.positions) {
      assert.ok(Array.isArray(point) && point.length === 3 && point.every(Number.isFinite), 'invalid start vector');
    }
    assert.equal(new Set(round.positions.map(point => JSON.stringify(point))).size, 4, 'race starts overlap');
  }
}
