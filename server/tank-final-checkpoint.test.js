import test from 'node:test';
import assert from 'node:assert/strict';
import {restoreTankFinal, TANK_FINAL_SEED} from './tank-final-checkpoint.js';

test('recorded tank results restore the actual host versus bot final', () => {
  const room = {roster: [0, 1, 2, 3], epoch: 0, config: {game: 'tank_arena'}};
  const restored = restoreTankFinal(room);
  assert.equal(TANK_FINAL_SEED, 15775892);
  assert.equal(room.epoch, 3);
  assert.equal(restored.round, 3);
  assert.deepEqual(restored.points, [10, 7, 10, 7]);
  assert.deepEqual(restored.contenders, [0, 2]);
  assert.deepEqual(room.tournament.next(), {game: 'tank_arena', arena: 'tank_oasis'});
  assert.throws(() => room.tournament.record(3, [500, 100, 500, 200]), /invalid_tournament_result/);
  room.tournament.record(4, [475, 100, 500, 200]);
  assert.deepEqual(room.tournament.champions, [2]);
  assert.equal(room.tournament.complete, true);
  assert.deepEqual(room.tournament.points, restored.points);
});

test('tank checkpoint refuses unrelated, started or partial rooms', () => {
  const room = {roster: [0, 1, 2, 3], epoch: 0, config: {game: 'tank_arena'}};
  assert.throws(() => restoreTankFinal({...room, epoch: 1}));
  assert.throws(() => restoreTankFinal({...room, roster: [0, 1]}));
  assert.throws(() => restoreTankFinal({...room, config: {game: 'fawda'}}));
});

test('a no-hit final remains tied rather than inventing a champion', () => {
  const room = {roster: [0, 1, 2, 3], epoch: 0, config: {game: 'tank_arena'}};
  const before = restoreTankFinal(room);
  room.tournament.next();
  room.tournament.record(4, [500, 100, 500, 200]);
  assert.equal(room.tournament.complete, false);
  assert.deepEqual(room.tournament.contenders, [0, 2]);
  assert.deepEqual(room.tournament.points, before.points);
  assert.equal(room.tournament.tieAttempts, 1);
});
