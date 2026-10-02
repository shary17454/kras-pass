import test from 'node:test';
import assert from 'node:assert/strict';
import {validDrawWorld} from './world-snapshots.js';

const make = () => ({stage: 0, prompt: 1, order: [], locked: [false, false, false, false],
  signal_sequence: 0, correct_sequence: 0, wrong_sequence: 0, resolve_sequence: 0});

test('draw world validates bounded host decisions without hidden timing', () => {
  assert.ok(validDrawWorld(JSON.parse(JSON.stringify(make())), 4));
  for (const key of Object.keys(make())) {
    const data = make(); delete data[key]; assert.equal(validDrawWorld(data, 4), false, key);
  }
  for (const key of ['stage', 'prompt', 'signal_sequence', 'correct_sequence', 'wrong_sequence', 'resolve_sequence']) {
    for (const value of [null, true, '1', NaN, Infinity, -1, .5, 1000001]) {
      assert.equal(validDrawWorld({...make(), [key]: value}, 4), false);
    }
  }
  for (const changes of [{stage: 3}, {timer: 2}, {order: [0]}, {stage: 1, order: [0, 0]},
    {stage: 1, order: [4]}, {stage: 1, order: [true]}, {locked: [0, false, false, false]},
    {stage: 1, order: [0], locked: [true, false, false, false]}]) {
    assert.equal(validDrawWorld({...make(), ...changes}, 4), false);
  }
  for (const count of [2, 3, 4]) {
    const data = {...make(), locked: Array(count).fill(false), stage: 1, order: [count - 1]};
    assert.ok(validDrawWorld(data, count));
    assert.equal(validDrawWorld(data, count - 1), false);
  }
});
