import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
import {Rooms, LEGACY_RULESET_ID} from './rooms.js';

const CURRENT = 'atomic-v3';
function fixture(protocol = 2) {
  let time = 0;
  let seedCalls = 0;
  const rooms = new Rooms({protocol, now: () => time, seed: () => { seedCalls++; return 117; }});
  const client = ruleset => {
    const messages = [];
    const c = rooms.connect(message => messages.push(structuredClone(message)));
    return {c, messages, send: message => rooms.handle(c, {v: protocol,
      ...(ruleset === undefined ? {} : {ruleset}), ...message}),
    last: op => messages.findLast(message => message.op === op)};
  };
  const create = (host, publicRoom = true) => host.send({op: 'create', capacity: 2, public: publicRoom, name: 'Host'});
  const start = (host, guest) => {
    host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true}); host.send({op: 'start'});
    const epoch = host.last('start').epoch;
    host.send({op: 'loaded', epoch}); guest.send({op: 'loaded', epoch});
    return epoch;
  };
  return {rooms, client, create, start, seedCalls: () => seedCalls, advance: delta => { time += delta; }};
}
const snapshot = () => ({phase: 4, round: 0, countdown: 0, radius: 10, time: 50,
  scores: [0, 1], alive: [true, true], fighters: Array.from({length: 2}, () => ({
    position: [0, 0, 0], velocity: [0, 0, 0], facing: [0, 0, 1], health: 100,
    dash: 0, attack: 0, stun: 0, visible: true, alive: true}))});

test('protocol two validates declarations before binding or allocating a room', () => {
  const f = fixture();
  for (const ruleset of [undefined, null, true, false, 2, [], {}, '', 'Atomic-v2', 'with space', 'x'.repeat(65), '../token']) {
    const peer = f.client();
    assert.throws(() => peer.send({op: 'create', capacity: 2, public: true, ruleset}), /^Error: invalid_ruleset$/);
    assert.equal(f.rooms.rooms.size, 0); assert.equal(f.rooms.sessions.size, 0);
    assert.equal(Object.hasOwn(peer.c, 'ruleset'), false);
    f.create(peer); // Failed validation did not pin a malformed session.
    assert.equal(peer.c.ruleset, LEGACY_RULESET_ID);
    peer.send({op: 'leave'});
  }
});

test('missing is explicit legacy; connection, room and player identities are immutable', () => {
  const f = fixture(), host = f.client(); f.create(host);
  for (const target of [host.c, host.c.room, host.c.player]) {
    assert.equal(target.ruleset, 'legacy');
    assert.equal(Object.getOwnPropertyDescriptor(target, 'ruleset').writable, false);
    assert.throws(() => { target.ruleset = CURRENT; }, TypeError);
  }
  assert.equal(host.last('room').ruleset, 'legacy'); assert.equal(host.last('welcome').ruleset, 'legacy');
  assert.throws(() => host.send({op: 'list', ruleset: CURRENT}), /^Error: version_mismatch$/);
  const current = f.client(CURRENT); f.create(current);
  for (const op of ['create', 'join', 'resume', 'start', 'configure', 'ping', 'list', 'leave']) {
    assert.throws(() => current.send({op, ruleset: 'future-4'}), /^Error: version_mismatch$/);
    const missing = {v: 2, op};
    assert.throws(() => f.rooms.handle(current.c, missing), /^Error: version_mismatch$/);
  }
  assert.equal(current.c.room.ruleset, CURRENT);
});

test('public lists partition legacy, atomic and future labels; private mismatch reveals no membership', () => {
  const f = fixture();
  const identities = [undefined, 'atomic-v2', CURRENT, 'future-4'];
  const hosts = identities.map(id => { const host = f.client(id); f.create(host); return host; });
  for (let i = 0; i < hosts.length; i++) {
    const guest = f.client(identities[i]);
    guest.send({op: 'list'});
    assert.deepEqual(guest.last('rooms').rooms.map(room => room.code), [hosts[i].c.room.code]);
    assert.equal(guest.last('rooms').rooms[0].ruleset, hosts[i].c.ruleset);
    for (let j = 0; j < hosts.length; j++) if (i !== j) {
      assert.throws(() => guest.send({op: 'join', code: hosts[j].c.room.code}), /^Error: room_unavailable$/);
      assert.equal(guest.c.player, null); assert.equal(guest.c.room, null);
      assert.equal(guest.last('welcome'), undefined);
    }
    assert.throws(() => guest.send({op: 'join', code: 'ZZZZZZ'}), /^Error: room_unavailable$/);
    guest.send({op: 'join', code: hosts[i].c.room.code});
    assert.equal(guest.c.room, hosts[i].c.room);
  }
});

for (const ruleset of [undefined, 'legacy', 'atomic-v2', CURRENT, 'future-4']) {
  test(`${ruleset ?? 'missing legacy'}: start, reconnect, authority and resuming an old token preserve ruleset`, () => {
    const f = fixture(), host = f.client(ruleset), guest = f.client(ruleset);
    f.create(host); guest.send({op: 'join', code: host.c.room.code});
    const room = host.c.room, token = guest.last('welcome').token, hostToken = host.last('welcome').token;
    host.send({op: 'configure', config: {game: 'ring_rumble', arena: 'vortex_ring', rounds: 1, bots: false, difficulty: 1, ruleset: 'ignored'}});
    const epoch = f.start(host, guest);
    assert.equal(host.last('start').ruleset, ruleset ?? 'legacy');
    assert.equal(host.last('room').ruleset, ruleset ?? 'legacy');
    const originalStart = structuredClone(host.last('start'));
    guest.send({op: 'input', epoch, sequence: 1, axes: [0, 0, 0, 0], bits: 4});
    assert.equal(host.last('input').bits, 4);
    const data = snapshot(); host.send({op: 'snapshot', epoch, tick: 1, data});
    assert.deepEqual(guest.last('snapshot').data, data);
    assert.throws(() => guest.send({op: 'snapshot', epoch, tick: 2, data}), /^Error: host_only$/);
    assert.throws(() => guest.send({op: 'result', epoch, scores: [1, 0]}), /^Error: host_only$/);
    assert.throws(() => guest.send({op: 'start'}), /^Error: host_only$/);
    const wrong = f.client(ruleset === CURRENT ? undefined : CURRENT);
    for (const secret of [token, hostToken, 'not-a-real-token']) {
      assert.throws(() => wrong.send({op: 'resume', token: secret}), /^Error: session_expired$/);
      assert.equal(wrong.last('welcome'), undefined);
      assert.equal(wrong.c.room, null);
    }
    f.rooms.disconnect(guest.c);
    const expiry = guest.c.player.expires;
    assert.throws(() => wrong.send({op: 'resume', token}), /^Error: session_expired$/);
    assert.equal(guest.c.player.expires, expiry);
    assert.equal(guest.c.player.connection, null);
    const resumed = f.client(ruleset); resumed.send({op: 'resume', token});
    assert.deepEqual(resumed.last('welcome'), guest.last('welcome'));
    assert.deepEqual(resumed.last('start'), originalStart);
    assert.deepEqual(resumed.last('snapshot').data, data);
    assert.equal(room.players.size, 2);
    f.rooms.disconnect(host.c);
    assert.equal(room.host, 1); // No silent promotion to a different authoritative build.
    const restoredHost = f.client(ruleset); restoredHost.send({op: 'resume', token: hostToken});
    assert.equal(restoredHost.c.room.host, restoredHost.c.player.id);
    restoredHost.send({op: 'result', epoch, scores: [3, 1]});
    assert.deepEqual(resumed.last('result').scores, [3, 1]);
    restoredHost.send({op: 'leave'});
    assert.deepEqual(resumed.last('closed'), {op: 'closed', reason: 'host_left'});
    assert.equal(f.rooms.rooms.size, 0); assert.equal(f.rooms.sessions.size, 0);
  });
}

test('start refuses an incompatible connection before consuming seed or changing round state', () => {
  const f = fixture(), host = f.client(CURRENT), guest = f.client(CURRENT);
  f.create(host); guest.send({op: 'join', code: host.c.room.code});
  host.send({op: 'ready', ready: true}); guest.send({op: 'ready', ready: true});
  const foreign = f.client('future-4'); foreign.send({op: 'ping'});
  guest.c.player.connection = foreign.c;
  assert.throws(() => host.send({op: 'start'}), /^Error: version_mismatch$/);
  assert.equal(host.c.room.epoch, 0); assert.equal(host.c.room.state, 'lobby');
  assert.equal(f.seedCalls(), 0);
  assert.equal(host.c.room.roster, undefined);
  assert.equal(host.last('start'), undefined);
  guest.c.player.connection = guest.c;
  assert.equal(f.start(host, guest), 1);
  assert.equal(f.seedCalls(), 1);
});

test('host expiry closes the room, never migrates authority or loses ruleset isolation', () => {
  const f = fixture(), host = f.client(CURRENT), guest = f.client(CURRENT);
  f.create(host); guest.send({op: 'join', code: host.c.room.code}); f.start(host, guest);
  f.rooms.disconnect(host.c); f.advance(30001); f.rooms.sweep();
  assert.deepEqual(guest.last('closed'), {op: 'closed', reason: 'host_left'});
  assert.equal(f.rooms.sessions.size, 0);
});

test('protocol one ignores optional declarations and retains its original wire envelopes', () => {
  const f = fixture(1), host = f.client(CURRENT), guest = f.client('future-4');
  f.create(host); guest.send({op: 'join', code: host.c.room.code}); f.start(host, guest);
  for (const operation of ['welcome', 'room', 'start']) assert.equal(Object.hasOwn(host.last(operation), 'ruleset'), false);
  assert.equal(host.c.room.ruleset, 'legacy');
});

test('Node source contracts: client cannot override session identity or simulate guest combat (not an engine test)', () => {
  const source = file => fs.readFileSync(new URL('../' + file, import.meta.url), 'utf8');
  const transport = source('src/net/room_client.gd');
  assert.match(transport, /const ONLINE_RULESET_ID := "atomic-v3"/);
  assert.match(transport, /packet\["ruleset"\] = ONLINE_RULESET_ID/);
  assert.match(transport, /version == PROTOCOL_VERSION and compatible_ruleset_server\(message\)/);
  const scene = source('src/match/match_scene.gd');
  const guest = scene.slice(scene.indexOf('\t\tif not Net.is_host:'), scene.indexOf('\t\tfor p in config.players:', scene.indexOf('func _physics_process')));
  assert.match(guest, /Net\.publish_input/); assert.match(guest, /_network_replica\.render\(self, delta\)\n\t\t\treturn/);
  assert.doesNotMatch(guest, /_tick_phase|_tick_live|prepare_tick|integrate_prepared_tick|resolve_impacts/);
  const service = source('src/net/net_service.gd');
  for (const operation of ['welcome', 'room', 'start']) {
    const block = service.split(`\t\t"${operation}":`)[1].split('\n\t\t"')[0];
    assert.match(block, /RoomClient\.compatible_ruleset\(m\)/);
  }
});
