import test from 'node:test';
import assert from 'node:assert/strict';
import {validColorWorld} from './world-snapshots.js';

const make = () => ({tiles: Array.from({length: 121}, () => [0, 0, 0, 0]),
  colors: Array.from({length: 121}, (_, i) => i % 4), called: 2, stage: 0,
  timer: 2.4, call_sequence: 1, drop_sequence: 0});

test('color world requires a complete bounded quilt, call and phase', () => {
  assert.ok(validColorWorld(JSON.parse(JSON.stringify(make()))));
  const overlongWarning = make(); overlongWarning.tiles[0] = [1, 2.4, 0, 0];
  assert.equal(validColorWorld(overlongWarning), false, 'crumble timing cannot expand the color floor contract');
  for (const key of Object.keys(make())) {
    const data = make(); delete data[key]; assert.equal(validColorWorld(data), false, key);
  }
  for (const key of ['called', 'stage', 'timer', 'call_sequence', 'drop_sequence']) {
    for (const value of [null, true, '1', NaN, Infinity, -1, 1000001]) {
      assert.equal(validColorWorld({...make(), [key]: value}), false);
    }
  }
  for (const value of [null, true, '1', NaN, Infinity, -1, 4, .5]) {
    const data = make(); data.colors[0] = value; assert.equal(validColorWorld(data), false);
  }
  for (const key of ['tiles', 'colors']) {
    const data = make(); data[key].pop(); assert.equal(validColorWorld(data), false);
  }
  for (const changes of [{called: 4}, {stage: 3}, {timer: 61}, {call_sequence: .5}, {drop_sequence: .5}]) {
    assert.equal(validColorWorld({...make(), ...changes}), false);
  }
  const data = make(); data.stage = 1; data.tiles[0] = [2, .2, -1, 1];
  assert.ok(validColorWorld(data));
});
