import test from 'node:test';
import assert from 'node:assert/strict';
import {validTideWorld} from './world-snapshots.js';

test('tide snapshots contain only bounded authoritative water presentation', () => {
  const world = {level: 2.5, age: 12};
  assert.equal(validTideWorld(world), true);
  for (const invalid of [null, [], {}, {...world, extra: 1}, {level: 2.5}, {age: 12}]) {
    assert.equal(validTideWorld(invalid), false);
  }
  for (const level of [-1001, 1001, NaN, Infinity, '2.5', true]) {
    assert.equal(validTideWorld({...world, level}), false);
  }
  for (const age of [-1, 3601, NaN, Infinity, '12', true]) {
    assert.equal(validTideWorld({...world, age}), false);
  }
  assert.equal(validTideWorld({level: -1000, age: 0}), true);
  assert.equal(validTideWorld({level: 1000, age: 3600}), true);
});
