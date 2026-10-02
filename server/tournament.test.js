import test from 'node:test';
import assert from 'node:assert/strict';
import {Tournament} from './tournament.js';

const settings = (overrides = {}) => ({mode: 'points', target: 3, rotation: 'random_no_repeat',
  entries: [{game: 'ring_rumble', arena: 'vortex_ring'}, {game: 'ring_rumble', arena: 'storm_ring'}],
  points: [5, 3, 2, 1], ...overrides});

test('points, cup awards and results are applied once per epoch', () => {
  const t = new Tournament(4, settings(), 19);
  t.record(1, [8, 6, 4, 2]);
  assert.deepEqual(t.points, [5, 3, 2, 1]);
  assert.deepEqual(t.cups, [1, 0, 0, 0]);
  assert.throws(() => t.record(1, [8, 6, 4, 2]), /invalid_tournament_result/);
  t.record(2, [8, 6, 4, 2]); t.record(3, [8, 6, 4, 2]);
  assert.equal(t.complete, true); assert.deepEqual(t.champions, [0]);
  assert.throws(() => t.next(), /tournament_complete/);
});

test('cup target, tied finalists and bounded shared championship', () => {
  const t = new Tournament(4, settings({mode: 'cups', target: 3}), 19);
  for (let i = 1; i <= 3; i++) t.record(i, [9, 9, 1, 0]);
  assert.deepEqual(t.contenders, [0, 1]);
  // Spectators cannot win the final even if a faulty host submits a higher score.
  for (let i = 4; i <= 6; i++) t.record(i, [5, 5, 99, 99]);
  assert.equal(t.complete, true); assert.deepEqual(t.champions, [0, 1]);
  assert.deepEqual(t.cups, [3, 3, 0, 0]);
});

test('a tiebreak narrows contenders without awarding extra tournament points', () => {
  const t = new Tournament(4, settings({target: 1}), 1);
  t.record(1, [4, 4, 1, 0]);
  assert.deepEqual(t.points, [4, 4, 2, 1]);
  t.record(2, [1, 2, 99, 99]);
  assert.deepEqual(t.champions, [1]);
  assert.deepEqual(t.points, [4, 4, 2, 1]);
});

test('seeded rotation exhausts each bag without repetition', () => {
  const a = new Tournament(4, settings(), 17), b = new Tournament(4, settings(), 17);
  const order = Array.from({length: 10}, () => a.next());
  assert.deepEqual(order, Array.from({length: 10}, () => b.next()));
  for (let i = 0; i < 10; i += 2) assert.notEqual(order[i].arena, order[i + 1].arena);
});

test('tournament view cannot mutate authoritative accounting', () => {
  const t = new Tournament(4, settings(), 1);
  t.view().points[0] = 900;
  assert.equal(t.points[0], 0);
  assert.throws(() => t.record(1, [NaN]), /invalid_tournament_result/);
  assert.equal(t.lastEpoch, -1);
});
