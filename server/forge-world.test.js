import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {validForgeWorld} from './world-snapshots.js';

const world = () => ({boss: {health: 780, phase: 0, defeated: false, position: [0, 1, 0], rotation: [0, 0, 0],
  damage: 1, strike: 1, strike_position: [2, 0, 0], strike_radius: 3.4}, intake: [Math.PI / 2, 0, 0],
  warnings: [{id: '1', position: [2, 0, 0], radius: 3.4, left: .5, total: 1.3}],
  crates: [{id: '2', position: [5, .7, 0]}], slag: [{id: '3', position: [4, 1, 0], life: 6, by: 0}]});

test('forge schema rejects incomplete or inconsistent boss and object presentation', () => {
  for (const count of [2, 3, 4]) assert.ok(validForgeWorld(world(), count));
  for (const count of [1, 5, 2.5, '4', true]) assert.equal(validForgeWorld(world(), count), false);
  for (const key of Object.keys(world())) {
    const data = world(); delete data[key]; assert.equal(validForgeWorld(data, 4), false);
  }
  for (const key of Object.keys(world().boss)) {
    const data = world(); delete data.boss[key]; assert.equal(validForgeWorld(data, 4), false);
  }
  for (const [key, bad] of Object.entries({health: [-1, 900.1, true, '900', null, NaN, Infinity],
    phase: [-1, 1, .5, true], defeated: [true, 0, 'false'], damage: [-1, .5, 1000001], strike: [-1, .5, 1000001],
    strike_radius: [-1, 100.1, true], position: [[NaN, 0, 0], [10001, 0, 0]], rotation: [[0, Math.PI + .01, 0]]})) {
    for (const value of bad) { const data = world(); data.boss[key] = value; assert.equal(validForgeWorld(data, 4), false, key); }
  }
  for (const [health, phase] of [[900, 0], [594, 1], [297, 2], [0, 2]]) {
    const data = world(); Object.assign(data.boss, {health, phase, defeated: health === 0}); assert.ok(validForgeWorld(data, 4));
  }
  for (const group of ['warnings', 'crates', 'slag']) {
    for (const id of ['', '01', '-1', '1.0', '1000000000000000000', 1, null]) {
      const data = world(); data[group][0].id = id; assert.equal(validForgeWorld(data, 4), false);
    }
    for (const key of Object.keys(world()[group][0])) {
      const data = world(); delete data[group][0][key]; assert.equal(validForgeWorld(data, 4), false);
    }
    const extra = world(); extra[group][0].extra = 1; assert.equal(validForgeWorld(extra, 4), false);
    const duplicate = world(); duplicate[group].push({...duplicate[group][0]}); assert.equal(validForgeWorld(duplicate, 4), false);
    const overflow = world(); overflow[group] = Array.from({length: group === 'warnings' ? 65 : 97}, (_, i) =>
      ({...world()[group][0], id: String(i + 10)})); assert.equal(validForgeWorld(overflow, 4), false);
  }
  const duplicate = world(); duplicate.slag[0].id = duplicate.crates[0].id; assert.equal(validForgeWorld(duplicate, 4), false);
  for (const patch of [{left: -1}, {left: 2}, {total: 0}, {total: 61}, {radius: .24}, {radius: 101}]) {
    const data = world(); Object.assign(data.warnings[0], patch); assert.equal(validForgeWorld(data, 4), false);
  }
  for (const patch of [{life: 0}, {life: 6.01}, {by: -1}, {by: 4}, {by: true}]) {
    const data = world(); Object.assign(data.slag[0], patch); assert.equal(validForgeWorld(data, 4), false);
  }
  for (const data of [{...world(), extra: 1}, {...world(), intake: [0, 0, Infinity]}, null, []])
    assert.equal(validForgeWorld(data, 4), false);
});

test('actual Godot forge capture satisfies server schema', {skip: !process.env.KRAS_FORGE_WORLD_FIXTURE}, () => {
  const data = JSON.parse(readFileSync(process.env.KRAS_FORGE_WORLD_FIXTURE, 'utf8'));
  assert.equal(data.boss.health, 780);
  assert.equal(data.boss.damage, 1);
  assert.equal(data.boss.strike, 1);
  assert.equal(data.crates.length, 1);
  assert.equal(data.slag.length, 1);
  assert.equal(data.warnings.length, 1);
  assert.ok(validForgeWorld(data, 4));
});
