import test from 'node:test';
import assert from 'node:assert/strict';
import {validTankWorld, validTurretWorld} from './world-snapshots.js';

test('tank world validates all shell kinds, ammunition, armor, fuses and five crates', () => {
  const world = {
    shots: [{id: '20', generation: 1, shooter: 0, position: [2, 1, 3], direction: [1, 0, 0], kind: 6, fuse: .5}],
    cooldowns: [0, .75, 0, 0], damage: [0, 0, 0, 0],
    armor: [100, 75, 40, 0], ammo: [0, 6, 3, 1], shell_types: [0, 1, 6, 2],
    crates: Array.from({length: 5}, () => ({cooldown: 0, rotation: 0})),
  };
  assert.equal(validTankWorld(JSON.parse(JSON.stringify(world)), 4), true);
  for (const count of [0, 1, 5, 2.5, '4']) assert.equal(validTankWorld(world, count), false);
  for (const field of Object.keys(world)) {
    const bad = structuredClone(world); delete bad[field];
    assert.equal(validTankWorld(bad, 4), false);
  }
  for (const field of ['armor', 'ammo', 'shell_types']) {
    for (const value of [-1, 101, Infinity, NaN, '1', true, 1.5]) {
      const bad = structuredClone(world); bad[field][0] = value;
      assert.equal(validTankWorld(bad, 4), false);
    }
    const bad = structuredClone(world); bad[field].pop();
    assert.equal(validTankWorld(bad, 4), false);
  }
  for (const [ammo, kind] of [[1, 0], [0, 1], [4, 2], [7, 1]]) {
    const bad = structuredClone(world); bad.ammo[0] = ammo; bad.shell_types[0] = kind;
    assert.equal(validTankWorld(bad, 4), false);
  }
  for (let kind = 0; kind <= 6; kind++) {
    const good = structuredClone(world); good.shots[0].kind = kind; good.shots[0].fuse = -1;
    assert.equal(validTankWorld(good, 4), true);
  }
  for (const change of [{kind: 7}, {kind: '1'}, {kind: true}, {kind: 1.5}, {fuse: -0.5},
    {fuse: 2.01}, {fuse: Infinity}, {fuse: NaN}, {fuse: '1'}, {kind: 0, fuse: 0},
    {generation: 0}, {id: '01'}, {direction: [0, 0, 0]}, {shooter: 4}, {extra: 1}]) {
    const bad = structuredClone(world); Object.assign(bad.shots[0], change);
    assert.equal(validTankWorld(bad, 4), false);
  }
  const guided = structuredClone(world); guided.shots[0].direction = [0, .6, .8];
  assert.equal(validTankWorld(guided, 4), true, 'guidance follows terrain height');
  const {kind, fuse, ...base} = guided.shots[0];
  assert.equal(validTurretWorld({shots: [base], damage: world.damage, cooldowns: world.cooldowns}, 4), false,
    'shared helper does not weaken turret horizontal validation');
  for (const change of [{cooldown: -1}, {cooldown: 9.01}, {cooldown: '0'}, {rotation: Math.PI + .001},
    {rotation: NaN}, {extra: 1}]) {
    const bad = structuredClone(world); Object.assign(bad.crates[0], change);
    assert.equal(validTankWorld(bad, 4), false);
  }
  for (const field of ['shots', 'crates']) {
    const bad = structuredClone(world); bad[field].push(bad[field][0]);
    assert.equal(validTankWorld(bad, 4), false);
  }
  const bad = structuredClone(world); bad.extra = 1;
  assert.equal(validTankWorld(bad, 4), false);
  bad.shots = Array(129).fill(world.shots[0]); delete bad.extra;
  assert.equal(validTankWorld(bad, 4), false);
});
