import test from 'node:test';
import assert from 'node:assert/strict';
import {validBlastWorld} from './world-snapshots.js';

const make = () => ({position: [0, .9, 0], velocity: [7, 0, 0], generation: 1,
  fuse: 5, fuse_max: 5, detonated: false, explosion_sequence: 0, explosion_position: [0, 0, 0]});

test('blast world validates bounded host state and terminal detonation', () => {
  assert.ok(validBlastWorld(JSON.parse(JSON.stringify(make()))));
  assert.ok(validBlastWorld({...make(), detonated: true, fuse: 0}));
  for (const value of [null, [], {}, true, 'world']) assert.equal(validBlastWorld(value), false);
  for (const key of Object.keys(make())) {
    const data = make(); delete data[key]; assert.equal(validBlastWorld(data), false, key);
  }
  for (const key of ['position', 'velocity', 'explosion_position']) {
    for (const value of [null, [], [0, 0], [0, 0, 0, 0], [NaN, 0, 0], [true, 0, 0], [10001, 0, 0]]) {
      assert.equal(validBlastWorld({...make(), [key]: value}), false);
    }
  }
  for (const key of ['generation', 'explosion_sequence', 'fuse', 'fuse_max']) {
    for (const value of [null, true, '1', NaN, Infinity, -1, 1000001]) {
      assert.equal(validBlastWorld({...make(), [key]: value}), false);
    }
  }
  for (const changes of [{generation: .5}, {explosion_sequence: .5}, {fuse: 6},
    {fuse_max: 0}, {fuse_max: 61}, {detonated: 1}, {detonated: true}]) {
    assert.equal(validBlastWorld({...make(), ...changes}), false);
  }
});
