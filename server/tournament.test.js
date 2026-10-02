import test from 'node:test';
import assert from 'node:assert/strict';
import {Tournament} from './tournament.js';
import {higherIsBetter} from './game-scoring.js';

const settings = (overrides = {}) => ({mode: 'points', target: 3, rotation: 'random_no_repeat',
  entries: [{game: 'ring_rumble', arena: 'vortex_ring'}, {game: 'ring_rumble', arena: 'storm_ring'}],
  points: [5, 3, 2, 1], ...overrides});

test('mixed race and score rounds use their own ranking direction', () => {
  const t = new Tournament(4, settings({rotation: 'manual', entries: [
    {game: 'hurdle_dash', arena: 'hurdle_track', higher_is_better: true},
    {game: 'ring_rumble', arena: 'vortex_ring', higher_is_better: false}
  ]}), 1);
  t.next(); t.record(1, [100, 200, 300, 99999]);
  assert.deepEqual(t.points, [5, 3, 2, 1]);
  assert.deepEqual(t.cups, [1, 0, 0, 0]);
  t.next(); t.record(2, [1, 2, 3, 4]);
  assert.deepEqual(t.points, [6, 5, 5, 6]);
  t.next(); t.record(3, [100, 200, 300, 400]);
  assert.deepEqual(t.champions, [0]);
});

test('race tiebreak ignores faster spectators and awards no extra points', () => {
  const t = new Tournament(4, settings({target: 1, entries: [{game: 'hurdle_dash', arena: 'hurdle_track'}]}), 1);
  t.next(); t.record(1, [100, 100, 200, 99999]);
  assert.deepEqual(t.contenders, [0, 1]);
  const before = [...t.points];
  t.next(); t.record(2, [120, 110, 0, 0]);
  assert.deepEqual(t.champions, [1]);
  assert.deepEqual(t.points, before);
});

test('duo teammates settle a tournament tie in an individual duel', () => {
  const t = new Tournament(4, settings({target: 1, entries: [{game: 'duo_clash', arena: 'sweeper_ring'}]}), 1);
  t.next(); t.record(1, [30, 0, 30, 0]);
  assert.deepEqual(t.contenders, [0, 2]);
  const points = [...t.points], cups = [...t.cups];
  assert.deepEqual(t.next(), {game: 'duel_pit', arena: 'duel_pit'});
  t.record(2, [3, 99, 3, 99]);
  assert.deepEqual(t.next(), {game: 'duel_pit', arena: 'duel_pit'});
  t.record(3, [1, 99, 2, 99]);
  assert.deepEqual(t.champions, [2]);
  assert.deepEqual(t.points, points);
  assert.deepEqual(t.cups, cups);
  assert.deepEqual(t.lastAwards, [0, 0, 0, 0]);
  assert.deepEqual(t.entries, [{game: 'duo_clash', arena: 'sweeper_ring'}]);
});

test('catalogue ranking rejects unknown games and cannot be supplied by clients', () => {
  for (const id of ['hurdle_dash', 'kart_sprint', 'sabaq_sawarikh']) assert.equal(higherIsBetter(id), false);
  for (const id of ['ring_rumble', 'crate_relay', 'tank_arena']) assert.equal(higherIsBetter(id), true);
  for (const id of ['missing', null, undefined, '__proto__']) assert.throws(() => higherIsBetter(id), /unknown_game_scoring/);
  const t = new Tournament(4, settings({entries: [{game: 'missing', arena: 'missing'}]}), 1);
  t.next();
  assert.throws(() => t.record(1, [1, 2, 3, 4]), /unknown_game_scoring/);
  assert.equal(t.lastEpoch, -1);
  assert.deepEqual(t.points, [0, 0, 0, 0]);
});

test('race cup tournaments reward quickest finish and refuse unstarted results', () => {
  const t = new Tournament(4, settings({mode: 'cups', entries: [{game: 'hurdle_dash', arena: 'hurdle_track'}]}), 1);
  assert.throws(() => t.record(1, [100, 200, 300, 99999]), /invalid_tournament_result/);
  for (let epoch = 1; epoch <= 3; epoch++) { t.next(); t.record(epoch, [100, 200, 300, 99999]); }
  assert.deepEqual(t.cups, [3, 0, 0, 0]);
  assert.deepEqual(t.champions, [0]);
});

test('points, cup awards and results are applied once per epoch', () => {
  const t = new Tournament(4, settings(), 19);
  t.next();
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
  t.next();
  for (let i = 1; i <= 3; i++) t.record(i, [9, 9, 1, 0]);
  assert.deepEqual(t.contenders, [0, 1]);
  // Spectators cannot win the final even if a faulty host submits a higher score.
  for (let i = 4; i <= 6; i++) t.record(i, [5, 5, 99, 99]);
  assert.equal(t.complete, true); assert.deepEqual(t.champions, [0, 1]);
  assert.deepEqual(t.cups, [3, 3, 0, 0]);
});

test('a tiebreak narrows contenders without awarding extra tournament points', () => {
  const t = new Tournament(4, settings({target: 1}), 1);
  t.next();
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
