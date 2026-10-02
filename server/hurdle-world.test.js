import test from 'node:test';
import assert from 'node:assert/strict';
import {validHurdleWorld} from './world-snapshots.js';

test('hurdle world bounds finish times by observed elapsed clock', () => {
  const make = () => ({elapsed: 12.5, times: [1000, 1200, 1250, 99999]});
  assert.ok(validHurdleWorld(make(), 4));
  for (const count of [0, 1, 5, 2.5, '4']) assert.equal(validHurdleWorld(make(), count), false);
  for (const key of ['elapsed', 'times']) {
    const data = make(); delete data[key];
    assert.equal(validHurdleWorld(data, 4), false);
  }
  for (const elapsed of [-1, 3601, NaN, Infinity, '12.5', true]) {
    assert.equal(validHurdleWorld({...make(), elapsed}, 4), false);
  }
  for (const time of [-1, 1251, .5, 360001, NaN, Infinity, '1000', true]) {
    const data = make(); data.times[0] = time;
    assert.equal(validHurdleWorld(data, 4), false);
  }
  assert.equal(validHurdleWorld({...make(), extra: 1}, 4), false);
  assert.equal(validHurdleWorld({...make(), times: [1, 2]}, 4), false);
  assert.ok(validHurdleWorld({elapsed: 0, times: [99999, 99999]}, 2));
  assert.ok(validHurdleWorld({elapsed: 3600, times: [360000, 99999]}, 2));
});
