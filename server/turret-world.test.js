import test from 'node:test';
import assert from 'node:assert/strict';
import {validTurretWorld} from './world-snapshots.js';

test('turret world bounds launch generations, live shots and host cooldown/damage', () => {
  const shot = {id: '20', generation: 1, shooter: 0, position: [2, 1, 3], direction: [1, 0, 0]};
  const world = {shots: [shot], cooldowns: [0, .9, .1, 0], damage: [0, 14, 28, 0]};
  assert.equal(validTurretWorld(JSON.parse(JSON.stringify(world)), 4), true);
  for (const count of [0, 1, 5, 2.5, '4']) assert.equal(validTurretWorld(world, count), false);
  for (const field of Object.keys(world)) {
    const bad = {...world}; delete bad[field];
    assert.equal(validTurretWorld(bad, 4), false);
  }
  for (const bad of [null, [], {...world, extra: 1}, {...world, cooldowns: []}, {...world, damage: []},
    {...world, shots: [shot, shot]}, {...world, shots: Array(129).fill(shot)}]) {
    assert.equal(validTurretWorld(bad, 4), false);
  }
  for (const field of ['cooldowns', 'damage']) {
    for (const value of [-1, Infinity, NaN, '1', true, field === 'cooldowns' ? 60.01 : 10001]) {
      assert.equal(validTurretWorld({...world, [field]: [value, 0, 0, 0]}, 4), false);
    }
  }
  for (const change of [{id: ''}, {id: '0'}, {id: '01'}, {id: '+1'}, {id: 1}, {id: '1000000000000000000'},
    {generation: 0}, {generation: 1.5}, {generation: '1'}, {generation: true}, {generation: 1000001},
    {shooter: 4}, {shooter: -1}, {shooter: true}, {shooter: 0.5}, {position: [0, 0, 10001]},
    {direction: [0, 0, 0]}, {direction: [0, 1, 0]}, {direction: [NaN, 0, 0]}, {extra: 1}]) {
    assert.equal(validTurretWorld({...world, shots: [{...shot, ...change}]}, 4), false);
  }
});
