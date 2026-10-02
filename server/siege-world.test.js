import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {validSiegeWorld} from './world-snapshots.js';

const world = count => ({bases: Array.from({length: count}, () =>
  ({health: 100, cooldown: 0, rotation: 0, height: 1.35, hits: 0}))});

test('siege schema bounds roster-ordered base health animation and feedback', () => {
  for (const count of [2, 3, 4]) assert.ok(validSiegeWorld(world(count), count));
  for (const count of [0, 1, 5, 2.5, '4', true]) assert.equal(validSiegeWorld(world(4), count), false);
  const fields = {health: [-1, 100.001], cooldown: [-.001, .301], rotation: [-Math.PI - .01, Math.PI + .01],
    height: [1.278, 1.422], hits: [-1, .5, 1000001]};
  for (const [field, invalid] of Object.entries(fields)) {
    for (const value of [...invalid, true, '1', null, NaN, Infinity]) {
      const data = world(4); data.bases[0][field] = value;
      assert.equal(validSiegeWorld(data, 4), false, `${field}: ${value}`);
    }
    const data = world(4); delete data.bases[0][field]; assert.equal(validSiegeWorld(data, 4), false);
  }
  for (const data of [null, [], {}, {bases: []}, {...world(4), extra: true}]) assert.equal(validSiegeWorld(data, 4), false);
  const extra = world(4); extra.bases[0].extra = true; assert.equal(validSiegeWorld(extra, 4), false);
  const lost = world(4); lost.bases.pop(); assert.equal(validSiegeWorld(lost, 4), false);
  const destroyed = world(4); destroyed.bases[1] = {health: 0, cooldown: .3, rotation: Math.PI, height: 1.28, hits: 1000000};
  assert.ok(validSiegeWorld(destroyed, 4));
});

test('actual Godot siege capture satisfies server schema', {skip: !process.env.KRAS_SIEGE_WORLD_FIXTURE}, () => {
  const data = JSON.parse(readFileSync(process.env.KRAS_SIEGE_WORLD_FIXTURE, 'utf8'));
  assert.equal(data.bases.length, 4);
  assert.equal(data.bases[1].health, 78);
  assert.equal(data.bases[1].hits, 2);
  assert.ok(validSiegeWorld(data, 4));
});
