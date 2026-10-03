import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {validColossusWorld} from './world-snapshots.js';

const world = () => ({boss: {health: 745, phase: 0, defeated: false, position: [0, 0, 0], rotation: [0, 0, 0],
  damage: 1, strike: 1, strike_position: [6, 0, 0], strike_radius: 4},
warnings: [{id: '1', position: [-4, 0, 2], radius: 3, left: 1.2, total: 1.2}],
craters: [{id: '2', position: [6, 0, 0], radius: 3}],
arm_rotation: [0, 0, 0], fist_position: [6, 1, 0], fist_scale: [1, 1, 1], exposed: 2.4});

test('colossus world bounds poses, holes, identity and authority state', () => {
  for (const count of [2, 3, 4]) assert.ok(validColossusWorld(world(), count));
  for (const count of [1, 5, 2.5, true, '4']) assert.equal(validColossusWorld(world(), count), false);
  for (const field of Object.keys(world())) {
    const data = world(); delete data[field]; assert.equal(validColossusWorld(data, 4), false);
  }
  for (const field of Object.keys(world().boss)) {
    const data = world(); delete data.boss[field]; assert.equal(validColossusWorld(data, 4), false);
  }
  for (const [key, values] of Object.entries({health: [-1, 800.1, true, NaN, Infinity, null],
    phase: [-1, 1, .5, true], defeated: [true, 0], position: [[10001, 0, 0], [NaN, 0, 0], [0, 0]]})) {
    for (const value of values) {const data = world(); data.boss[key] = value; assert.equal(validColossusWorld(data, 4), false);}
  }
  for (const [health, phase] of [[800, 0], [528, 1], [264, 2], [0, 2]]) {
    const data = world(); Object.assign(data.boss, {health, phase, defeated: health === 0});
    assert.ok(validColossusWorld(data, 4));
  }
  for (const [key, values] of Object.entries({exposed: [-1, 2.41, true, NaN, Infinity, null],
    fist_scale: [[0, 1, 1], [1.21, 1, 1], [NaN, 1, 1], [1, 1]],
    arm_rotation: [[0, Math.PI + .1, 0], [Infinity, 0, 0]]})) {
    for (const value of values) {const data = world(); data[key] = value; assert.equal(validColossusWorld(data, 4), false);}
  }
  for (const group of ['warnings', 'craters']) {
    for (const key of Object.keys(world()[group][0])) {
      const data = world(); delete data[group][0][key]; assert.equal(validColossusWorld(data, 4), false);
    }
    for (const id of ['', '01', '-1', '1.0', 1, null]) {
      const data = world(); data[group][0].id = id; assert.equal(validColossusWorld(data, 4), false);
    }
    const extra = world(); extra[group][0].extra = 1; assert.equal(validColossusWorld(extra, 4), false);
    const duplicate = world(); duplicate[group].push({...duplicate[group][0]}); assert.equal(validColossusWorld(duplicate, 4), false);
    const data = world(); data[group] = Array.from({length: 65}, (_, i) => ({...world()[group][0], id: String(i + 10)}));
    assert.equal(validColossusWorld(data, 4), false);
  }
  const duplicate = world(); duplicate.craters[0].id = duplicate.warnings[0].id;
  assert.equal(validColossusWorld(duplicate, 4), false);
  for (const radius of [.74, 100.1, NaN, true]) {
    const data = world(); data.craters[0].radius = radius; assert.equal(validColossusWorld(data, 4), false);
  }
});

test('actual Godot colossus slam and arm hit satisfy server schema', {skip: !process.env.KRAS_COLOSSUS_WORLD_FIXTURE}, () => {
  const data = JSON.parse(readFileSync(process.env.KRAS_COLOSSUS_WORLD_FIXTURE, 'utf8'));
  assert.ok(validColossusWorld(data, 4));
  assert.equal(data.boss.health, 745);
  assert.equal(data.boss.damage, 1);
  assert.equal(data.boss.strike, 1);
  assert.equal(data.craters.length, 1);
  assert.deepEqual(data.fist_position, [6, 1, 0]);
});
