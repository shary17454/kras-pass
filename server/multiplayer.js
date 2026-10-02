import {WebSocketServer, WebSocket} from 'ws';
import {Rooms, PROTOCOL, ONLINE_GAMES} from './rooms.js';

export function attachMultiplayer(server, {rooms = new Rooms(), enabled = false, origins = []} = {}) {
  const wss = new WebSocketServer({noServer: true, maxPayload: 65536, perMessageDeflate: false});
  const addresses = new Map();
  server.on('upgrade', (req, socket, head) => {
    // Native clients omit Origin. Browser clients require an explicit allowlist.
    const address = req.socket.remoteAddress;
    if (!enabled || req.url !== '/multiplayer' || wss.clients.size >= 800
      || (addresses.get(address) || 0) >= 16
      || (req.headers.origin && !origins.includes(req.headers.origin))) {
      socket.end('HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n'); return;
    }
    wss.handleUpgrade(req, socket, head, ws => {
      addresses.set(address, (addresses.get(address) || 0) + 1);
      ws.on('close', () => {
        const n = (addresses.get(address) || 1) - 1;
        if (n) addresses.set(address, n); else addresses.delete(address);
      });
      wss.emit('connection', ws);
    });
  });
  wss.on('connection', ws => {
    let count = 0, start = rooms.now(), lastPong = rooms.now(), controls = 0;
    const c = rooms.connect(message => {
      if (ws.readyState !== WebSocket.OPEN) return;
      if (ws.bufferedAmount > 256000) { ws.close(1013, 'slow_client'); return; }
      ws.send(JSON.stringify(message));
    });
    c.send({op: 'hello', v: PROTOCOL, games: ONLINE_GAMES, reconnect_ms: rooms.grace});
    ws.on('pong', () => { lastPong = rooms.now(); });
    ws.on('error', () => {});
    ws.on('message', (data, binary) => {
      if (rooms.now() - start >= 1000) { start = rooms.now(); count = 0; controls = 0; }
      if (++count > 90 || binary) { ws.close(1008, 'rate_or_format'); return; }
      try {
        const m = JSON.parse(data.toString());
        if (!['input', 'snapshot'].includes(m?.op) && ++controls > 12) throw new Error('rate_limit');
        rooms.handle(c, m);
      } catch (error) {
        // Only stable protocol codes, never echo untrusted payloads or credentials.
        const code = /^[a-z_]{1,40}$/.test(error.message) ? error.message : 'invalid_request';
        c.send({op: 'error', code});
      }
    });
    ws.on('close', () => rooms.disconnect(c));
    const heartbeat = setInterval(() => {
      // Godot's initial scene build is synchronous. Honor the load barrier's
      // budget instead of disconnecting healthy clients while assets compile.
      const timeout = c.room?.state === 'loading' ? 65000 : 30000;
      if (rooms.now() - lastPong > timeout) { ws.terminate(); return; }
      ws.ping();
    }, 10000);
    heartbeat.unref(); ws.on('close', () => clearInterval(heartbeat));
  });
  const sweep = setInterval(() => rooms.sweep(), 1000); sweep.unref();
  return {rooms, close() {
    clearInterval(sweep);
    for (const room of rooms.rooms.values()) rooms.close(room, 'server_shutdown');
    for (const ws of wss.clients) ws.terminate();
    wss.close();
  }};
}
