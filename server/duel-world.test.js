import test from 'node:test';
import assert from 'node:assert/strict';
import {validDuelWorld} from './world-snapshots.js';

test('duel world bounds lives and damage to the authoritative roster', () => {
  const world = {lives: [0, 1, 2, 3], damage: [0, 10.5, 100, 10000]};
  assert.equal(validDuelWorld(world, 4), true);
  for (const invalid of [null, [], {}, {...world, extra: 1}, {lives: world.lives}, {damage: world.damage}]) {
    assert.equal(validDuelWorld(invalid, 4), false);
  }
  for (const life of [-1, 4, 0.5, NaN, Infinity, '1', true]) {
    assert.equal(validDuelWorld({...world, lives: [life, 1, 2, 3]}, 4), false);
  }
  for (const value of [-1, 10001, NaN, Infinity, '1', true]) {
    assert.equal(validDuelWorld({...world, damage: [value, 0, 0, 0]}, 4), false);
  }
  assert.equal(validDuelWorld(world, 3), false);
  assert.equal(validDuelWorld({...world, damage: []}, 4), false);
  assert.equal(validDuelWorld({lives: [3, 3], damage: [0, 0]}, 2), true);
});
