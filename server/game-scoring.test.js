import test from 'node:test';
import assert from 'node:assert/strict';
import {validResultScore} from './game-scoring.js';
import {Tournament} from './tournament.js';

test('kart result range preserves unfinished progress and summed rounds without widening arena scores', () => {
  for (const game of ['kart_sprint', 'sabaq_sawarikh']) {
    for (const score of [0, 12000, 999999901, 1000000000]) assert.ok(validResultScore(game, score));
    for (const score of [-1, 1000000001, Infinity, NaN, true, '1', 1.5]) assert.equal(validResultScore(game, score), false);
    assert.ok(validResultScore(game, 10000000000, 10));
    assert.equal(validResultScore(game, 10000000001, 10), false);
    assert.equal(validResultScore(game, 2000000000, 1), false);
    for (const rounds of [0, 11, 1.5, true, '1']) assert.equal(validResultScore(game, 1, rounds), false);
  }
  for (const game of ['ring_rumble', 'goal_guard', 'fawda', 'tank_arena']) {
    assert.ok(validResultScore(game, -1000000));
    assert.ok(validResultScore(game, 1000000));
    assert.equal(validResultScore(game, 1000001, 10), false);
    assert.equal(validResultScore(game, 1000000000), false);
  }
  assert.ok(validResultScore('hurdle_dash', 99999));
  assert.equal(validResultScore('hurdle_dash', -1), false);
  assert.equal(validResultScore('hurdle_dash', 1000000000), false);
  assert.throws(() => validResultScore('missing', 1), /unknown_game_scoring/);
});

test('kart tournament ranks unfinished racers behind finishers using real score encoding', () => {
  const t = new Tournament(4, {mode: 'points', target: 3, rotation: 'manual',
    entries: [{game: 'kart_sprint', arena: 'circuit_loop'}], points: [5, 3, 2, 1]}, 117);
  t.next();
  assert.throws(() => t.record(1, [12000, -1, 999999901, 1000000000]), /invalid_tournament_result/);
  assert.equal(t.lastEpoch, -1);
  t.record(1, [12000, 13500, 999999901, 1000000000]);
  assert.deepEqual(t.points, [5, 3, 2, 1]);
  assert.deepEqual(t.cups, [1, 0, 0, 0]);
  assert.throws(() => t.record(1, [12000, 13500, 999999901, 1000000000]), /invalid_tournament_result/);
  for (const epoch of [2, 3]) { t.next(); t.record(epoch, [12000, 13500, 999999901, 1000000000]); }
  assert.deepEqual(t.points, [15, 9, 6, 3]);
  assert.deepEqual(t.champions, [0]);
});
