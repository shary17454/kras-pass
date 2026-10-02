import test from 'node:test';
import assert from 'node:assert/strict';
import {validKartWorld} from './world-snapshots.js';

test('kart world bounds course progress finishing rescue and per-player boost state', () => {
  const data = {elapsed: 120, times: [10000, 1000000000, 1000000000, 1000000000],
    lap: [3, 1, 0, 0], next: [1, 2, 0, 0], started: [true, true, false, false], laps: 3,
    checkpoints: 8, recovery: [-1, .5, -1, -1],
    boost: {serial: [1, 0, 0, 0], pads: Array.from({length: 4}, () => [0, 0, 0, 0])}};
  assert.ok(validKartWorld(data, 4, 8));
  assert.equal(validKartWorld(data, 4, 7), false);
  for (const count of [1, 2, 3, 5, '4', 4.5]) assert.equal(validKartWorld(data, count), false);
  for (const field of Object.keys(data)) {
    const bad = structuredClone(data); delete bad[field]; assert.equal(validKartWorld(bad, 4), false);
  }
  for (const field of ['elapsed', 'laps', 'checkpoints']) {
    for (const value of [-1, Infinity, NaN, true, '1', 1000001]) {
      const bad = structuredClone(data); bad[field] = value; assert.equal(validKartWorld(bad, 4), false);
    }
  }
  for (const field of ['times', 'lap', 'next']) {
    for (const value of [-1, .5, Infinity, NaN, true, '1', 1000000001]) {
      const bad = structuredClone(data); bad[field][0] = value; assert.equal(validKartWorld(bad, 4), false);
    }
  }
  for (const [field, value] of [['lap', 2], ['times', 12001], ['next', 8], ['started', false], ['recovery', 0]]) {
    const bad = structuredClone(data); bad[field][0] = value; assert.equal(validKartWorld(bad, 4), false);
  }
  for (const value of [-.5, 1.01, Infinity, NaN, true, '1']) {
    const bad = structuredClone(data); bad.recovery[1] = value; assert.equal(validKartWorld(bad, 4), false);
  }
  for (const field of ['times', 'lap', 'next', 'started', 'recovery']) {
    const bad = structuredClone(data); bad[field].pop(); assert.equal(validKartWorld(bad, 4), false);
  }
  for (const value of [-1, .5, 1000001, Infinity, NaN, true, '1']) {
    const bad = structuredClone(data); bad.boost.serial[0] = value; assert.equal(validKartWorld(bad, 4), false);
  }
  for (const value of [-.01, 2.01, Infinity, NaN, true, '1']) {
    const bad = structuredClone(data); bad.boost.pads[0][0] = value; assert.equal(validKartWorld(bad, 4), false);
  }
  for (const bad of [{...data, extra: 1}, {...data, boost: {}}, {...data, boost: {...data.boost, pads: []}},
    {...data, boost: {...data.boost, serial: []}}, {...data, boost: {...data.boost, extra: 1}}]) assert.equal(validKartWorld(bad, 4), false);
  const unstarted = structuredClone(data); unstarted.lap[2] = 1; assert.equal(validKartWorld(unstarted, 4), false);
});
