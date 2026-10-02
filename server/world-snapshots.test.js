import test from 'node:test';
import assert from 'node:assert/strict';
import {validGoalGuardWorld, validCollectionWorld, validZoneWorld, validRelicWorld, validTagWorld, validPaintWorld, validSaboteurWorld, validMagnetWorld, validStormWorld, validSkyWorld} from './world-snapshots.js';

test('sky world bounds tilt and warning state with no arbitrary transforms', () => {
  const make = () => ({balls: [{position: [0, .9, 0], velocity: [9, 0, 0], generation: 1, heavy: false}],
    charges: [1, 1], engine: 3, bank: 1, warning: 0, tilting: 4, cycle: 9, warning_sequence: 2, tilt_sequence: 1});
  assert.ok(validSkyWorld(make(), 2));
  assert.ok(validSkyWorld({...make(), engine: -1, bank: 0, tilting: 0}, 2));
  assert.equal(validSkyWorld({...make(), engine: -1}, 2), false);
  for (const field of Object.keys(make())) {
    const data = make(); delete data[field];
    assert.equal(validSkyWorld(data, 2), false, field);
  }
  for (const [key, values] of Object.entries({engine: [-2, 4, .5, true], bank: [-1, 1.1, NaN], warning: [-1, 1.3, '1'],
    tilting: [-1, 5, Infinity], cycle: [-1, 10, null], warning_sequence: [-1, .5, true], tilt_sequence: [-1, 1000001]})) {
    for (const value of values) assert.equal(validSkyWorld({...make(), [key]: value}, 2), false, key);
  }
});

test('storm world allows two extra balls but requires turbine state and bounded events', () => {
  for (const count of [2, 3, 4]) {
    const make = () => ({balls: Array.from({length: count + 2}, () => ({position: [0, .9, 0], velocity: [9, 0, 0], generation: 3, heavy: false})),
      charges: Array(count).fill(1), rotor: 2, windup: 1.6, volley_timer: 8, warning_sequence: 2, volley_sequence: 1});
    assert.ok(validStormWorld(make(), count));
    assert.equal(validGoalGuardWorld(make(), count), false, 'ordinary court retains its original ball cap');
    const extra = make(); extra.balls.push(extra.balls[0]);
    assert.equal(validStormWorld(extra, count), false);
    for (const key of Object.keys(make())) {
      const data = make(); delete data[key];
      assert.equal(validStormWorld(data, count), false, key);
    }
    for (const [key, values] of Object.entries({rotor: [-1, 7, true, '1'], windup: [-1, 1.7, Infinity],
      volley_timer: [-1, 9, null], warning_sequence: [-1, .5, 1000001], volley_sequence: [true, '1', NaN]})) {
      for (const value of values) assert.equal(validStormWorld({...make(), [key]: value}, count), false, key);
    }
  }
});

test('magnet world maps every ball to a bounded owner and every player to a meter', () => {
  const make = () => ({balls: [{position: [0, .9, 0], velocity: [1, 0, 0], generation: 1, heavy: false}],
    charges: [1, 1], magnet_charge: [0, 1], magnet_active: [1.1, 0], held: [0]});
  assert.ok(validMagnetWorld(make(), 2));
  assert.ok(validMagnetWorld({...make(), held: [-1]}, 2));
  for (const key of ['held', 'magnet_charge', 'magnet_active']) {
    const data = make(); delete data[key];
    assert.equal(validMagnetWorld(data, 2), false);
    assert.equal(validMagnetWorld({...make(), [key]: []}, 2), false);
  }
  for (const owner of [-2, 2, .5, true, '0']) assert.equal(validMagnetWorld({...make(), held: [owner]}, 2), false);
  for (const field of ['magnet_charge', 'magnet_active']) {
    for (const value of [-1, 1.2, Infinity, '1', true]) assert.equal(validMagnetWorld({...make(), [field]: [value, 0]}, 2), false);
  }
  assert.equal(validMagnetWorld({...make(), held: [0, 1]}, 2), false);
  assert.equal(validMagnetWorld({...make(), balls: []}, 2), false);
});

test('saboteur requires bounded drone and warning state with tile ownership', () => {
  const make = () => ({owners: Array(169).fill(-1), drone: [1, 3.2, -1], rotor: 2,
    target: 168, mark: 1.5, cycle: 3.4, warning_sequence: 2, scrub_sequence: 1, scrub_position: [0, 0, 0]});
  assert.ok(validSaboteurWorld(make(), 4));
  assert.ok(validSaboteurWorld({...make(), target: -1, mark: 0}, 2));
  for (const [key, values] of Object.entries({drone: [[], [0, 0, Infinity], [0, '3', 0]],
    rotor: [-1, 7, true], target: [-2, 169, 1.5, '1'], mark: [-1, 2, true], cycle: [-1, 4, null],
    warning_sequence: [-1, .5, true, 1000001], scrub_sequence: [-1, '1', Infinity], scrub_position: [[0], [0, NaN, 0]]})) {
    for (const value of values) assert.equal(validSaboteurWorld({...make(), [key]: value}, 4), false, key);
  }
  for (const key of Object.keys(make())) {
    const data = make(); delete data[key];
    assert.equal(validSaboteurWorld(data, 4), false, key);
  }
  assert.equal(validSaboteurWorld({...make(), target: -1}, 4), false);
  assert.equal(validSaboteurWorld({...make(), owners: Array(169).fill(4)}, 4), false);
});

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
