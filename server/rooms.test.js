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

test('real WebSocket four-client match and transport reconnect', async t => {
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
});
