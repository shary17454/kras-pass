import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {validSovereignWorld} from './world-snapshots.js';

const world = () => ({boss: {health: 1440, phase: 0, defeated: false, position: [0, 1, 0], rotation: [0, 0, 0],
  damage: 1, strike: 0, strike_position: [0, 0, 0], strike_radius: 0},
  warnings: [{id: '1', position: [6, 0, 0], radius: 4.2, left: 1.35, total: 1.35}],
  orbs: [{id: '2', position: [0, 3.2, 0], returned: false}], shielded: false, recovery: 0, volleys: 1, returns: 0});

test('sovereign schema bounds phases, shields, recovery and visible objects', () => {
  for (const count of [2, 3, 4]) assert.ok(validSovereignWorld(world(), count));
  for (const count of [1, 5, 2.5, '4', true]) assert.equal(validSovereignWorld(world(), count), false);
  for (const key of Object.keys(world())) {
    const data = world(); delete data[key]; assert.equal(validSovereignWorld(data, 4), false);
  }
  for (const key of Object.keys(world().boss)) {
    const data = world(); delete data.boss[key]; assert.equal(validSovereignWorld(data, 4), false);
  }
  for (const [key, values] of Object.entries({health: [-1, 1500.1, true, '1440', null, NaN, Infinity],
    phase: [-1, 1, .5, true], defeated: [true, 0], damage: [-1, .5, 1000001], strike: [-1, .5, 1000001],
    strike_radius: [-1, 100.1, true], position: [[NaN, 0, 0], [10001, 0, 0]], rotation: [[0, Math.PI + .01, 0]]})) {
    for (const value of values) { const data = world(); data.boss[key] = value; assert.equal(validSovereignWorld(data, 4), false, key); }
  }
  for (const [health, phase] of [[1500, 0], [990, 1], [450, 2], [0, 2]]) {
    const data = world(); Object.assign(data.boss, {health, phase, defeated: health === 0});
    assert.ok(validSovereignWorld(data, 4)); data.shielded = true;
    assert.equal(validSovereignWorld(data, 4), phase === 1);
  }
  for (const recovery of [-1, 2.801, true, NaN, Infinity, '1', null]) {
    const data = world(); data.recovery = recovery; assert.equal(validSovereignWorld(data, 4), false);
  }
  for (const field of ['volleys', 'returns']) {
    for (const value of [-1, .5, true, NaN, Infinity, '1', null, 1000001]) {
      const data = world(); data[field] = value; assert.equal(validSovereignWorld(data, 4), false);
    }
  }
  const excessReturns = world(); excessReturns.returns = 5;
  assert.equal(validSovereignWorld(excessReturns, 4), false);
  for (const returned of [0, 1, 'false', null]) {
    const data = world(); data.orbs[0].returned = returned; assert.equal(validSovereignWorld(data, 4), false);
  }
  for (const group of ['warnings', 'orbs']) {
    for (const key of Object.keys(world()[group][0])) {
      const data = world(); delete data[group][0][key]; assert.equal(validSovereignWorld(data, 4), false);
    }
    for (const id of ['', '01', '-1', '1.0', '1000000000000000000', 1, null]) {
      const data = world(); data[group][0].id = id; assert.equal(validSovereignWorld(data, 4), false);
    }
    const extra = world(); extra[group][0].extra = 1; assert.equal(validSovereignWorld(extra, 4), false);
    const duplicate = world(); duplicate[group].push({...duplicate[group][0]}); assert.equal(validSovereignWorld(duplicate, 4), false);
    const overflow = world(); overflow[group] = Array.from({length: group === 'warnings' ? 65 : 33}, (_, i) =>
      ({...world()[group][0], id: String(i + 10)})); assert.equal(validSovereignWorld(overflow, 4), false);
  }
  const duplicate = world(); duplicate.orbs[0].id = duplicate.warnings[0].id;
  assert.equal(validSovereignWorld(duplicate, 4), false);
  for (const patch of [{left: -1}, {left: 2}, {total: 0}, {total: 61}, {radius: .24}, {radius: 101}]) {
    const data = world(); Object.assign(data.warnings[0], patch); assert.equal(validSovereignWorld(data, 4), false);
  }
  for (const data of [{...world(), extra: 1}, null, []]) assert.equal(validSovereignWorld(data, 4), false);
});

test('actual Godot sovereign capture satisfies server schema', {skip: !process.env.KRAS_SOVEREIGN_WORLD_FIXTURE}, () => {
  const data = JSON.parse(readFileSync(process.env.KRAS_SOVEREIGN_WORLD_FIXTURE, 'utf8'));
  assert.equal(data.boss.health, 1440);
  assert.equal(data.boss.damage, 1);
  assert.equal(data.orbs.length, 4);
  assert.equal(data.warnings.length, 1);
  assert.equal(data.volleys, 1);
  assert.equal(data.returns, 0);
  assert.ok(validSovereignWorld(data, 4));
});
