import test from 'node:test';
import assert from 'node:assert/strict';
import {validScrapWorld} from './world-snapshots.js';

test('scrap world bounds health maximum impact position and wreck feedback by roster', () => {
  const world = {health: [100, 75.25, 0, 100], maximum: 100,
    ram: 1, position: [2, .3, -1], wrecks: [0, 0, 1, 0]};
  assert.ok(validScrapWorld(world, 4));
  for (const count of [0, 1, 2, 3, 5, 4.5, '4']) assert.equal(validScrapWorld(world, count), false);
  for (const key of Object.keys(world)) {
    const bad = structuredClone(world); delete bad[key];
    assert.equal(validScrapWorld(bad, 4), false);
  }
  for (const bad of [null, [], {...world, extra: 1}, {...world, health: []}, {...world, wrecks: []},
    {...world, position: [0, 0]}, {...world, position: [Infinity, 0, 0]}, {...world, position: [10001, 0, 0]}]) {
    assert.equal(validScrapWorld(bad, 4), false);
  }
  for (const field of ['maximum', 'ram']) {
    for (const value of [-1, Infinity, NaN, true, '1']) {
      assert.equal(validScrapWorld({...world, [field]: value}, 4), false);
    }
  }
  for (const value of [0, 1001]) assert.equal(validScrapWorld({...world, maximum: value}, 4), false);
  for (const value of [.5, 1000001]) assert.equal(validScrapWorld({...world, ram: value}, 4), false);
  for (const value of [-1, 100.01, Infinity, NaN, true, '1']) {
    assert.equal(validScrapWorld({...world, health: [value, 0, 0, 0]}, 4), false);
  }
  for (const value of [-1, .5, 2, 1000001, Infinity, NaN, true, '1']) {
    assert.equal(validScrapWorld({...world, wrecks: [value, 0, 0, 0]}, 4), false);
  }
  assert.equal(validScrapWorld({...world, wrecks: [1, 0, 1, 0]}, 4), false);
});
