import assert from 'node:assert/strict';
import {once} from 'node:events';
import {createServer} from 'node:http';
import test from 'node:test';
import WebSocket from 'ws';
import {attachMultiplayer} from './multiplayer.js';
import {Rooms, PROTOCOL} from './rooms.js';

async function fixture(t, options = {}) {
  const server = createServer();
  const multiplayer = attachMultiplayer(server, options);
  const sockets = [];
  t.after(async () => {
    for (const socket of sockets) socket.terminate();
    multiplayer.close();
    await new Promise(resolve => server.close(resolve));
  });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  return {
    multiplayer,
    connect({origin, path = '/multiplayer'} = {}) {
      const socket = new WebSocket(`ws://127.0.0.1:${server.address().port}${path}`,
        origin === undefined ? {} : {origin});
      sockets.push(socket);
      socket.on('error', () => {});
      return socket;
    },
  };
}

function event(socket, name) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      socket.off(name, receive);
      reject(new Error(`Timed out waiting for ${name}`));
    }, 3000);
    function receive(...values) {
      clearTimeout(timer);
      resolve(values);
    }
    socket.once(name, receive);
  });
}

async function rejected(socket) {
  const [, response] = await event(socket, 'unexpected-response');
  response.resume();
  socket.terminate();
  assert.equal(response.statusCode, 403);
}

async function hello(socket) {
  const [data] = await event(socket, 'message');
  assert.equal(JSON.parse(data).op, 'hello');
}

test('multiplayer is disabled by default, including native clients without Origin', async t => {
  const f = await fixture(t);
  await rejected(f.connect());
  assert.equal(f.multiplayer.rooms.rooms.size, 0);
  assert.equal(f.multiplayer.rooms.sessions.size, 0);
});

test('browser Origin requires an exact allowlist match while native clients can connect', async t => {
  const f = await fixture(t, {enabled: true, origins: ['https://game.example.test']});
  await rejected(f.connect({origin: 'https://attacker.example.test'}));
  await rejected(f.connect({origin: 'https://game.example.test.attacker.test'}));
  await rejected(f.connect({origin: 'null'}));
  await hello(f.connect({origin: 'https://game.example.test'}));
  await hello(f.connect());
});

test('upgrade rejects paths other than the exact multiplayer endpoint', async t => {
  const f = await fixture(t, {enabled: true});
  for (const path of ['/account', '/multiplayer/', '/multiplayer?token=not-a-session']) {
    await rejected(f.connect({path}));
  }
  await hello(f.connect());
});

test('binary messages close the socket rather than reaching room parsing', async t => {
  const f = await fixture(t, {enabled: true});
  const socket = f.connect();
  await hello(socket);
  const closed = event(socket, 'close');
  socket.send(Buffer.from('{"op":"create"}'));
  const [code, reason] = await closed;
  assert.equal(code, 1008);
  assert.equal(reason.toString(), 'rate_or_format');
  assert.equal(f.multiplayer.rooms.rooms.size, 0);
});

test('invalid JSON returns only a stable error code and never reflects supplied secrets', async t => {
  const f = await fixture(t, {enabled: true});
  const socket = f.connect();
  await hello(socket);
  const response = event(socket, 'message');
  socket.send('credential=development-only-canary');
  const [data] = await response;
  assert.deepEqual(JSON.parse(data), {op: 'error', code: 'invalid_request'});
  assert.ok(!data.toString().includes('development-only-canary'));
  assert.equal(f.multiplayer.rooms.rooms.size, 0);
});

test('control rate limit rejects the thirteenth request and recovers after its window', async t => {
  let now = 1000;
  const f = await fixture(t, {enabled: true, rooms: new Rooms({now: () => now})});
  const socket = f.connect();
  await hello(socket);
  for (let stamp = 0; stamp < 12; stamp++) {
    const response = event(socket, 'message');
    socket.send(JSON.stringify({v: PROTOCOL, op: 'ping', stamp}));
    const [data] = await response;
    assert.deepEqual(JSON.parse(data), {op: 'pong', stamp});
  }
  let response = event(socket, 'message');
  socket.send(JSON.stringify({v: PROTOCOL, op: 'ping', stamp: 12}));
  assert.deepEqual(JSON.parse((await response)[0]), {op: 'error', code: 'rate_limit'});
  now += 1000;
  response = event(socket, 'message');
  socket.send(JSON.stringify({v: PROTOCOL, op: 'ping', stamp: 13}));
  assert.deepEqual(JSON.parse((await response)[0]), {op: 'pong', stamp: 13});
  assert.equal(f.multiplayer.rooms.rooms.size, 0);
});

test('message flood closes the connection without creating room state', async t => {
  const f = await fixture(t, {enabled: true, rooms: new Rooms({now: () => 1000})});
  const socket = f.connect();
  await hello(socket);
  const closed = event(socket, 'close');
  for (let request = 0; request < 91; request++) socket.send('null');
  const [code, reason] = await closed;
  assert.equal(code, 1008);
  assert.equal(reason.toString(), 'rate_or_format');
  assert.equal(f.multiplayer.rooms.rooms.size, 0);
  assert.equal(f.multiplayer.rooms.sessions.size, 0);
});

test('payload above 64 KiB is rejected by the transport before room parsing', async t => {
  const f = await fixture(t, {enabled: true});
  const socket = f.connect();
  await hello(socket);
  const closed = event(socket, 'close');
  socket.send('x'.repeat(65537));
  assert.equal((await closed)[0], 1009);
  assert.equal(f.multiplayer.rooms.rooms.size, 0);
  assert.equal(f.multiplayer.rooms.sessions.size, 0);
});

test('per-address connection budget rejects the seventeenth socket and releases a closed slot', async t => {
  const f = await fixture(t, {enabled: true});
  const sockets = [];
  for (let index = 0; index < 16; index++) {
    const socket = f.connect();
    sockets.push(socket);
    await hello(socket);
  }
  await rejected(f.connect());
  const closed = event(sockets[0], 'close');
  sockets[0].close();
  await closed;
  await new Promise(resolve => setImmediate(resolve));
  await hello(f.connect());
  assert.equal(f.multiplayer.rooms.rooms.size, 0);
  assert.equal(f.multiplayer.rooms.sessions.size, 0);
});
