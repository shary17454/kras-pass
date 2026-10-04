import test from 'node:test';
import assert from 'node:assert/strict';
import {validCrateWorld} from './world-snapshots.js';

const make = () => ({crates: [{id: '10', kind: 0, position: [1, .75, 3]}], shots: [],
  break_sequence: 0, break_kind: 0, break_position: [0, 0, 0],
  break_events: Array.from({length: 5}, () => ({sequence: 0, position: [0, 0, 0]}))});
const shot = () => ({id: '20', position: [2, 1, 3], direction: [1, 0, 0], shooter: 0});

test('crate worlds bound identities, types, feedback and lab-only projectiles', () => {
  for (const lab of [false, true]) {
    assert.ok(validCrateWorld(make(), 4, lab));
    for (const key of Object.keys(make())) {
      const data = make(); delete data[key]; assert.equal(validCrateWorld(data, 4, lab), false);
    }
    for (const value of [null, true, '1', NaN, Infinity, -1, .5, 1000001]) {
      assert.equal(validCrateWorld({...make(), break_sequence: value}, 4, lab), false);
    }
    for (const value of ['', '0', '01', '+1', '-1', '1.0', 1, '1000000000000000000']) {
      const data = make(); data.crates[0].id = value;
      assert.equal(validCrateWorld(data, 4, lab), false);
    }
    const duplicate = make(); duplicate.crates.push({...duplicate.crates[0]});
    assert.equal(validCrateWorld(duplicate, 4, lab), false);
    for (const changes of [{extra: 1}, {break_position: [NaN, 0, 0]}, {break_kind: 5},
      {crates: Array(15).fill(make().crates[0])}, {shots: Array(129).fill(shot())}]) {
      assert.equal(validCrateWorld({...make(), ...changes}, 4, lab), false);
    }
  }
  const data = make(); data.shots = [shot()]; data.crates[0].kind = 2;
  assert.ok(validCrateWorld(JSON.parse(JSON.stringify(data)), 4, true));
  assert.equal(validCrateWorld(data, 4, false), false);
  for (const changes of [{id: '10'}, {direction: [0, 0, 0]}, {direction: [0, 1, 0]},
    {shooter: 4}, {shooter: true}, {direction: [Infinity, 0, 0]}, {position: [0, 0, 10001]}, {extra: 1}]) {
    assert.equal(validCrateWorld({...data, shots: [{...shot(), ...changes}]}, 4, true), false);
  }
});

test('crate event lanes retain mixed kinds and reject incoherent or excessive history', () => {
  const data = make();
  data.break_sequence = 2;
  data.break_position = [4, 1, 5];
  data.break_events[0] = {sequence: 1, position: [4, 1, 5]};
  data.break_events[3] = {sequence: 1, position: [2, 1, 3]};
  assert.ok(validCrateWorld(JSON.parse(JSON.stringify(data)), 4, true));
  assert.equal(validCrateWorld(data, 4, false), false);
  for (const value of [null, {}, [], data.break_events.slice(0, 4), [...data.break_events, data.break_events[0]]]) {
    assert.equal(validCrateWorld({...data, break_events: value}, 4, true), false);
  }
  for (const changes of [{sequence: -1}, {sequence: true}, {sequence: Infinity},
    {sequence: .5}, {sequence: 1000001}, {position: [0, NaN, 0]}, {extra: 1}]) {
    const copy = structuredClone(data);
    Object.assign(copy.break_events[0], changes);
    assert.equal(validCrateWorld(copy, 4, true), false);
  }
  assert.equal(validCrateWorld({...data, break_sequence: 3}, 4, true), false);
  assert.equal(validCrateWorld({...data, break_position: [0, 0, 0]}, 4, true), false);
  const missingLatest = make();
  missingLatest.break_sequence = 1;
  missingLatest.break_events[1].sequence = 1;
  assert.equal(validCrateWorld(missingLatest, 4, true), false);
});
