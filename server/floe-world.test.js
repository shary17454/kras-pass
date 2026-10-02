import test from 'node:test';
import assert from 'node:assert/strict';
import {validFloeWorld} from './world-snapshots.js';

test('floe world bounds all three platform positions and motion age', () => {
  const world = {age: 12.5, positions: [[1, -.13, 2], [3, -.13, 4], [5, -.13, 6]]};
  assert.equal(validFloeWorld(JSON.parse(JSON.stringify(world))), true);
  for (const bad of [null, [], {}, {...world, extra: 1}, {age: 0}, {positions: world.positions},
    {...world, positions: []}, {...world, positions: [...world.positions, [0, 0, 0]]}]) {
    assert.equal(validFloeWorld(bad), false);
  }
  for (const value of [-1, 3601, Infinity, NaN, '12', true]) {
    assert.equal(validFloeWorld({...world, age: value}), false);
  }
  for (const row of [[0, 0], [0, 0, 0, 0], null, 'bad', [1001, 0, 0], [Infinity, 0, 0], [NaN, 0, 0], ['1', 0, 0], [true, 0, 0]]) {
    assert.equal(validFloeWorld({...world, positions: [row, ...world.positions.slice(1)]}), false);
  }
});
