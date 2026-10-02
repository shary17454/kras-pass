import test from 'node:test';
import assert from 'node:assert/strict';
import {validBumperWorld} from './world-snapshots.js';

test('bumper world bounds five visual scales and hit serials', () => {
  const world = {scales: Array.from({length: 5}, () => [1.25, .8, 1.25]), hits: [0, 1, 2, 3, 1000000]};
  assert.equal(validBumperWorld(world), true);
  for (const bad of [null, [], {}, {...world, extra: 1}, {...world, hits: []}, {...world, scales: world.scales.slice(1)}]) {
    assert.equal(validBumperWorld(bad), false);
  }
  for (const value of [-1, .5, 1000001, NaN, Infinity, '1', true]) {
    assert.equal(validBumperWorld({...world, hits: [value, 0, 0, 0, 0]}), false);
  }
  for (const scale of [[1, 1], [1, 1, 1, 1], [.9, 1, 1], [1, .7, 1], [1, 1.1, 1], [1, 1, 1.3], ['1', 1, 1], [NaN, 1, 1], [Infinity, 1, 1], [true, 1, 1]]) {
    assert.equal(validBumperWorld({...world, scales: [scale, ...world.scales.slice(1)]}), false);
  }
});
