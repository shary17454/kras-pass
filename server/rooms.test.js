import test from 'node:test';
import assert from 'node:assert/strict';
import {createServer} from 'node:http';
import {once} from 'node:events';
import {WebSocket} from 'ws';
import {Rooms} from './rooms.js';
import {attachMultiplayer} from './multiplayer.js';

const snapshot = () => ({phase: 4, round: 0, countdown: 0, radius: 10, time: 50,
  scores: [0, 1, 0, 0], alive: [true, true, true, true],
  fighters: Array.from({length: 4}, () => ({position: [0, 0, 0], velocity: [0, 0, 0],
    facing: [0, 0, 1], health: 100, dash: 0, attack: 0, stun: 0, visible: true, alive: true}))});

test('wall clock adjustments cannot expire a live room', () => {
  const original = Date.now;
  let wall = original();
  Date.now = () => wall;
  try {
    const rooms = new Rooms();
    const client = rooms.connect(() => {});
    rooms.handle(client, {v: 1, op: 'create', capacity: 4, public: true});
    wall += 86400000;
    rooms.sweep();
    assert.equal(rooms.rooms.size, 1);
    wall -= 172800000;
    rooms.sweep();
    assert.equal(rooms.rooms.size, 1);
  } finally { Date.now = original; }
});

function fixture() {
  let now = 1000;
  const rooms = new Rooms({now: () => now});
  const client = () => {
    const messages = [];
    const c = rooms.connect(m => messages.push(structuredClone(m)));
    return {c, messages, send: m => rooms.handle(c, {v: 1, ...m}), last: op => messages.findLast(m => m.op === op)};
  };
  const host = client(); host.send({op: 'create', capacity: 4, public: true, name: 'Host'});
  return {rooms, host, client, advance: ms => { now += ms; rooms.sweep(); }};
}

test('closed-room inputs drain briefly without granting authority to detached clients', () => {
  const {rooms, host, client, advance} = fixture();
  const guest = client(); guest.send({op: 'join', code: host.c.room.code});
  const outsider = client();
  host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true});
  host.send({op: 'start'});
  const epoch = host.last('start').epoch;
  host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
  const input = {op: 'input', epoch, sequence: 1, axes: [0, 0, 0, 0], bits: 4};
  guest.send(input);
  const messageCount = host.messages.length;
  host.send({op: 'leave'});
  assert.equal(rooms.rooms.size, 0);
  assert.equal(rooms.sessions.size, 0);
  const afterClose = host.messages.length;
  assert.ok(afterClose > messageCount);
  assert.doesNotThrow(() => guest.send({...input, sequence: 2}));
  assert.equal(host.messages.length, afterClose, 'late input is discarded, not forwarded');
  assert.throws(() => outsider.send(input), /not_joined/);
  assert.throws(() => guest.send({...input, epoch: epoch + 1}), /not_joined/);
  assert.throws(() => guest.send({...input, axes: [NaN, 0, 0, 0]}), /not_joined/);
  assert.throws(() => guest.send({op: 'snapshot', epoch, tick: 1, data: snapshot()}), /not_joined/);
  assert.throws(() => guest.send({op: 'result', epoch, scores: [0, 0, 0, 0]}), /not_joined/);
  advance(1000);
  assert.throws(() => guest.send({...input, sequence: 3}), /not_joined/);
});

test('joining another room clears the closed-room input drain allowance', () => {
  const {host, client} = fixture();
  const guest = client(); guest.send({op: 'join', code: host.c.room.code});
  host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true});
  host.send({op: 'start'});
  const epoch = host.last('start').epoch;
  host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
  host.send({op: 'leave'});
  guest.send({op: 'create', capacity: 4, public: true, name: 'New Host'});
  assert.throws(() => guest.send({op: 'input', epoch, sequence: 1, axes: [0, 0, 0, 0], bits: 4}), /invalid_state/);
  guest.send({op: 'leave'});
  assert.throws(() => guest.send({op: 'input', epoch, sequence: 2, axes: [0, 0, 0, 0], bits: 4}), /not_joined/);
});

test('goal guard enforces its arena and complete world snapshots', () => {
  const {host, client} = fixture();
  const guest = client(); guest.send({op: 'join', code: host.c.room.code});
  const config = {game: 'goal_guard', arena: 'quad_court', rounds: 2, bots: true, difficulty: 1};
  assert.throws(() => host.send({op: 'configure', config: {...config, arena: 'vortex_ring'}}), /invalid_config/);
  host.send({op: 'configure', config});
  host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true});
  host.send({op: 'start'});
  const epoch = host.last('start').epoch;
  host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
  assert.throws(() => host.send({op: 'snapshot', epoch, tick: 1, data: snapshot()}), /invalid_snapshot/);
  const data = snapshot();
  data.world = {charges: [1, 1, 1, 1], balls: [{position: [0, .9, 0], velocity: [9, 0, 0], heavy: false, generation: 1}]};
  host.send({op: 'snapshot', epoch, tick: 1, data});
  assert.deepEqual(guest.last('snapshot').data.world, data.world);
  data.world.balls[0].generation = -1;
  assert.throws(() => host.send({op: 'snapshot', epoch, tick: 2, data}), /invalid_snapshot/);
  assert.equal(guest.last('snapshot').tick, 1);
});

test('blast room rejects missing fuse, invalid arena and non-host snapshots', () => {
  const {host, client} = fixture();
  const guest = client(); guest.send({op: 'join', code: host.c.room.code});
  const config = {game: 'blast_ball', arena: 'ember_pit', rounds: 2, bots: true, difficulty: 1};
  assert.throws(() => host.send({op: 'configure', config: {...config, arena: 'quad_court'}}), /invalid_config/);
  host.send({op: 'configure', config});
  host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true}); host.send({op: 'start'});
  const epoch = host.last('start').epoch;
  host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
  const data = snapshot();
  assert.throws(() => host.send({op: 'snapshot', epoch, tick: 1, data}), /invalid_snapshot/);
  data.world = {position: [0, .9, 0], velocity: [7, 0, 0], generation: 2, fuse: 4, fuse_max: 5,
    detonated: false, explosion_sequence: 1, explosion_position: [2, .9, 3]};
  assert.throws(() => guest.send({op: 'snapshot', epoch, tick: 1, data}));
  host.send({op: 'snapshot', epoch, tick: 1, data});
  assert.deepEqual(guest.last('snapshot').data.world, data.world);
  delete data.world.fuse;
  assert.throws(() => host.send({op: 'snapshot', epoch, tick: 2, data}), /invalid_snapshot/);
  assert.equal(guest.last('snapshot').tick, 1);
});

test('echo room accepts only host public cues and consistent progress', () => {
  const {host, client} = fixture();
  const guest = client(); guest.send({op: 'join', code: host.c.room.code});
  const config = {game: 'symbol_echo', arena: 'echo_hall', rounds: 2, bots: true, difficulty: 1};
  assert.throws(() => host.send({op: 'configure', config: {...config, arena: 'draw_stage'}}), /invalid_config/);
  host.send({op: 'configure', config});
  host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true}); host.send({op: 'start'});
  const epoch = host.last('start').epoch;
  host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
  const data = snapshot();
  assert.throws(() => host.send({op: 'snapshot', epoch, tick: 1, data}), /invalid_snapshot/);
  data.world = {stage: 0, serial: 1, length: 3, pad: 2, step: 0, flash_left: .2,
    progress: [0, 0, 0, 0], mistakes: [0, 0, 0, 0], finished: [],
    flash_sequence: 1, correct_sequence: 0, wrong_sequence: 0, finish_sequence: 0};
  assert.throws(() => guest.send({op: 'snapshot', epoch, tick: 1, data}));
  host.send({op: 'snapshot', epoch, tick: 1, data});
  assert.deepEqual(guest.last('snapshot').data.world, data.world);
  data.world.sequence = [2, 3, 4];
  assert.throws(() => host.send({op: 'snapshot', epoch, tick: 2, data}), /invalid_snapshot/);
  assert.equal(guest.last('snapshot').tick, 1);
});

test('crate rooms require their arena and host snapshots with game-specific weapons', () => {
  for (const game of ['crate_smash', 'lab_crates']) {
    const {host, client} = fixture();
    const guest = client(); guest.send({op: 'join', code: host.c.room.code});
    const config = {game, arena: 'crate_yard', rounds: 2, bots: true, difficulty: 1};
    assert.throws(() => host.send({op: 'configure', config: {...config, arena: 'echo_hall'}}), /invalid_config/);
    host.send({op: 'configure', config});
    host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true}); host.send({op: 'start'});
    const epoch = host.last('start').epoch;
    host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
    const data = snapshot();
    assert.throws(() => host.send({op: 'snapshot', epoch, tick: 1, data}), /invalid_snapshot/);
    data.world = {crates: [{id: '10', kind: 0, position: [1, .75, 3]}], shots: [],
      break_sequence: 0, break_kind: 0, break_position: [0, 0, 0]};
    assert.throws(() => guest.send({op: 'snapshot', epoch, tick: 1, data}));
    host.send({op: 'snapshot', epoch, tick: 1, data});
    assert.deepEqual(guest.last('snapshot').data.world, data.world);
    data.world.shots = [{id: '20', position: [2, 1, 3], direction: [1, 0, 0], shooter: 0}];
    if (game === 'lab_crates') {
      host.send({op: 'snapshot', epoch, tick: 2, data});
      data.world.shots[0].shooter = 4;
      assert.throws(() => host.send({op: 'snapshot', epoch, tick: 3, data}), /invalid_snapshot/);
    } else {
      assert.throws(() => host.send({op: 'snapshot', epoch, tick: 2, data}), /invalid_snapshot/);
    }
  }
});

test('draw room relays host decisions and rejects hidden timing or client authority', () => {
  const {host, client} = fixture();
  const guest = client(); guest.send({op: 'join', code: host.c.room.code});
  const config = {game: 'quick_draw', arena: 'draw_stage', rounds: 2, bots: true, difficulty: 1};
  assert.throws(() => host.send({op: 'configure', config: {...config, arena: 'quad_court'}}), /invalid_config/);
  host.send({op: 'configure', config});
  host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true}); host.send({op: 'start'});
  const epoch = host.last('start').epoch;
  host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
  const data = snapshot();
  assert.throws(() => host.send({op: 'snapshot', epoch, tick: 1, data}), /invalid_snapshot/);
  data.world = {stage: 1, prompt: 2, order: [0], locked: [false, false, false, false],
    signal_sequence: 2, correct_sequence: 1, wrong_sequence: 0, resolve_sequence: 1};
  assert.throws(() => guest.send({op: 'snapshot', epoch, tick: 1, data}));
  host.send({op: 'snapshot', epoch, tick: 1, data});
  assert.deepEqual(guest.last('snapshot').data.world, data.world);
  data.world.timer = 2;
  assert.throws(() => host.send({op: 'snapshot', epoch, tick: 2, data}), /invalid_snapshot/);
  assert.equal(guest.last('snapshot').tick, 1);
});

test('color room requires host-owned palette and called color', () => {
  const {host, client} = fixture();
  const guest = client(); guest.send({op: 'join', code: host.c.room.code});
  const config = {game: 'color_stand', arena: 'color_floor', rounds: 2, bots: true, difficulty: 1};
  assert.throws(() => host.send({op: 'configure', config: {...config, arena: 'paint_grid'}}), /invalid_config/);
  host.send({op: 'configure', config});
  host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true}); host.send({op: 'start'});
  const epoch = host.last('start').epoch;
  host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
  const data = snapshot();
  assert.throws(() => host.send({op: 'snapshot', epoch, tick: 1, data}), /invalid_snapshot/);
  data.world = {tiles: Array.from({length: 121}, () => [0, 0, 0, 0]), colors: Array(121).fill(2),
    called: 2, stage: 0, timer: 2.4, call_sequence: 1, drop_sequence: 0};
  assert.throws(() => guest.send({op: 'snapshot', epoch, tick: 1, data}));
  host.send({op: 'snapshot', epoch, tick: 1, data});
  assert.deepEqual(guest.last('snapshot').data.world, data.world);
  delete data.world.called;
  assert.throws(() => host.send({op: 'snapshot', epoch, tick: 2, data}), /invalid_snapshot/);
  assert.equal(guest.last('snapshot').tick, 1);
});

test('crumble room relays only complete host-owned floor state', () => {
  const {host, client} = fixture();
  const guest = client(); guest.send({op: 'join', code: host.c.room.code});
  const config = {game: 'crumble_court', arena: 'crumble_court', rounds: 2, bots: true, difficulty: 1};
  assert.throws(() => host.send({op: 'configure', config: {...config, arena: 'paint_grid'}}), /invalid_config/);
  host.send({op: 'configure', config});
  host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true}); host.send({op: 'start'});
  const epoch = host.last('start').epoch;
  host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
  const data = snapshot();
  assert.throws(() => host.send({op: 'snapshot', epoch, tick: 1, data}), /invalid_snapshot/);
  data.world = {tiles: Array.from({length: 113}, () => [0, 0, 0, 0])};
  host.send({op: 'snapshot', epoch, tick: 1, data});
  assert.deepEqual(guest.last('snapshot').data.world, data.world);
  data.world.tiles.pop();
  assert.throws(() => host.send({op: 'snapshot', epoch, tick: 2, data}), /invalid_snapshot/);
  assert.equal(guest.last('snapshot').tick, 1);
});

test('sky room requires bounded bank and warning state', () => {
  const {host, client} = fixture();
  const guest = client(); guest.send({op: 'join', code: host.c.room.code});
  host.send({op: 'configure', config: {game: 'sky_court', arena: 'quad_court', rounds: 2, bots: true, difficulty: 1}});
  host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true}); host.send({op: 'start'});
  const epoch = host.last('start').epoch;
  host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
  const data = snapshot(); data.world = {charges: [1, 1, 1, 1], balls: [{position: [0, .9, 0], velocity: [9, 0, 0], heavy: false, generation: 1}]};
  assert.throws(() => host.send({op: 'snapshot', epoch, tick: 1, data}), /invalid_snapshot/);
  Object.assign(data.world, {engine: 2, bank: .5, warning: 0, tilting: 3.7, cycle: 9, warning_sequence: 1, tilt_sequence: 1});
  host.send({op: 'snapshot', epoch, tick: 1, data});
  assert.deepEqual(guest.last('snapshot').data.world, data.world);
  data.world.bank = 1.1;
  assert.throws(() => host.send({op: 'snapshot', epoch, tick: 2, data}), /invalid_snapshot/);
  assert.equal(guest.last('snapshot').tick, 1);
});

test('storm room relays turbine state and rejects missing or excessive state', () => {
  const {host, client} = fixture();
  const guest = client(); guest.send({op: 'join', code: host.c.room.code});
  host.send({op: 'configure', config: {game: 'storm_heart', arena: 'quad_court', rounds: 2, bots: true, difficulty: 1}});
  host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true}); host.send({op: 'start'});
  const epoch = host.last('start').epoch;
  host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
  const data = snapshot(); data.world = {charges: [1, 1, 1, 1], balls: Array.from({length: 6}, () => ({position: [0, .9, 0], velocity: [0, 0, 0], heavy: false, generation: 1}))};
  assert.throws(() => host.send({op: 'snapshot', epoch, tick: 1, data}), /invalid_snapshot/);
  Object.assign(data.world, {rotor: 2, windup: 1.6, volley_timer: 8, warning_sequence: 3, volley_sequence: 2});
  host.send({op: 'snapshot', epoch, tick: 1, data});
  assert.deepEqual(guest.last('snapshot').data.world, data.world);
  data.world.balls.push(data.world.balls[0]);
  assert.throws(() => host.send({op: 'snapshot', epoch, tick: 2, data}), /invalid_snapshot/);
  assert.equal(guest.last('snapshot').tick, 1);
});

test('magnet rooms require both ball state and bounded magnet ownership', () => {
  const {host, client} = fixture();
  const guest = client(); guest.send({op: 'join', code: host.c.room.code});
  host.send({op: 'configure', config: {game: 'magnet_court', arena: 'quad_court', rounds: 2, bots: true, difficulty: 1}});
  host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true}); host.send({op: 'start'});
  const epoch = host.last('start').epoch;
  host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
  const data = snapshot(); data.world = {charges: [1, 1, 1, 1], balls: [{position: [0, .9, 0], velocity: [0, 0, 0], heavy: false, generation: 1}]};
  assert.throws(() => host.send({op: 'snapshot', epoch, tick: 1, data}), /invalid_snapshot/);
  Object.assign(data.world, {magnet_charge: [0, 1, 1, 1], magnet_active: [1.1, 0, 0, 0], held: [0]});
  host.send({op: 'snapshot', epoch, tick: 1, data});
  assert.deepEqual(guest.last('snapshot').data.world, data.world);
  data.world.held[0] = 4;
  assert.throws(() => host.send({op: 'snapshot', epoch, tick: 2, data}), /invalid_snapshot/);
  assert.equal(guest.last('snapshot').tick, 1);
});

test('zone hold requires host capture state and rejects malformed updates', () => {
  const {host, client} = fixture();
  const guest = client(); guest.send({op: 'join', code: host.c.room.code});
  host.send({op: 'configure', config: {game: 'zone_hold', arena: 'dune_ring', rounds: 2, bots: true, difficulty: 1}});
  host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true}); host.send({op: 'start'});
  const epoch = host.last('start').epoch;
  host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
  assert.throws(() => host.send({op: 'snapshot', epoch, tick: 1, data: snapshot()}), /invalid_snapshot/);
  const data = snapshot(); data.world = {position: [4, 0, 3], radius: 2.04, color: 'ff5f6dff'};
  host.send({op: 'snapshot', epoch, tick: 1, data});
  assert.deepEqual(guest.last('snapshot').data.world, data.world);
  data.world.radius = 0;
  assert.throws(() => host.send({op: 'snapshot', epoch, tick: 2, data}), /invalid_snapshot/);
  assert.equal(guest.last('snapshot').tick, 1);
});

test('relic match requires world state and bounds carrier to roster', () => {
  const {host, client} = fixture();
  const guest = client(); guest.send({op: 'join', code: host.c.room.code});
  host.send({op: 'configure', config: {game: 'relic_hold', arena: 'star_meadow', rounds: 2, bots: true, difficulty: 1}});
  host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true}); host.send({op: 'start'});
  const epoch = host.last('start').epoch;
  host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
  assert.throws(() => host.send({op: 'snapshot', epoch, tick: 1, data: snapshot()}), /invalid_snapshot/);
  const data = snapshot(); data.world = {holder: 1, items: []};
  host.send({op: 'snapshot', epoch, tick: 1, data});
  assert.deepEqual(guest.last('snapshot').data.world, data.world);
  data.world.holder = 4;
  assert.throws(() => host.send({op: 'snapshot', epoch, tick: 2, data}), /invalid_snapshot/);
  assert.equal(guest.last('snapshot').tick, 1);
});

test('tag match requires bounded authoritative hunter role', () => {
  const {host, client} = fixture();
  const guest = client(); guest.send({op: 'join', code: host.c.room.code});
  host.send({op: 'configure', config: {game: 'tag_hunt', arena: 'star_meadow', rounds: 2, bots: true, difficulty: 1}});
  host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true}); host.send({op: 'start'});
  const epoch = host.last('start').epoch;
  host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
  assert.throws(() => host.send({op: 'snapshot', epoch, tick: 1, data: snapshot()}), /invalid_snapshot/);
  const data = snapshot(); data.world = {hunter: 1, grace: 1.3};
  host.send({op: 'snapshot', epoch, tick: 1, data});
  assert.deepEqual(guest.last('snapshot').data.world, data.world);
  data.world.hunter = 4;
  assert.throws(() => host.send({op: 'snapshot', epoch, tick: 2, data}), /invalid_snapshot/);
  assert.equal(guest.last('snapshot').tick, 1);
});

test('paint games relay complete ownership and reject invalid grids', () => {
  for (const game of ['paint_grid', 'mnatiq', 'mukharrib']) {
    const {host, client} = fixture();
    const guest = client(); guest.send({op: 'join', code: host.c.room.code});
    const config = {game, arena: 'paint_grid', rounds: 2, bots: true, difficulty: 1};
    assert.throws(() => host.send({op: 'configure', config: {...config, arena: 'star_meadow'}}), /invalid_config/);
    host.send({op: 'configure', config});
    host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true}); host.send({op: 'start'});
    const epoch = host.last('start').epoch;
    host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
    assert.throws(() => host.send({op: 'snapshot', epoch, tick: 1, data: snapshot()}), /invalid_snapshot/);
    const data = snapshot(); data.world = {owners: Array(169).fill(-1)};
    data.world.owners[168] = 3;
    if (game === 'mukharrib') {
      assert.throws(() => host.send({op: 'snapshot', epoch, tick: 1, data}), /invalid_snapshot/);
      Object.assign(data.world, {drone: [0, 3.2, 0], rotor: 0, target: -1, mark: 0, cycle: 3.4,
        warning_sequence: 0, scrub_sequence: 0, scrub_position: [0, 0, 0]});
    }
    host.send({op: 'snapshot', epoch, tick: 1, data});
    assert.deepEqual(guest.last('snapshot').data.world, data.world);
    for (const owners of [Array(168).fill(-1), Array(170).fill(-1), Array(169).fill(4), Array(169).fill(0.5)]) {
      assert.throws(() => host.send({op: 'snapshot', epoch, tick: 2, data: {...data, world: {...data.world, owners}}}), /invalid_snapshot/);
      assert.equal(guest.last('snapshot').tick, 1);
    }
  }
});

test('collection games reject absent or wrong-kind world state', () => {
  for (const [game, arena, kind] of [['gem_grab', 'gem_hollow', 'gem'], ['star_rush', 'star_meadow', 'star']]) {
    const {host, client} = fixture();
    const guest = client(); guest.send({op: 'join', code: host.c.room.code});
    host.send({op: 'configure', config: {game, arena, rounds: 2, bots: true, difficulty: 1}});
    host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true}); host.send({op: 'start'});
    const epoch = host.last('start').epoch;
    host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
    assert.throws(() => host.send({op: 'snapshot', epoch, tick: 1, data: snapshot()}), /invalid_snapshot/);
    const data = snapshot(); data.world = {items: [{id: '1', kind, position: [0, 1, 0],
      rotation: 0, color: 'ffffffff', size: .4, value: 1}], carrying: [0, 1, 0, 0]};
    host.send({op: 'snapshot', epoch, tick: 1, data});
    assert.deepEqual(guest.last('snapshot').data.world, data.world);
    data.world.items[0].kind = 'crate';
    assert.throws(() => host.send({op: 'snapshot', epoch, tick: 2, data}), /invalid_snapshot/);
  }
});

test('relay room accepts only host cargo with its authored arena', () => {
  const {host, client} = fixture();
  const guest = client(); guest.send({op: 'join', code: host.c.room.code});
  const config = {game: 'crate_relay', arena: 'relay_docks', rounds: 2, bots: true, difficulty: 1};
  assert.throws(() => host.send({op: 'configure', config: {...config, arena: 'crate_yard'}}), /invalid_config/);
  host.send({op: 'configure', config});
  host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true}); host.send({op: 'start'});
  const epoch = host.last('start').epoch;
  host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
  const data = snapshot();
  data.world = {items: [{id: '1', kind: 'crate', position: [0, 1, 0], rotation: 0,
    color: 'ffc46bff', size: .42, value: 1}], carrying: [0, 1, 0, 0]};
  assert.throws(() => guest.send({op: 'snapshot', epoch, tick: 1, data}), /host_only/);
  host.send({op: 'snapshot', epoch, tick: 1, data});
  assert.deepEqual(guest.last('snapshot').data.world, data.world);
  for (const world of [undefined, {...data.world, carrying: [0, 2, 0, 0]},
    {...data.world, items: [{...data.world.items[0], kind: 'star'}]}]) {
    assert.throws(() => host.send({op: 'snapshot', epoch, tick: 2, data: {...data, world}}), /invalid_snapshot/);
    assert.equal(guest.last('snapshot').tick, 1);
  }
});

test('bumper rooms require five bounded host-owned barriers', () => {
  const {host, client} = fixture();
  const guest = client(); guest.send({op: 'join', code: host.c.room.code});
  const config = {game: 'bumper_bowl', arena: 'bumper_bowl', rounds: 1, bots: true, difficulty: 1};
  assert.throws(() => host.send({op: 'configure', config: {...config, arena: 'duel_pit'}}), /invalid_config/);
  host.send({op: 'configure', config});
  host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true}); host.send({op: 'start'});
  const epoch = host.last('start').epoch;
  host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
  const data = snapshot(); data.world = {scales: Array.from({length: 5}, () => [1, 1, 1]), hits: [0, 1, 2, 3, 4]};
  assert.throws(() => guest.send({op: 'snapshot', epoch, tick: 1, data}), /host_only/);
  host.send({op: 'snapshot', epoch, tick: 1, data});
  assert.deepEqual(guest.last('snapshot').data.world, data.world);
  for (const world of [undefined, {...data.world, scales: []}, {...data.world, hits: [-1, 1, 2, 3, 4]}]) {
    assert.throws(() => host.send({op: 'snapshot', epoch, tick: 2, data: {...data, world}}), /invalid_snapshot/);
    assert.equal(guest.last('snapshot').tick, 1);
  }
});

test('duo rooms bind team snapshots to each authored arena', () => {
  for (const arena of ['sweeper_ring', 'bumper_bowl']) {
    const {host, client} = fixture();
    const guest = client(); guest.send({op: 'join', code: host.c.room.code});
    const config = {game: 'duo_clash', arena, rounds: 1, bots: true, difficulty: 1};
    assert.throws(() => host.send({op: 'configure', config: {...config, arena: 'duel_pit'}}), /invalid_config/);
    host.send({op: 'configure', config});
    host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true}); host.send({op: 'start'});
    const epoch = host.last('start').epoch;
    host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
    const data = snapshot();
    data.world = {lives: [2, 1, 0, 2], damage: [0, 10, 0, 0], team_scores: [2, 4], arena,
      hazards: arena === 'sweeper_ring' ? {angles: [0, 1, -1]}
        : {scales: Array.from({length: 5}, () => [1, 1, 1]), hits: [0, 1, 2, 3, 4]}};
    assert.throws(() => guest.send({op: 'snapshot', epoch, tick: 1, data}), /host_only/);
    host.send({op: 'snapshot', epoch, tick: 1, data});
    assert.deepEqual(guest.last('snapshot').data.world, data.world);
    for (const world of [undefined, {...data.world, team_scores: [-1, 0]}, {...data.world, hazards: {}},
      {...data.world, arena: arena === 'sweeper_ring' ? 'bumper_bowl' : 'sweeper_ring'}]) {
      assert.throws(() => host.send({op: 'snapshot', epoch, tick: 2, data: {...data, world}}), /invalid_snapshot/);
      assert.equal(guest.last('snapshot').tick, 1);
    }
  }
});

test('duel rooms validate host lives and damage', () => {
  const {host, client} = fixture();
  const guest = client(); guest.send({op: 'join', code: host.c.room.code});
  const config = {game: 'duel_pit', arena: 'duel_pit', rounds: 1, bots: true, difficulty: 1};
  assert.throws(() => host.send({op: 'configure', config: {...config, arena: 'sweeper_ring'}}), /invalid_config/);
  host.send({op: 'configure', config});
  host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true}); host.send({op: 'start'});
  const epoch = host.last('start').epoch;
  host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
  const data = snapshot(); data.world = {lives: [3, 2, 1, 0], damage: [0, 9, 18, 0]};
  assert.throws(() => guest.send({op: 'snapshot', epoch, tick: 1, data}), /host_only/);
  host.send({op: 'snapshot', epoch, tick: 1, data});
  assert.deepEqual(guest.last('snapshot').data.world, data.world);
  for (const world of [undefined, {...data.world, lives: [4, 2, 1, 0]}, {...data.world, damage: [-1, 0, 0, 0]}]) {
    assert.throws(() => host.send({op: 'snapshot', epoch, tick: 2, data: {...data, world}}), /invalid_snapshot/);
  }
});

test('sweeper rooms require all three host-owned arm angles', () => {
  const {host, client} = fixture();
  const guest = client(); guest.send({op: 'join', code: host.c.room.code});
  const config = {game: 'sweeper_storm', arena: 'sweeper_ring', rounds: 1, bots: true, difficulty: 1};
  assert.throws(() => host.send({op: 'configure', config: {...config, arena: 'tide_spire'}}), /invalid_config/);
  host.send({op: 'configure', config});
  host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true}); host.send({op: 'start'});
  const epoch = host.last('start').epoch;
  host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
  const data = snapshot(); data.world = {angles: [0, 1, -1]};
  assert.throws(() => guest.send({op: 'snapshot', epoch, tick: 1, data}), /host_only/);
  host.send({op: 'snapshot', epoch, tick: 1, data});
  assert.deepEqual(guest.last('snapshot').data.world, data.world);
  for (const world of [undefined, {angles: [0, 1]}, {angles: [0, 1, 4]}]) {
    assert.throws(() => host.send({op: 'snapshot', epoch, tick: 2, data: {...data, world}}), /invalid_snapshot/);
  }
});

test('tide rooms accept only host water state on the authored arena', () => {
  const {host, client} = fixture();
  const guest = client(); guest.send({op: 'join', code: host.c.room.code});
  const config = {game: 'rising_tide', arena: 'tide_spire', rounds: 1, bots: true, difficulty: 1};
  assert.throws(() => host.send({op: 'configure', config: {...config, arena: 'hurdle_track'}}), /invalid_config/);
  host.send({op: 'configure', config});
  host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true}); host.send({op: 'start'});
  const epoch = host.last('start').epoch;
  host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
  const data = snapshot(); data.world = {level: 1.5, age: 15};
  assert.throws(() => guest.send({op: 'snapshot', epoch, tick: 1, data}), /host_only/);
  host.send({op: 'snapshot', epoch, tick: 1, data});
  assert.deepEqual(guest.last('snapshot').data.world, data.world);
  for (const world of [undefined, {...data.world, age: -1}, {...data.world, level: 1001}]) {
    assert.throws(() => host.send({op: 'snapshot', epoch, tick: 2, data: {...data, world}}), /invalid_snapshot/);
  }
});

test('hurdle rooms validate host times and award the fastest tournament runner', () => {
  const {host, client} = fixture();
  const guest = client(); guest.send({op: 'join', code: host.c.room.code});
  const config = {game: 'hurdle_dash', arena: 'hurdle_track', rounds: 1, bots: true, difficulty: 1,
    tournament: {mode: 'points', target: 3, rotation: 'manual', points: [5, 3, 2, 1],
      entries: [{game: 'hurdle_dash', arena: 'hurdle_track'}]}};
  assert.throws(() => host.send({op: 'configure', config: {...config, arena: 'crate_yard'}}), /invalid_config/);
  host.send({op: 'configure', config});
  host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true}); host.send({op: 'start'});
  const epoch = host.last('start').epoch;
  host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
  const data = snapshot(); data.world = {elapsed: 20, times: [1000, 1200, 1500, 99999]};
  assert.throws(() => guest.send({op: 'snapshot', epoch, tick: 1, data}), /host_only/);
  host.send({op: 'snapshot', epoch, tick: 1, data});
  assert.deepEqual(guest.last('snapshot').data.world, data.world);
  for (const world of [undefined, {...data.world, times: [2001, 1200, 1500, 99999]}, {...data.world, elapsed: -1}]) {
    assert.throws(() => host.send({op: 'snapshot', epoch, tick: 2, data: {...data, world}}), /invalid_snapshot/);
  }
  host.send({op: 'result', epoch, scores: data.world.times, higher_is_better: true});
  assert.deepEqual(guest.last('result').tournament.points, [5, 3, 2, 1]);
  assert.deepEqual(guest.last('result').tournament.cups, [1, 0, 0, 0]);
});

test('tournament snapshots follow the current game rather than the lobby default', () => {
  const {host, client} = fixture();
  const guest = client(); guest.send({op: 'join', code: host.c.room.code});
  host.send({op: 'configure', config: {game: 'ring_rumble', arena: 'vortex_ring', rounds: 1,
    bots: true, difficulty: 1, tournament: {mode: 'points', target: 3, rotation: 'manual',
      points: [5, 3, 2, 1], entries: [{game: 'goal_guard', arena: 'quad_court'}]}}});
  host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true});
  host.send({op: 'start'});
  assert.equal(host.last('start').config.game, 'goal_guard');
  const epoch = host.last('start').epoch;
  host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
  assert.throws(() => host.send({op: 'snapshot', epoch, tick: 1, data: snapshot()}), /invalid_snapshot/);
});

test('private codes, public discovery, four players, no leaked tokens', () => {
  const {rooms, host, client} = fixture();
  const code = host.c.room.code;
  assert.match(code, /^[A-Z2-9]{6}$/);
  const guests = Array.from({length: 3}, client);
  guests.forEach(g => g.send({op: 'join', code, name: '<guest>\n'}));
  assert.equal(host.last('room').players.length, 4);
  assert.equal(host.last('room').players[1].name, 'guest');
  assert.ok(!JSON.stringify(host.last('room')).includes('token'));
  assert.throws(() => client().send({op: 'join', code}), /room_full/);
  const browser = client(); browser.send({op: 'list'});
  assert.deepEqual(browser.last('rooms').rooms, []);
  guests[0].send({op: 'leave'}); browser.send({op: 'list'});
  assert.doesNotThrow(() => guests[0].send({op: 'leave'}));
  assert.equal(browser.last('rooms').rooms.length, 1);
  const privateHost = client(); privateHost.send({op: 'create', capacity: 2, public: false});
  browser.send({op: 'list'}); assert.equal(browser.last('rooms').rooms.length, 1);
  assert.equal(rooms.rooms.size, 2);
});

test('host controls, readiness invalidation, load barrier, authoritative results', () => {
  const {host, client} = fixture();
  const guest = client(); guest.send({op: 'join', code: host.c.room.code});
  assert.throws(() => guest.send({op: 'kick', id: 1}), /host_only/);
  assert.throws(() => host.send({op: 'start'}), /not_ready/);
  host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true});
  host.send({op: 'configure', config: {game: 'ring_rumble', arena: 'storm_ring', rounds: 5, bots: true, difficulty: 3}});
  assert.ok(host.last('room').players.every(p => !p.ready));
  host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true});
  host.send({op: 'start'});
  const epoch = host.last('start').epoch;
  assert.equal(host.last('start').players.length, 4);
  assert.equal(host.c.room.state, 'loading');
  host.send({op: 'loaded', epoch}); assert.equal(host.c.room.state, 'loading');
  guest.send({op: 'loaded', epoch}); assert.equal(host.c.room.state, 'playing');
  assert.throws(() => guest.send({op: 'snapshot', epoch, tick: 1, data: {}}), /host_only/);
  guest.send({op: 'input', epoch, sequence: 1, slot: 0, axes: [1, 0, 0, 0], bits: 4});
  assert.equal(host.last('input').slot, 1);
  assert.throws(() => guest.send({op: 'input', epoch, sequence: 1, axes: [0, 0, 0, 0], bits: 0}), /invalid_input/);
  assert.throws(() => guest.send({op: 'input', epoch, sequence: 2, axes: [Infinity, 0, 0, 0], bits: 0}), /invalid_input/);
  assert.throws(() => host.send({op: 'snapshot', epoch, tick: 1, data: {fighters: []}}), /invalid_snapshot/);
  host.send({op: 'snapshot', epoch, tick: 1, data: snapshot()});
  assert.equal(guest.last('snapshot').tick, 1);
  assert.throws(() => guest.send({op: 'result', epoch, scores: [99, 0, 0, 0]}), /host_only/);
  host.send({op: 'result', epoch, scores: [1, 2, 3, 4]});
  assert.deepEqual(guest.last('result').scores, [1, 2, 3, 4]);
  const forwarded = host.messages.filter(m => m.op === 'input').length;
  guest.send({op: 'input', epoch, sequence: 2, axes: [1, 0, 0, 0], bits: 4});
  assert.equal(host.messages.filter(m => m.op === 'input').length, forwarded);
  host.send({op: 'snapshot', epoch, tick: 2, data: snapshot()});
  assert.equal(guest.last('snapshot').tick, 1);
  assert.throws(() => guest.send({op: 'input', epoch: epoch + 1, sequence: 3, axes: [0, 0, 0, 0], bits: 0}), /invalid_state/);
  assert.throws(() => host.send({op: 'result', epoch, scores: [1, 2, 3, 4]}), /invalid_result/);
  host.send({op: 'lobby'}); assert.equal(host.c.room.state, 'lobby');
});

test('reconnect preserves identity and grace, rejects impersonation and expired tokens', () => {
  const {rooms, host, client, advance} = fixture();
  const guest = client(); guest.send({op: 'join', code: host.c.room.code});
  const token = guest.last('welcome').token;
  const id = guest.c.player.id;
  assert.throws(() => client().send({op: 'resume', token}), /session_active/);
  rooms.disconnect(guest.c);
  advance(29000);
  const resumed = client(); resumed.send({op: 'resume', token});
  assert.equal(resumed.last('welcome').id, id);
  assert.equal(resumed.c.player.slot, 1);
  rooms.disconnect(resumed.c); advance(30001);
  assert.throws(() => client().send({op: 'resume', token}), /session_expired/);
  assert.equal(host.c.room.players.size, 1);
  rooms.disconnect(host.c); advance(30001); assert.equal(rooms.rooms.size, 0);
});

test('host loss expires without fabricated winner, kick invalidates token', () => {
  const {rooms, host, client, advance} = fixture();
  const guest = client(); guest.send({op: 'join', code: host.c.room.code});
  const token = guest.last('welcome').token;
  host.send({op: 'kick', id: guest.c.player.id});
  assert.equal(guest.last('closed').reason, 'kicked');
  assert.throws(() => client().send({op: 'resume', token}), /session_expired/);
  guest.send({op: 'join', code: host.c.room.code});
  rooms.disconnect(host.c); advance(30001);
  assert.equal(guest.last('closed').reason, 'host_left');
  assert.equal(guest.last('result'), undefined);
});

test('protocol/config validation and bounded room resources', () => {
  const {host, rooms, client} = fixture();
  assert.throws(() => rooms.handle(host.c, {op: 'start', v: 2}), /version_mismatch/);
  assert.throws(() => host.send({op: 'configure', config: {game: 'tank_arena'}}), /invalid_config/);
  assert.throws(() => host.send({op: 'ready', ready: 'true'}), /invalid_state/);
  assert.throws(() => host.send({op: 'character', character: 50}), /invalid_request/);
  rooms.maxRooms = 1;
  assert.throws(() => client().send({op: 'create', capacity: 4, public: true}), /unavailable/);
});

test('rejoining a lobby reuses only a vacant slot', () => {
  const {host, client} = fixture();
  const guests = Array.from({length: 3}, client);
  guests.forEach(g => g.send({op: 'join', code: host.c.room.code}));
  guests[0].send({op: 'leave'});
  const replacement = client();
  replacement.send({op: 'join', code: host.c.room.code});
  const slots = host.last('room').players.map(p => p.slot);
  assert.equal(new Set(slots).size, 4);
  assert.equal(replacement.c.player.slot, 1);
});

test('resuming after returning to lobby cannot replay an old result', () => {
  const {rooms, host, client} = fixture();
  const guest = client(); guest.send({op: 'join', code: host.c.room.code});
  host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true});
  host.send({op: 'start'});
  host.send({op: 'loaded', epoch: 1}); guest.send({op: 'loaded', epoch: 1});
  host.send({op: 'result', epoch: 1, scores: [5, 3, 2, 1]});
  host.send({op: 'lobby'});
  const token = guest.last('welcome').token;
  rooms.disconnect(guest.c);
  const resumed = client(); resumed.send({op: 'resume', token});
  assert.equal(resumed.last('room').state, 'lobby');
  assert.equal(resumed.last('result'), undefined);
  assert.equal(resumed.last('start'), undefined);
});

test('disconnected host receives the full reconnect grace, not snapshot age', () => {
  const {rooms, host, client, advance} = fixture();
  host.send({op: 'ready', ready: true}); host.send({op: 'start'});
  host.send({op: 'loaded', epoch: 1});
  advance(5000);
  const token = host.last('welcome').token;
  rooms.disconnect(host.c);
  advance(26000);
  const resumed = client(); resumed.send({op: 'resume', token});
  assert.equal(resumed.last('room').state, 'playing');
  advance(1000);
  assert.equal(rooms.rooms.size, 1);
  advance(30001);
  assert.equal(resumed.last('closed').reason, 'authority_timeout');
});

test('loading and silent-authority watchdogs terminate without a result', () => {
  const {host, advance} = fixture();
  host.send({op: 'ready', ready: true}); host.send({op: 'start'});
  advance(60001);
  assert.equal(host.last('closed').reason, 'load_timeout');
  assert.equal(host.last('result'), undefined);
  const f = fixture();
  f.host.send({op: 'ready', ready: true}); f.host.send({op: 'start'});
  f.host.send({op: 'loaded', epoch: 1}); f.advance(30001);
  assert.equal(f.host.last('closed').reason, 'authority_timeout');
  assert.equal(f.host.last('result'), undefined);
});

test('online tournament keeps roster, requires ready between rounds and reconnects standings', () => {
  const {rooms, host, client} = fixture();
  const guest = client(); guest.send({op: 'join', code: host.c.room.code});
  const config = {...host.c.room.config, tournament: {mode: 'points', target: 3,
    rotation: 'random_no_repeat', points: [5, 3, 2, 1],
    entries: [{game: 'ring_rumble', arena: 'vortex_ring'}, {game: 'ring_rumble', arena: 'storm_ring'}]}};
  host.send({op: 'configure', config});
  assert.throws(() => guest.send({op: 'next'}), /host_only/);
  for (let epoch = 1; epoch <= 3; epoch++) {
    host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true});
    host.send({op: epoch === 1 ? 'start' : 'next'});
    assert.equal(host.last('start').config.rounds, 1);
    assert.equal(host.last('start').players[1].id, guest.c.player.id);
    host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
    host.send({op: 'result', epoch, scores: [10, 8, 6, 2]});
    assert.equal(host.last('result').tournament.round, epoch);
    if (epoch < 3) assert.throws(() => host.send({op: 'next'}), /not_ready/);
  }
  assert.deepEqual(host.last('result').tournament.points, [15, 9, 6, 3]);
  assert.deepEqual(host.last('result').tournament.champions, [0]);
  assert.throws(() => host.send({op: 'next'}), /invalid_state/);
  const token = guest.last('welcome').token;
  rooms.disconnect(guest.c);
  const resumed = client(); resumed.send({op: 'resume', token});
  assert.deepEqual(resumed.last('result').tournament.champions, [0]);
  host.send({op: 'lobby'});
  assert.equal(host.last('room').tournament, null);
});

test('online tournament rejects unavailable games and malformed point tables', () => {
  const {host} = fixture();
  const t = {mode: 'points', target: 3, rotation: 'manual', points: [5, 3, 2, 1],
    entries: [{game: 'tank_arena', arena: 'vortex_ring'}]};
  assert.throws(() => host.send({op: 'configure', config: {...host.c.room.config, tournament: t}}), /invalid_config/);
  t.entries[0].game = 'ring_rumble'; t.points = [1, 9, 2, 3];
  assert.throws(() => host.send({op: 'configure', config: {...host.c.room.config, tournament: t}}), /invalid_config/);
});

test('real WebSocket match, reconnect and closed-room input drain', async t => {
  const server = createServer();
  const multiplayer = attachMultiplayer(server, {enabled: true});
  const sockets = [];
  t.after(async () => {
    for (const socket of sockets) socket.terminate();
    multiplayer.close();
    await new Promise(resolve => server.close(resolve));
  });
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  const url = `ws://127.0.0.1:${server.address().port}/multiplayer`;
  async function connect() {
    const socket = new WebSocket(url); sockets.push(socket);
    const messages = []; const waiters = [];
    socket.on('message', data => {
      const m = JSON.parse(data); messages.push(m);
      for (const w of [...waiters]) if (w.op === m.op) { waiters.splice(waiters.indexOf(w), 1); w.resolve(m); }
    });
    const wait = op => new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`timeout ${op}`)), 5000);
      waiters.push({op, resolve: m => { clearTimeout(timer); resolve(m); }});
    });
    const hello = wait('hello'); await once(socket, 'open'); await hello;
    return {socket, messages, wait, send: m => socket.send(JSON.stringify({v: 1, ...m}))};
  }
  const clients = await Promise.all(Array.from({length: 4}, connect));
  const host = clients[0];
  let room = host.wait('room');
  host.send({op: 'create', capacity: 4, public: true}); const code = (await room).code;
  for (const c of clients.slice(1)) { const joined = c.wait('room'); c.send({op: 'join', code}); await joined; }
  for (const c of clients) { const changed = c.wait('room'); c.send({op: 'ready', ready: true}); await changed; }
  const starts = clients.map(c => c.wait('start')); host.send({op: 'start'});
  const matches = await Promise.all(starts); const epoch = matches[0].epoch;
  assert.ok(matches.every(m => m.players.length === 4 && m.seed === matches[0].seed));
  const goes = clients.map(c => c.wait('go'));
  clients.forEach(c => c.send({op: 'loaded', epoch})); await Promise.all(goes);
  const input = host.wait('input'); clients[2].send({op: 'input', epoch, sequence: 1, axes: [.5, 0, 0, 0], bits: 8});
  assert.equal((await input).slot, 2);
  const token = clients[2].messages.find(m => m.op === 'welcome').token;
  const disconnect = once(clients[2].socket, 'close'); clients[2].socket.close(); await disconnect;
  const returned = await connect(); const welcome = returned.wait('welcome'); const restored = returned.wait('start');
  returned.send({op: 'resume', token}); assert.equal((await welcome).id, 3); await restored;
  const done = returned.wait('result'); host.send({op: 'result', epoch, scores: [4, 3, 2, 1]});
  assert.deepEqual((await done).scores, [4, 3, 2, 1]);
  const closed = returned.wait('closed'); host.send({op: 'leave'}); await closed;
  const drained = returned.wait('pong');
  returned.send({op: 'input', epoch, sequence: 2, axes: [.5, 0, 0, 0], bits: 8});
  returned.send({op: 'ping', stamp: 42});
  assert.equal((await drained).stamp, 42);
  assert.deepEqual(returned.messages.filter(m => m.op === 'error'), []);
  assert.equal(multiplayer.rooms.rooms.size, 0);
  assert.equal(multiplayer.rooms.sessions.size, 0);
});
