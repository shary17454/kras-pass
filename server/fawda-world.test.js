import test from 'node:test';
import assert from 'node:assert/strict';
import {validFawdaWorld} from './world-snapshots.js';

test('fawda bounds visible bombs carrying and sampled event generations', () => {
  const bomb = {id: 1, position: [0, .6, 0], velocity: [0, 0, 17], fuse: 4.5, held: -1, thrower: 0};
  const data = {bombs: [bomb], carrying: [0, 0, 0, 0],
    events: Object.fromEntries(['drop', 'pickup', 'throw', 'explode'].map(kind => [kind, {sequence: 0, position: [0, 0, 0]}]))};
  assert.ok(validFawdaWorld(data, 4));
  assert.ok(validFawdaWorld({...data, bombs: []}, 4));
  for (const count of [1, 2, 3, 5, '4', 4.5]) assert.equal(validFawdaWorld(data, count), false);
  for (const field of Object.keys(data)) {
    const bad = structuredClone(data); delete bad[field]; assert.equal(validFawdaWorld(bad, 4), false);
  }
  for (const field of Object.keys(bomb)) {
    const bad = structuredClone(data); delete bad.bombs[0][field]; assert.equal(validFawdaWorld(bad, 4), false);
  }
  for (const field of ['id', 'fuse', 'held', 'thrower']) {
    for (const value of [Infinity, NaN, true, '1', 1000001, -2]) {
      const bad = structuredClone(data); bad.bombs[0][field] = value;
      assert.equal(validFawdaWorld(bad, 4), false);
    }
  }
  for (const bad of [{...data, bombs: [bomb, {...bomb}]}, {...data, bombs: Array(5).fill(bomb)},
    {...data, carrying: [0, 2, 0, 0]}, {...data, events: {}}, {...data, extra: 1},
    {...data, bombs: [{...bomb, fuse: 5.01}]}, {...data, bombs: [{...bomb, held: 4}]},
    {...data, bombs: [{...bomb, id: 0}]}, {...data, bombs: [{...bomb, id: 1.5}]},
    {...data, bombs: [{...bomb, held: 0}, {...bomb, id: 2, held: 0}]},
    {...data, bombs: [{...bomb, velocity: [0, Infinity, 0]}]},
    {...data, bombs: [{...bomb, position: [10001, 0, 0]}]}]) assert.equal(validFawdaWorld(bad, 4), false);
  for (const kind of Object.keys(data.events)) {
    const missing = structuredClone(data); delete missing.events[kind]; assert.equal(validFawdaWorld(missing, 4), false);
    for (const event of [{sequence: -1, position: [0, 0, 0]}, {sequence: .5, position: [0, 0, 0]},
      {sequence: 0, position: [0, NaN, 0]}, {sequence: 0, position: [0, 0, 0], extra: 1}]) {
      const bad = structuredClone(data); bad.events[kind] = event; assert.equal(validFawdaWorld(bad, 4), false);
    }
  }
});
