import test from 'node:test';
import assert from 'node:assert/strict';
import {NetworkTiming} from './network-timing.js';

test('network timing separates handler work from scheduler stalls without payloads', () => {
  let time = 0, user = 0;
  const timing = new NetworkTiming({now: () => time, cpu: () => ({user, system: 0})});
  timing.recordOperation('snapshot', 2);
  timing.recordOperation('snapshot', 3);
  timing.recordOperation('result', 1);
  timing.recordOperation('invalid secret', 99);
  timing.recordOperation('snapshot', NaN);
  time = 100; user = 1000;
  assert.equal(timing.sample([]), null);
  time = 1200; user = 6000;
  const rooms = [{state: 'playing', epoch: 1, matchConfig: {game: 'base_siege', arena: 'iron_flats'},
    token: 'secret', code: 'secret', players: ['secret']}];
  const stall = timing.sample(rooms);
  assert.equal(stall.delayMs, 1000);
  assert.equal(stall.cpuMs, 5);
  assert.deepEqual(stall.rooms, [{state: 'playing', epoch: 1, game: 'base_siege', arena: 'iron_flats'}]);
  assert.deepEqual(timing.report().operations.snapshot, {count: 2, totalMs: 5, maxMs: 3});
  assert.ok(!JSON.stringify(timing.report()).includes('secret'));
});

test('network timing bounds samples while retaining the worst later stall', () => {
  let time = 0;
  const timing = new NetworkTiming({now: () => time, cpu: () => ({user: 0, system: 0})});
  for (let i = 0; i < 60; i++) { time += 300; timing.sample([]); }
  time += 6000; timing.sample([]);
  assert.equal(timing.report().stalls.length, 50);
  assert.equal(timing.report().worstStall.delayMs, 5900);
});

test('operation CPU stays associated with its actual worst wall sample', () => {
  const timing = new NetworkTiming();
  timing.recordOperation('snapshot', 2);
  timing.recordOperation('snapshot', 408, 0.5);
  timing.recordOperation('snapshot', 3, 1);
  let row = timing.report().operations.snapshot;
  assert.equal(row.count, 3);
  assert.equal(row.maxMs, 408);
  assert.deepEqual(row.cpu, {count: 2, totalMs: 1.5, maxMs: 1, atMaxWallMs: 0.5});
  timing.recordOperation('snapshot', 500, -1);
  row = timing.report().operations.snapshot;
  assert.equal(row.cpu.count, 2);
  assert.equal(row.cpu.atMaxWallMs, null);
  timing.recordOperation('result', 1, NaN);
  assert.equal(timing.report().operations.result.cpu, undefined);
});

test('diagnostic operation cardinality is bounded without dropping known samples', () => {
  const timing = new NetworkTiming();
  timing.recordOperation('snapshot', 1, 0.1);
  for (let i = 0; i < 100; i++) {
    const op = `op_${String.fromCharCode(97 + Math.floor(i / 26))}${String.fromCharCode(97 + i % 26)}`;
    timing.recordOperation(op, 1, 0.1);
  }
  assert.equal(Object.keys(timing.report().operations).length, 32);
  timing.recordOperation('snapshot', 2, 0.2);
  assert.equal(timing.report().operations.snapshot.count, 2);
  assert.equal(timing.report().operations.snapshot.cpu.count, 2);
});
