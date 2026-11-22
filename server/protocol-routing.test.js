import assert from 'node:assert/strict';
import {once} from 'node:events';
import {createServer} from 'node:http';
import test from 'node:test';
import WebSocket, {WebSocketServer} from 'ws';
import {attachMultiplayer} from './multiplayer.js';
import {Rooms, PROTOCOL} from './rooms.js';

const paths = {1: '/multiplayer', 2: '/multiplayer/v2'};

async function fixture(t, options = {}) {
  const server = createServer();
  const multiplayer = attachMultiplayer(server, {enabled: true, legacyEnabled: true, ...options});
  const sockets = [];
  t.after(async () => {
    for (const socket of sockets) socket.terminate();
    multiplayer.close();
    await new Promise(resolve => server.close(resolve));
  });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  function socket(path, origin) {
    const ws = new WebSocket(`ws://127.0.0.1:${server.address().port}${path}`,
      origin === undefined ? {} : {origin});
    ws.on('error', () => {});
    sockets.push(ws);
    return ws;
  }
  return {
    multiplayer,
    async reject(path, origin) {
      const ws = socket(path, origin);
      const [, response] = await once(ws, 'unexpected-response');
      response.resume();
      ws.terminate();
      assert.equal(response.statusCode, 403);
    },
    async connect(v, {path = paths[v], origin, ruleset} = {}) {
      const ws = socket(path, origin);
      // Queue before the handshake so bursts of welcome/room/start cannot race readers.
      const messages = [];
      let pending;
      ws.on('message', data => {
        messages.push(JSON.parse(data));
        pending?.();
      });
      async function next(op) {
        const deadline = Date.now() + 3000;
        while (true) {
          const index = messages.findIndex(m => m.op === op);
          if (index !== -1) return messages.splice(index, 1)[0];
          await new Promise((resolve, reject) => {
            const timer = setTimeout(() => {
              pending = null;
              reject(new Error(`Timed out waiting for ${op}`));
            }, Math.max(1, deadline - Date.now()));
            pending = () => { clearTimeout(timer); pending = null; resolve(); };
          });
        }
      }
      const hello = await next('hello');
      assert.equal(hello.v, v);
      return {
        ws, hello, next,
        send(message) { ws.send(JSON.stringify({v, ...(ruleset === undefined ? {} : {ruleset}), ...message})); },
        async request(message, op) { this.send(message); return next(op); },
        async disconnect() {
          const closed = once(ws, 'close');
          ws.close();
          await closed;
          await new Promise(resolve => setImmediate(resolve));
        },
      };
    },
  };
}

async function create(client, publicRoom = false) {
  const welcome = await client.request({op: 'create', capacity: 2, public: publicRoom, name: 'Host'}, 'welcome');
  const room = await client.next('room');
  return {welcome, room};
}

function colossusSnapshot(exposed) {
  return {phase: 4, round: 0, countdown: 0, radius: 10, time: 50,
    scores: [0, 0], alive: [true, true],
    fighters: Array.from({length: 2}, () => ({position: [0, 0, 0], velocity: [0, 0, 0],
      facing: [0, 0, 1], health: 100, dash: 0, attack: 0, stun: 0, visible: true, alive: true})),
    world: {boss: {health: 745, phase: 0, defeated: false, position: [0, 0, 0], rotation: [0, 0, 0],
      damage: 1, strike: 1, strike_position: [6, 0, 0], strike_radius: 4},
    warnings: [], craters: [], arm_rotation: [0, 0, 0], fist_position: [6, 1, 0],
    fist_scale: [1, 1, 1], exposed}};
}

test('Rooms validates and fixes its instance protocol; default remains current', () => {
  assert.equal(new Rooms().protocol, PROTOCOL);
  for (const protocol of [1, 2]) {
    const rooms = new Rooms({protocol});
    const messages = [];
    const c = rooms.connect(message => messages.push(message));
    rooms.handle(c, {v: protocol, op: 'ping', stamp: 7});
    assert.deepEqual(messages, [{op: 'pong', stamp: 7}]);
    for (const v of [3 - protocol, undefined, String(protocol), null]) {
      assert.throws(() => rooms.handle(c, {v, op: 'create', capacity: 2, public: false}), /version_mismatch/);
    }
    assert.throws(() => { rooms.protocol = 3 - protocol; }, TypeError);
    assert.equal(rooms.rooms.size, 0);
  }
  for (const protocol of [0, 3, -1, 1.5, '1', '2', true, false, null, NaN, Infinity, {}, []]) {
    assert.throws(() => new Rooms({protocol}), /invalid_protocol/);
  }
});

test('routing options reject invalid registrations before attaching upgrade handlers', () => {
  for (const options of [{legacyEnabled: 'true'}, {legacyEnabled: null},
    {rooms: new Rooms({protocol: 1})}, {rooms: {}}, {rooms: null}]) {
    const server = createServer();
    assert.throws(() => attachMultiplayer(server, options), /invalid_(legacy_enabled|rooms)/);
    assert.equal(server.listenerCount('upgrade'), 0);
  }
});

test('local default preserves protocol 2 on the old fixture endpoint only', async t => {
  const f = await fixture(t, {legacyEnabled: false});
  assert.equal(f.multiplayer.legacyRooms, null);
  await f.connect(2, {path: '/multiplayer'});
  await f.reject('/multiplayer/v2');
});

for (const v of [1, 2]) {
  test(`protocol ${v}: handshake, private join, ready/start, reconnect and cross-version isolation`, async t => {
    const f = await fixture(t);
    assert.notEqual(f.multiplayer.rooms, f.multiplayer.legacyRooms);
    const host = await f.connect(v);
    const other = await f.connect(3 - v);
    const {room, welcome} = await create(host);
    assert.equal(host.hello.reconnect_ms, 30000);
    assert.ok(host.hello.games.includes('boss_colossus'));
    const guest = await f.connect(v);
    assert.deepEqual((await guest.request({op: 'list'}, 'rooms')).rooms, []);
    assert.deepEqual((await other.request({op: 'list'}, 'rooms')).rooms, []);
    assert.deepEqual(await other.request({op: 'join', code: room.code}, 'error'),
      {op: 'error', code: 'room_unavailable'});
    const joined = await guest.request({op: 'join', code: room.code, name: 'Guest'}, 'welcome');
    assert.notEqual(joined.id, welcome.id);
    assert.equal((await guest.next('room')).code, room.code);
    const joinedRoom = await host.next('room');
    assert.equal(joinedRoom.players.length, 2);
    await host.request({op: 'configure', config: {game: 'boss_colossus', arena: 'vortex_ring',
      rounds: 2, bots: false, difficulty: 1}}, 'room');
    await guest.next('room');
    await host.request({op: 'ready', ready: true}, 'room');
    await guest.next('room');
    await guest.request({op: 'ready', ready: true}, 'room');
    await host.next('room');
    const started = await host.request({op: 'start'}, 'start');
    assert.deepEqual(await guest.next('start'), started);
    assert.equal(started.players.length, 2);
    await host.next('room');
    await guest.next('room');
    host.send({op: 'loaded', epoch: started.epoch});
    const go = await guest.request({op: 'loaded', epoch: started.epoch}, 'go');
    assert.deepEqual(await host.next('go'), go);
    await host.next('room');
    await guest.next('room');

    let tick = 0;
    for (const exposed of v === 1 ? [0, 1.2, 2.4] : [0, 2.4, 3.2]) {
      const data = colossusSnapshot(exposed);
      host.send({op: 'snapshot', epoch: started.epoch, tick: ++tick, data});
      assert.deepEqual((await guest.next('snapshot')).data, data);
    }
    assert.deepEqual(await host.request({op: 'snapshot', epoch: started.epoch, tick: tick + 1,
      data: colossusSnapshot(3.21)}, 'error'), {op: 'error', code: 'invalid_snapshot'});
    assert.deepEqual(await guest.request({op: 'snapshot', epoch: started.epoch, tick: tick + 1,
      data: colossusSnapshot(2.4)}, 'error'), {op: 'error', code: 'host_only'});

    await guest.disconnect();
    const disconnected = await host.next('room');
    assert.equal(disconnected.players.find(p => p.id === joined.id).connected, false);
    assert.deepEqual(await other.request({op: 'resume', token: joined.token}, 'error'),
      {op: 'error', code: 'session_expired'});
    const restored = await f.connect(v);
    assert.deepEqual(await restored.request({op: 'resume', token: joined.token}, 'welcome'), joined);
    assert.deepEqual(await restored.next('start'), started);
    assert.equal((await restored.next('snapshot')).tick, tick);
    assert.equal((await restored.next('room')).players.find(p => p.id === joined.id).connected, true);

    // A mismatched message must not renegotiate an existing connection's namespace.
    assert.deepEqual(await other.request({v, op: 'resume', token: joined.token}, 'error'),
      {op: 'error', code: 'version_mismatch'});
    assert.deepEqual(await host.request({v: 3 - v, op: 'list'}, 'error'),
      {op: 'error', code: 'version_mismatch'});
    assert.deepEqual((await other.request({op: 'list'}, 'rooms')).rooms, []);
    assert.equal((await restored.request({op: 'ping', stamp: 42}, 'pong')).stamp, 42);
  });
}

test('public room lists and room codes are scoped to the endpoint', async t => {
  const f = await fixture(t);
  const legacy = await f.connect(1), current = await f.connect(2);
  const a = await create(legacy, true), b = await create(current, true);
  for (const [client, own] of [[legacy, a], [current, b]]) {
    assert.deepEqual((await client.request({op: 'list'}, 'rooms')).rooms.map(r => r.code), [own.room.code]);
  }
  // Even identical codes must resolve to separate room/session stores.
  const currentRoom = f.multiplayer.rooms.rooms.get(b.room.code);
  f.multiplayer.rooms.rooms.delete(b.room.code);
  currentRoom.code = a.room.code;
  f.multiplayer.rooms.rooms.set(currentRoom.code, currentRoom);
  for (const v of [1, 2]) {
    const guest = await f.connect(v);
    await guest.request({op: 'join', code: a.room.code}, 'welcome');
    assert.equal((await guest.next('room')).players.length, 2);
  }
  assert.notEqual(f.multiplayer.legacyRooms.rooms.get(a.room.code), currentRoom);
});

test('protocol two over real WebSockets isolates rulesets and retains legacy token reconnect', async t => {
  const f = await fixture(t);
  const host = await f.connect(2, {ruleset: 'atomic-v3'});
  const legacy = await f.connect(2);
  assert.equal(host.hello.ruleset_version, 1);
  assert.equal(legacy.hello.v, 2); // An old decoder only needs the unchanged protocol.
  const priorHost = await f.connect(2, {ruleset: 'atomic-v2'});
  const modern = await create(host, true), historical = await create(legacy, true), prior = await create(priorHost, true);
  assert.equal(modern.room.ruleset, 'atomic-v3'); assert.equal(historical.room.ruleset, 'legacy');
  assert.equal(prior.room.ruleset, 'atomic-v2');
  const guest = await f.connect(2, {ruleset: 'atomic-v3'}), oldGuest = await f.connect(2);
  const priorGuest = await f.connect(2, {ruleset: 'atomic-v2'});
  assert.deepEqual((await guest.request({op: 'list'}, 'rooms')).rooms.map(r => r.code), [modern.room.code]);
  assert.deepEqual((await oldGuest.request({op: 'list'}, 'rooms')).rooms.map(r => r.code), [historical.room.code]);
  assert.deepEqual((await priorGuest.request({op: 'list'}, 'rooms')).rooms.map(r => r.code), [prior.room.code]);
  assert.deepEqual(await priorGuest.request({op: 'join', code: modern.room.code}, 'error'), {op: 'error', code: 'room_unavailable'});
  assert.deepEqual(await guest.request({op: 'join', code: prior.room.code}, 'error'), {op: 'error', code: 'room_unavailable'});
  assert.deepEqual(await oldGuest.request({op: 'join', code: modern.room.code}, 'error'), {op: 'error', code: 'room_unavailable'});
  assert.deepEqual(await guest.request({op: 'join', code: historical.room.code}, 'error'), {op: 'error', code: 'room_unavailable'});
  const joined = await guest.request({op: 'join', code: modern.room.code}, 'welcome');
  await guest.next('room'); await host.next('room');
  const oldJoined = await oldGuest.request({op: 'join', code: historical.room.code}, 'welcome');
  await oldGuest.next('room'); await legacy.next('room');
  await host.request({op: 'ready', ready: true}, 'room'); await guest.next('room');
  await guest.request({op: 'ready', ready: true}, 'room'); await host.next('room');
  const started = await host.request({op: 'start'}, 'start');
  assert.equal(started.ruleset, 'atomic-v3'); assert.deepEqual(await guest.next('start'), started);
  await host.next('room'); await guest.next('room');
  host.send({op: 'loaded', epoch: started.epoch});
  await guest.request({op: 'loaded', epoch: started.epoch}, 'go'); await host.next('go');
  await guest.next('room'); await host.next('room');
  await guest.disconnect(); await host.next('room');
  const incompatible = await f.connect(2);
  for (const token of [joined.token, 'unknown-token-canary']) {
    assert.deepEqual(await incompatible.request({op: 'resume', token}, 'error'), {op: 'error', code: 'session_expired'});
    assert.deepEqual(await priorGuest.request({op: 'resume', token}, 'error'), {op: 'error', code: 'session_expired'});
  }
  const restored = await f.connect(2, {ruleset: 'atomic-v3'});
  assert.deepEqual(await restored.request({op: 'resume', token: joined.token}, 'welcome'), joined);
  assert.deepEqual(await restored.next('start'), started);
  await oldGuest.disconnect(); await legacy.next('room');
  const oldRestored = await f.connect(2);
  assert.deepEqual(await oldRestored.request({op: 'resume', token: oldJoined.token}, 'welcome'), oldJoined);
  assert.equal((await oldRestored.next('room')).ruleset, 'legacy');
  assert.deepEqual(await restored.request({op: 'list', ruleset: 'future-4'}, 'error'), {op: 'error', code: 'version_mismatch'});
});

test('both routes preserve exact path, enabled flag and Origin policies', async t => {
  const f = await fixture(t, {origins: ['https://game.example.test']});
  for (const path of ['/multiplayer/', '/multiplayer?token=canary', '/multiplayer/v2/',
    '/multiplayer/v2?token=canary', '/multiplayer/v1', '/multiplayer/v3', '/account']) await f.reject(path);
  for (const v of [1, 2]) {
    for (const origin of ['null', 'https://attacker.example.test', 'https://game.example.test.attacker.test']) {
      await f.reject(paths[v], origin);
    }
    await f.connect(v, {origin: 'https://game.example.test'});
    await f.connect(v);
  }
  const disabled = await fixture(t, {enabled: false});
  for (const path of Object.values(paths)) await disabled.reject(path);
});

test('per-address budget is shared across both routes and releases closed slots', async t => {
  const f = await fixture(t);
  const clients = [];
  for (let i = 0; i < 16; i++) clients.push(await f.connect(i % 2 + 1));
  for (const path of Object.values(paths)) await f.reject(path);
  await clients[0].disconnect();
  await f.connect(2);
  await f.reject(paths[1]);
});

test('global 800-connection budget is shared across routes', async t => {
  let transport;
  const upgrade = WebSocketServer.prototype.handleUpgrade;
  t.mock.method(WebSocketServer.prototype, 'handleUpgrade', function (...args) {
    transport = this;
    return upgrade.apply(this, args);
  });
  const f = await fixture(t);
  await f.connect(1);
  await f.connect(2);
  // Fill only the transport accounting set; no 800-socket load test is needed.
  const placeholders = Array.from({length: 798}, () => ({}));
  try {
    for (const client of placeholders) transport.clients.add(client);
    assert.equal(transport.clients.size, 800);
    for (const path of Object.values(paths)) await f.reject(path);
    transport.clients.delete(placeholders[0]);
    await f.connect(1);
    await f.reject(paths[2]);
  } finally {
    for (const client of placeholders) transport.clients.delete(client);
  }
});

for (const first of [1, 2]) {
  test(`maxRooms=1 is shared when protocol ${first} creates first and released across routes`, async t => {
    const f = await fixture(t, {rooms: new Rooms({maxRooms: 1})});
    const host = await f.connect(first), other = await f.connect(3 - first);
    await create(host);
    const request = {op: 'create', capacity: 2, public: false};
    assert.deepEqual(await other.request({...request, v: first}, 'error'),
      {op: 'error', code: 'version_mismatch'});
    assert.deepEqual(await other.request(request, 'error'), {op: 'error', code: 'unavailable'});
    await host.request({op: 'leave'}, 'closed');
    await create(other);
    assert.deepEqual(await host.request(request, 'error'), {op: 'error', code: 'unavailable'});
    assert.equal(f.multiplayer.rooms.rooms.size + f.multiplayer.legacyRooms.rooms.size, 1);
  });
}

for (const v of [1, 2]) {
  test(`protocol ${v}: transport and parsing protections remain active`, async t => {
    const f = await fixture(t);
    const client = await f.connect(v);
    client.ws.send('credential=protocol-routing-canary');
    assert.deepEqual(await client.next('error'), {op: 'error', code: 'invalid_request'});
    for (const value of [null, [], true]) {
      client.ws.send(JSON.stringify(value));
      assert.deepEqual(await client.next('error'), {op: 'error', code: 'invalid_request'});
    }
    for (let stamp = 0; stamp < 9; stamp++) {
      assert.deepEqual(await client.request({op: 'ping', stamp}, 'pong'), {op: 'pong', stamp});
    }
    assert.deepEqual(await client.request({op: 'ping'}, 'error'), {op: 'error', code: 'rate_limit'});
    let closed = once(client.ws, 'close');
    client.ws.send(Buffer.from('{}'));
    const [code, reason] = await closed;
    assert.equal(code, 1008);
    assert.equal(reason.toString(), 'rate_or_format');
    const oversized = await f.connect(v);
    closed = once(oversized.ws, 'close');
    oversized.ws.send('x'.repeat(65537));
    assert.equal((await closed)[0], 1009);
    for (const store of [f.multiplayer.legacyRooms, f.multiplayer.rooms]) {
      assert.equal(store.rooms.size, 0);
      assert.equal(store.sessions.size, 0);
    }
  });
}

test('sweep and shutdown cover both room stores and clear their sessions', async t => {
  const f = await fixture(t);
  const swept = [];
  for (const store of [f.multiplayer.legacyRooms, f.multiplayer.rooms]) {
    const sweep = store.sweep.bind(store);
    t.mock.method(store, 'sweep', () => { swept.push(store.protocol); sweep(); });
  }
  const clients = [];
  for (const v of [1, 2]) {
    const client = await f.connect(v);
    clients.push(client);
    await create(client);
  }
  for (const store of [f.multiplayer.legacyRooms, f.multiplayer.rooms]) {
    for (const room of store.rooms.values()) room.touched = -Infinity;
  }
  const deadline = Date.now() + 3000;
  while (new Set(swept).size < 2 && Date.now() < deadline) {
    await new Promise(resolve => setTimeout(resolve, 20));
  }
  assert.deepEqual([...new Set(swept)].sort(), [1, 2]);
  for (const client of clients) {
    assert.deepEqual(await client.next('closed'), {op: 'closed', reason: 'room_expired'});
    await create(client);
  }
  f.multiplayer.close();
  for (const store of [f.multiplayer.legacyRooms, f.multiplayer.rooms]) {
    assert.equal(store.rooms.size, 0);
    assert.equal(store.sessions.size, 0);
  }
});
