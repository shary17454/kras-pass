import test from 'node:test';
import assert from 'node:assert/strict';
import {validEchoWorld} from './world-snapshots.js';

const make = (count = 4) => ({stage: 0, serial: 1, length: 3, pad: -1, step: -1,
  flash_left: 0, progress: Array(count).fill(0), mistakes: Array(count).fill(0), finished: [],
  flash_sequence: 0, correct_sequence: 0, wrong_sequence: 0, finish_sequence: 0});

test('echo publishes only the visible cue with consistent bounded progress', () => {
  for (const count of [2, 3, 4]) {
    assert.ok(validEchoWorld(JSON.parse(JSON.stringify(make(count))), count));
    assert.equal(validEchoWorld(make(count), count - 1), false);
    const completed = make(count);
    completed.stage = 1; completed.progress[count - 1] = 3; completed.finished = [count - 1];
    assert.ok(validEchoWorld(completed, count));
  }
  for (const key of Object.keys(make())) {
    const data = make(); delete data[key]; assert.equal(validEchoWorld(data, 4), false, key);
  }
  for (const key of ['stage', 'serial', 'length', 'pad', 'step', 'flash_left',
    'flash_sequence', 'correct_sequence', 'wrong_sequence', 'finish_sequence']) {
    for (const value of [null, true, '1', NaN, Infinity, -2, 1000001]) {
      assert.equal(validEchoWorld({...make(), [key]: value}, 4), false, key);
    }
  }
  for (const changes of [{sequence: [0, 1, 2]}, {stage: 3}, {length: 0}, {length: 10},
    {pad: 5}, {pad: 0}, {step: 0}, {flash_left: .1}, {progress: [1, 0, 0, 0]},
    {stage: 1, progress: [3, 0, 0, 0]}, {stage: 1, finished: [0]},
    {stage: 1, progress: [3, 0, 0, 0], finished: [0, 0]},
    {mistakes: [false, 0, 0, 0]}, {progress: [0, 0, 0]}, {finished: [4]}]) {
    assert.equal(validEchoWorld({...make(), ...changes}, 4), false);
  }
  const cue = {...make(), pad: 2, step: 0, flash_left: .3, flash_sequence: 1};
  assert.ok(validEchoWorld(cue, 4));
  assert.equal(validEchoWorld({...cue, stage: 1}, 4), false);
  assert.equal(validEchoWorld({...cue, step: 3}, 4), false);
});
