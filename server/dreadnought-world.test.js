import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {validDreadnoughtWorld} from './world-snapshots.js';

const world = () => ({boss: {health: 1055, phase: 0, defeated: false, position: [0, 1, 0], rotation: [0, 0, 0],
  damage: 1, strike: 0, strike_position: [0, 0, 0], strike_radius: 0},
  warnings: [{id: '1', position: [6, 0, 0], radius: 2.6, left: 1.3, total: 1.3}],
  mines: [{id: '2', position: [5, .25, 0], armed: 1}], shots: [{id: '3', position: [5, 2, 0], direction: [0, 0, -1]}]});

test('dreadnought schema bounds boss state and every visible world object', () => {
  for (const count of [2, 3, 4]) assert.ok(validDreadnoughtWorld(world(), count));
  for (const count of [1, 5, 2.5, '4', true]) assert.equal(validDreadnoughtWorld(world(), count), false);
  for (const key of Object.keys(world())) {
    const data = world(); delete data[key]; assert.equal(validDreadnoughtWorld(data, 4), false);
  }
  for (const key of Object.keys(world().boss)) {
    const data = world(); delete data.boss[key]; assert.equal(validDreadnoughtWorld(data, 4), false);
  }
  for (const [key, bad] of Object.entries({health: [-1, 1100.1, true, '1055', null, NaN, Infinity],
    phase: [-1, 1, .5, true], defeated: [true, 0], damage: [-1, .5, 1000001], strike: [-1, .5, 1000001],
    strike_radius: [-1, 100.1, true], position: [[NaN, 0, 0], [10001, 0, 0]], rotation: [[0, Math.PI + .01, 0]]})) {
    for (const value of bad) { const data = world(); data.boss[key] = value; assert.equal(validDreadnoughtWorld(data, 4), false, key); }
  }
  for (const [health, phase] of [[1100, 0], [770, 1], [385, 2], [0, 2]]) {
    const data = world(); Object.assign(data.boss, {health, phase, defeated: health === 0}); assert.ok(validDreadnoughtWorld(data, 4));
  }
  for (const group of ['warnings', 'mines', 'shots']) {
    for (const id of ['', '01', '-1', '1.0', '1000000000000000000', 1, null]) {
      const data = world(); data[group][0].id = id; assert.equal(validDreadnoughtWorld(data, 4), false);
    }
    for (const key of Object.keys(world()[group][0])) {
      const data = world(); delete data[group][0][key]; assert.equal(validDreadnoughtWorld(data, 4), false);
    }
    const extra = world(); extra[group][0].extra = 1; assert.equal(validDreadnoughtWorld(extra, 4), false);
    const duplicate = world(); duplicate[group].push({...duplicate[group][0]}); assert.equal(validDreadnoughtWorld(duplicate, 4), false);
    const overflow = world(); overflow[group] = Array.from({length: group === 'mines' ? 97 : 65}, (_, i) =>
      ({...world()[group][0], id: String(i + 10)})); assert.equal(validDreadnoughtWorld(overflow, 4), false);
  }
  for (const armed of [-1, 1.01, true, NaN]) {
    const data = world(); data.mines[0].armed = armed; assert.equal(validDreadnoughtWorld(data, 4), false);
  }
  for (const direction of [[0, 0, 0], [2, 0, 0], [NaN, 0, 0]]) {
    const data = world(); data.shots[0].direction = direction; assert.equal(validDreadnoughtWorld(data, 4), false);
  }
  const duplicate = world(); duplicate.mines[0].id = duplicate.shots[0].id;
  assert.equal(validDreadnoughtWorld(duplicate, 4), false);
  for (const patch of [{left: -1}, {left: 2}, {total: 0}, {total: 61}, {radius: .24}, {radius: 101}]) {
    const data = world(); Object.assign(data.warnings[0], patch); assert.equal(validDreadnoughtWorld(data, 4), false);
  }
  for (const data of [{...world(), extra: 1}, null, []]) assert.equal(validDreadnoughtWorld(data, 4), false);
});

test('actual Godot dreadnought capture satisfies server schema', {skip: !process.env.KRAS_DREADNOUGHT_WORLD_FIXTURE}, () => {
  const data = JSON.parse(readFileSync(process.env.KRAS_DREADNOUGHT_WORLD_FIXTURE, 'utf8'));
  assert.equal(data.boss.health, 1055);
  assert.equal(data.boss.damage, 1);
  for (const group of ['warnings', 'mines', 'shots']) assert.equal(data[group].length, 1);
  assert.ok(validDreadnoughtWorld(data, 4));
});
