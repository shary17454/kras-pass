import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {validArmedRaceWorld} from './world-snapshots.js';

const fixture = () => ({race: {elapsed: 0, times: Array(4).fill(1000000000), lap: [0, 0, 0, 0],
  next: [0, 0, 0, 0], started: Array(4).fill(false), laps: 3, checkpoints: 64,
  recovery: Array(4).fill(-1), boost: {serial: [0, 0, 0, 0], pads: Array.from({length: 4}, () => [0, 0, 0, 0])}},
held: [1, 2, 3, 4], shields: [0, 0, 0, 2], crates: Array.from({length: 20}, () => ({cooldown: 0, rotation: 0})),
bombs: [{id: '12', position: [0, 1, 0], owner: 0, arm: .55, life: 9}],
shots: [{id: '13', generation: 1, position: [0, 1, 0], direction: [1, 0, 0], shooter: 1}],
events: Object.fromEntries(['pickup', 'boost', 'shield', 'drop', 'explode', 'hit', 'block', 'respawn']
  .map(kind => [kind, {sequence: 0, position: [0, 0, 0]}]))});

test('armed race world bounds inventory hazards and inherited progress', () => {
  const data = fixture();
  assert.ok(validArmedRaceWorld(data, 4, 64));
  assert.equal(validArmedRaceWorld(data, 4, 63), false);
  for (const field of Object.keys(data)) {
    const bad = structuredClone(data); delete bad[field]; assert.equal(validArmedRaceWorld(bad, 4), false);
  }
  for (const field of ['held', 'shields']) {
    const bad = structuredClone(data); bad[field].pop(); assert.equal(validArmedRaceWorld(bad, 4), false);
    for (const value of [-1, true, '1', Infinity, NaN, 1000000]) {
      const bad = structuredClone(data); bad[field][0] = value; assert.equal(validArmedRaceWorld(bad, 4), false);
    }
  }
  for (const field of ['life', 'arm', 'owner']) {
    for (const value of [true, '1', Infinity, NaN, 1000000]) {
      const bad = structuredClone(data); bad.bombs[0][field] = value; assert.equal(validArmedRaceWorld(bad, 4), false);
    }
  }
  for (const [field, value] of [['life', 0], ['arm', -9.01], ['owner', -1], ['owner', 4]]) {
    const bad = structuredClone(data); bad.bombs[0][field] = value; assert.equal(validArmedRaceWorld(bad, 4), false);
  }
  const duplicate = structuredClone(data); duplicate.bombs.push({...duplicate.bombs[0]});
  assert.equal(validArmedRaceWorld(duplicate, 4), false);
  const oversize = structuredClone(data); oversize.bombs = Array.from({length: 65}, (_, i) => ({...data.bombs[0], id: String(i + 1)}));
  assert.equal(validArmedRaceWorld(oversize, 4), false);
  for (const field of ['cooldown', 'rotation']) {
    for (const value of [-100, true, '1', Infinity, NaN, 100]) {
      const bad = structuredClone(data); bad.crates[0][field] = value; assert.equal(validArmedRaceWorld(bad, 4), false);
    }
  }
  const shots = structuredClone(data); shots.shots[0].direction = [0, 0, 0];
  assert.equal(validArmedRaceWorld(shots, 4), false);
  for (const kind of Object.keys(data.events)) {
    const missing = structuredClone(data); delete missing.events[kind]; assert.equal(validArmedRaceWorld(missing, 4), false);
    for (const value of [-1, .5, true, '1', Infinity, NaN, 1000001]) {
      const bad = structuredClone(data); bad.events[kind].sequence = value;
      assert.equal(validArmedRaceWorld(bad, 4), false);
    }
    const bad = structuredClone(data); bad.events[kind].position[0] = 10001;
    assert.equal(validArmedRaceWorld(bad, 4), false);
  }
});

test('actual Godot armed-race capture satisfies server schema', {skip: !process.env.KRAS_ARMED_WORLD_FIXTURE}, () => {
  const data = JSON.parse(readFileSync(process.env.KRAS_ARMED_WORLD_FIXTURE, 'utf8'));
  assert.ok(validArmedRaceWorld(data, 4, data.race.checkpoints));
  assert.equal(data.bombs.length, 1);
  assert.equal(data.shots.length, 1);
  assert.ok(data.held[0] > 0);
  assert.equal(data.events.pickup.sequence, 1);
  assert.equal(data.events.drop.sequence, 1);
});
