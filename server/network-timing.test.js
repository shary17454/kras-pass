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
