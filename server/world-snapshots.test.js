import test from 'node:test';
import assert from 'node:assert/strict';
import {validGoalGuardWorld, validCollectionWorld, validZoneWorld, validRelicWorld, validTagWorld, validPaintWorld} from './world-snapshots.js';

test('paint grid requires complete bounded tile ownership', () => {
  const owners = Array(169).fill(-1);
  assert.ok(validPaintWorld({owners}, 4));
  for (const owner of [-2, 4, .5, '1', true, Infinity]) {
    assert.equal(validPaintWorld({owners: [owner, ...owners.slice(1)]}, 4), false);
  }
  for (const size of [0, 168, 170, 1000]) assert.equal(validPaintWorld({owners: Array(size).fill(0)}, 4), false);
  assert.equal(validPaintWorld({owners: Array(169).fill(3)}, 3), false);
  assert.ok(validPaintWorld({owners: Array(169).fill(3)}, 4));
});

test('tag world bounds role and handover grace without coercing JSON types', () => {
  assert.ok(validTagWorld({hunter: 3, grace: 1.3}, 4));
  assert.ok(validTagWorld({hunter: -1, grace: 0}, 2));
  assert.equal(validTagWorld({hunter: 3, grace: 1}, 3), false);
  for (const hunter of [-2, 4, .5, true, '1', NaN]) assert.equal(validTagWorld({hunter, grace: 1}, 4), false);
  for (const grace of [-1, 2, true, '1', Infinity]) assert.equal(validTagWorld({hunter: 0, grace}, 4), false);
  for (const data of [null, {}, [], {hunter: 0}, {grace: 1}]) assert.equal(validTagWorld(data, 4), false);
});

test('relic ownership and loose-item representation are mutually exclusive', () => {
  const item = {id: '123', kind: 'gem', position: [0, 1, 0], rotation: 0, color: 'ffd15cff', size: .6, value: 1};
  assert.ok(validRelicWorld({holder: -1, items: [item]}, 4));
  assert.ok(validRelicWorld({holder: -1, items: []}, 4));
  assert.ok(validRelicWorld({holder: 3, items: []}, 4));
  for (const count of [1, 2.5, 5, '4', NaN]) assert.equal(validRelicWorld({holder: -1, items: []}, count), false);
  assert.equal(validRelicWorld({holder: 3, items: []}, 3), false);
  assert.equal(validRelicWorld({holder: 0, items: [item]}, 4), false);
  assert.equal(validRelicWorld({holder: -1, items: [item, {...item, id: '124'}]}, 4), false);
  for (const holder of [-2, 4, .5, '1', true, Infinity]) {
    assert.equal(validRelicWorld({holder, items: []}, 4), false);
  }
  for (const data of [null, [], {}, {holder: -1}, {holder: 0, items: [{...item, kind: 'crate'}]}]) {
    assert.equal(validRelicWorld(data, 4), false);
  }
});

test('zone world rejects malformed or unbounded presentation state', () => {
  const make = () => ({position: [3, 0, -4], radius: 3.4, color: 'ff5f6dff'});
  assert.ok(validZoneWorld(JSON.parse(JSON.stringify(make()))));
  for (const data of [null, [], {}, {position: [0, 0, 0]}]) assert.equal(validZoneWorld(data), false);
  for (const [key, values] of Object.entries({position: [[1, 2], [NaN, 0, 0], [10001, 0, 0]],
    radius: [0, 11, Infinity, '3', true], color: ['red', '0xffffff', 'zzzzzzzz']})) {
    for (const value of values) assert.equal(validZoneWorld({...make(), [key]: value}), false, key);
  }
});

const world = () => ({charges: [1, .5, 0, 1], balls: [{position: [0, .9, 0],
  velocity: [9, 0, 0], generation: 1, heavy: false}]});

test('goal world validates counts, finite bounds, generations and JSON types', () => {
  assert.ok(validGoalGuardWorld(JSON.parse(JSON.stringify(world())), 4));
  for (const count of [0, 1, 2, 3, 5]) assert.equal(validGoalGuardWorld(world(), count), false);
  for (const value of [null, {}, [], {balls: [], charges: [1, 1, 1, 1]}]) {
    assert.equal(validGoalGuardWorld(value, 4), false);
  }
  for (const value of [-1, 1.1, NaN, Infinity, '1', true]) {
    const data = world(); data.charges[0] = value;
    assert.equal(validGoalGuardWorld(data, 4), false);
  }
  for (const value of [-1, .5, 1000001, NaN, '1']) {
    const data = world(); data.balls[0].generation = value;
    assert.equal(validGoalGuardWorld(data, 4), false);
  }
  for (const key of ['position', 'velocity']) {
    for (const value of [[1, 2], [0, 0, 10001], [0, NaN, 0], 'xyz']) {
      const data = world(); data.balls[0][key] = value;
      assert.equal(validGoalGuardWorld(data, 4), false);
    }
  }
  const data = world(); data.balls = Array.from({length: 5}, () => world().balls[0]);
  assert.equal(validGoalGuardWorld(data, 4), false);
});

test('collection worlds bound identities, visual fields, carrying and payload size', () => {
  const make = () => ({carrying: [0, 3, 0, 8], items: [{id: '1234', kind: 'gem', position: [1, 1.1, 2],
    rotation: 0, color: 'ff00ffff', size: .42, value: 1}]});
  assert.ok(validCollectionWorld(make(), 4, 'gem'));
  assert.equal(validCollectionWorld(make(), 4, 'star'), false);
  for (const id of ['', '-1', '01', '+1', ' 1', '9223372036854775808']) {
    const data = make(); data.items[0].id = id;
    assert.equal(validCollectionWorld(data, 4, 'gem'), false);
  }
  for (const [key, values] of Object.entries({position: [[1, 2], [NaN, 0, 0], [10001, 0, 0]],
    rotation: [Infinity, 3.2], color: ['red', 'zzzzzzzz'], size: [0, 4, '.4'], value: [0, .5, 1000001]})) {
    for (const value of values) {
      const data = make(); data.items[0][key] = value;
      assert.equal(validCollectionWorld(data, 4, 'gem'), false, key);
    }
  }
  for (const value of [-1, 9, .5, '1']) {
    const data = make(); data.carrying[0] = value;
    assert.equal(validCollectionWorld(data, 4, 'gem'), false);
  }
  const data = make(); data.items.push({...data.items[0]});
  assert.equal(validCollectionWorld(data, 4, 'gem'), false);
  data.items = Array.from({length: 256}, (_, i) => ({...make().items[0], id: String(i + 1)}));
  assert.ok(validCollectionWorld(data, 4, 'gem'));
  data.items.push({...make().items[0], id: '257'});
  assert.equal(validCollectionWorld(data, 4, 'gem'), false);
  data.items = [];
  assert.ok(validCollectionWorld(data, 4, 'gem'));
});
