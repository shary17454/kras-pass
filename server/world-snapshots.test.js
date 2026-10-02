import test from 'node:test';
import assert from 'node:assert/strict';
import {validGoalGuardWorld} from './world-snapshots.js';

const world = () => ({charges: [1, .5, 0, 1], balls: [{position: [0, .9, 0],
  velocity: [9, 0, 0], generation: 1, heavy: false}]});

test('goal world validates counts, finite bounds, generations and JSON types', () => {
  assert.ok(validGoalGuardWorld(JSON.parse(JSON.stringify(world())), 4));
  for (const count of [0, 1, 2, 3, 5]) assert.equal(validGoalGuardWorld(world(), count), false);
  for (const value of [null, {}, [], {balls: [], charges: [1, 1, 1, 1]}]) {
    assert.equal(validGoalGuardWorld(value, 4), false);
  }
  for (const value of [-1, 1.1, NaN, Infinity, '1', true]) {
    const data = world(); data.charges[0] = value;
    assert.equal(validGoalGuardWorld(data, 4), false);
  }
  for (const value of [-1, .5, 1000001, NaN, '1']) {
    const data = world(); data.balls[0].generation = value;
    assert.equal(validGoalGuardWorld(data, 4), false);
  }
  for (const key of ['position', 'velocity']) {
    for (const value of [[1, 2], [0, 0, 10001], [0, NaN, 0], 'xyz']) {
      const data = world(); data.balls[0][key] = value;
      assert.equal(validGoalGuardWorld(data, 4), false);
    }
  }
  const data = world(); data.balls = Array.from({length: 5}, () => world().balls[0]);
  assert.equal(validGoalGuardWorld(data, 4), false);
});
