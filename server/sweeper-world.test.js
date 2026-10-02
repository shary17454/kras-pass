import test from 'node:test';
import assert from 'node:assert/strict';
import {validSweeperWorld} from './world-snapshots.js';

test('sweeper world contains exactly three finite bounded arm angles', () => {
  assert.equal(validSweeperWorld({angles: [-Math.PI, 0, Math.PI]}), true);
  for (const world of [null, [], {}, {angles: []}, {angles: [0, 0]},
    {angles: [0, 0, 0, 0]}, {angles: [0, 0, 0], extra: 1}]) {
    assert.equal(validSweeperWorld(world), false);
  }
  for (const angle of [-3.142, 3.142, NaN, Infinity, '1', true, null]) {
    assert.equal(validSweeperWorld({angles: [0, angle, 0]}), false);
  }
});
