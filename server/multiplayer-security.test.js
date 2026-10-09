import assert from 'node:assert/strict';
import {once} from 'node:events';
import {createServer} from 'node:http';
import test from 'node:test';
import WebSocket from 'ws';
import {attachMultiplayer} from './multiplayer.js';

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
