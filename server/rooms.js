import {randomBytes, randomInt} from 'node:crypto';

export const PROTOCOL = 1;
export const ONLINE_GAMES = ['ring_rumble'];
const CODE = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const fail = code => { throw new Error(code); };
const integer = (v, min, max) => Number.isInteger(v) && v >= min && v <= max;
const cleanName = v => typeof v === 'string' ? v.replace(/[\p{C}<>]/gu, '').trim().slice(0, 24) : '';

function validSnapshot(data, count) {
  if (!data || typeof data !== 'object' || Array.isArray(data)) return false;
  if (!['fighters', 'scores', 'alive'].every(key => Array.isArray(data[key]) && data[key].length === count)) return false;
  if (!integer(data.phase, 0, 11) || !integer(data.round, 0, 9) || !integer(data.countdown, 0, 10)
    || !Number.isFinite(data.radius) || data.radius < .1 || data.radius > 1000
    || !Number.isFinite(data.time) || data.time < 0 || data.time > 3600) return false;
  if (!data.scores.every(v => integer(v, -1000000, 1000000)) || !data.alive.every(v => typeof v === 'boolean')) return false;
  return data.fighters.every(f => f && typeof f === 'object' &&
    ['position', 'velocity', 'facing'].every(key => Array.isArray(f[key]) && f[key].length === 3 &&
      f[key].every(v => Number.isFinite(v) && Math.abs(v) <= 10000)) &&
    ['health', 'dash', 'attack', 'stun'].every(key => Number.isFinite(f[key]) && Math.abs(f[key]) <= 10000) &&
    typeof f.visible === 'boolean' && typeof f.alive === 'boolean');
}

// Room identity and permission checks live here, independently of WebSocket.
// No Apple identity, email or long-lived credential is needed for guest play.
export class Rooms {
  constructor({now = Date.now, grace = 30000, maxRooms = 200} = {}) {
    this.now = now; this.grace = grace; this.maxRooms = maxRooms;
    this.rooms = new Map(); this.sessions = new Map();
  }

  connect(send) { return {send, room: null, player: null}; }

  handle(connection, message) {
    if (!message || typeof message !== 'object' || Array.isArray(message)) fail('invalid_request');
    const c = connection, m = message;
    if (m.v !== PROTOCOL) fail('version_mismatch');
    if (m.op === 'list') {
      c.send({op: 'rooms', rooms: [...this.rooms.values()]
        .filter(r => r.public && r.state === 'lobby' && r.players.size < r.capacity && r.players.get(r.host)?.connection)
        .slice(0, 100).map(r => ({code: r.code, host: r.players.get(r.host).name, count: r.players.size, capacity: r.capacity}))});
      return;
    }
    if (m.op === 'ping') { c.send({op: 'pong', stamp: m.stamp}); return; }
    if (m.op === 'resume') return this.resume(c, m.token);
    if (m.op === 'create') {
      if (c.room) fail('already_joined');
      if (this.rooms.size >= this.maxRooms) fail('unavailable');
      if (!integer(m.capacity, 2, 4) || typeof m.public !== 'boolean') fail('invalid_request');
      let code;
      do { code = Array.from({length: 6}, () => CODE[randomInt(CODE.length)]).join(''); } while (this.rooms.has(code));
      const r = {code, public: m.public, capacity: m.capacity, host: 1, next: 1, players: new Map(),
        state: 'lobby', touched: this.now(), epoch: 0, snapshot: null, result: null,
        config: {game: 'ring_rumble', arena: 'vortex_ring', rounds: 3, bots: true, difficulty: 1}};
      this.rooms.set(code, r); this.join(c, r, m.name); return;
    }
    if (m.op === 'join') {
      if (c.room) fail('already_joined');
      const r = this.rooms.get(m.code);
      if (!r || r.state !== 'lobby' || !r.players.get(r.host)?.connection) fail('room_unavailable');
      if (r.players.size >= r.capacity) fail('room_full');
      this.join(c, r, m.name); return;
    }
    const r = c.room, p = c.player;
    if (!r || !p || p.connection !== c) fail('not_joined');
    r.touched = this.now();
    if (m.op === 'leave') { this.remove(r, p, 'left'); return; }
    if (m.op === 'ready') {
      if (r.state !== 'lobby' || typeof m.ready !== 'boolean') fail('invalid_state');
      p.ready = m.ready; this.broadcastRoom(r); return;
    }
    if (m.op === 'character') {
      if (r.state !== 'lobby' || !integer(m.character, 0, 7)) fail('invalid_request');
      p.character = m.character; p.ready = false; this.broadcastRoom(r); return;
    }
    if (m.op === 'configure') {
      this.host(c); if (r.state !== 'lobby') fail('invalid_state');
      const cfg = m.config;
      if (!cfg || !ONLINE_GAMES.includes(cfg.game) || !['vortex_ring', 'storm_ring'].includes(cfg.arena)
        || !integer(cfg.rounds, 1, 10) || typeof cfg.bots !== 'boolean' || !integer(cfg.difficulty, 0, 3)) fail('invalid_config');
      r.config = {game: cfg.game, arena: cfg.arena, rounds: cfg.rounds, bots: cfg.bots, difficulty: cfg.difficulty};
      for (const peer of r.players.values()) peer.ready = false;
      this.broadcastRoom(r); return;
    }
    if (m.op === 'kick') {
      this.host(c); if (r.state !== 'lobby' || m.id === r.host) fail('invalid_state');
      const victim = r.players.get(m.id); if (!victim) fail('not_found');
      this.remove(r, victim, 'kicked'); return;
    }
    if (m.op === 'start') {
      this.host(c);
      if (r.state !== 'lobby' || [...r.players.values()].some(p => !p.ready || !p.connection)) fail('not_ready');
      if (r.players.size < 2 && !r.config.bots) fail('not_enough_players');
      r.state = 'loading'; r.loadingAt = this.now(); r.epoch++; r.seed = randomInt(1, 2147483647); r.snapshot = null; r.result = null;
      // Slots are contiguous for the shared match runtime; peer IDs stay stable.
      [...r.players.values()].forEach((p, slot) => { p.slot = slot; p.loaded = false; p.sequence = -1; });
      r.roster = [...r.players.values()].map(p => ({id: p.id, slot: p.slot, name: p.name, character: p.character}));
      const count = r.config.bots ? r.capacity : r.roster.length;
      while (r.roster.length < count) r.roster.push({id: 0, slot: r.roster.length, name: '', character: r.roster.length % 8});
      this.broadcastRoom(r); this.broadcast(r, {op: 'start', ...this.match(r)}); return;
    }
    if (m.op === 'loaded') {
      if (m.epoch !== r.epoch || !['loading', 'playing'].includes(r.state)) fail('invalid_state');
      p.loaded = true;
      if (r.state === 'loading' && [...r.players.values()].every(p => p.loaded && p.connection)) {
        r.state = 'playing'; r.authoritySeen = this.now();
        this.broadcastRoom(r); this.broadcast(r, {op: 'go', epoch: r.epoch});
      } else if (r.state === 'playing') c.send({op: 'go', epoch: r.epoch});
      return;
    }
    if (m.op === 'input') {
      if (r.state !== 'playing' || m.epoch !== r.epoch) fail('invalid_state');
      if (!integer(m.sequence, 0, Number.MAX_SAFE_INTEGER) || m.sequence <= p.sequence
        || !Array.isArray(m.axes) || m.axes.length !== 4 || m.axes.some(v => !Number.isFinite(v) || Math.abs(v) > 1)
        || !integer(m.bits, 0, 31)) fail('invalid_input');
      p.sequence = m.sequence;
      r.players.get(r.host)?.connection?.send({op: 'input', id: p.id, slot: p.slot,
        epoch: r.epoch, sequence: m.sequence, axes: m.axes, bits: m.bits}); return;
    }
    if (m.op === 'snapshot') {
      this.host(c);
      if (r.state !== 'playing' || m.epoch !== r.epoch) fail('invalid_state');
      if (!validSnapshot(m.data, r.roster.length) || !integer(m.tick, 0, Number.MAX_SAFE_INTEGER) || m.tick <= (r.snapshot?.tick ?? -1)
        || Buffer.byteLength(JSON.stringify(m.data)) > 48000) fail('invalid_snapshot');
      r.snapshot = {op: 'snapshot', epoch: r.epoch, tick: m.tick, data: m.data};
      r.authoritySeen = this.now();
      this.broadcast(r, r.snapshot, p.id); return;
    }
    if (m.op === 'result') {
      this.host(c);
      if (r.state !== 'playing' || m.epoch !== r.epoch || !Array.isArray(m.scores)
        || m.scores.length !== r.roster.length || m.scores.some(v => !integer(v, -1000000, 1000000))) fail('invalid_result');
      r.state = 'results'; r.result = {op: 'result', epoch: r.epoch, scores: m.scores};
      this.broadcast(r, r.result); this.broadcastRoom(r); return;
    }
    if (m.op === 'lobby') {
      this.host(c); if (r.state !== 'results') fail('invalid_state');
      r.state = 'lobby'; r.snapshot = null;
      for (const peer of r.players.values()) peer.ready = false;
      this.broadcastRoom(r); return;
    }
    fail('unknown_operation');
  }

  host(c) { if (c.player.id !== c.room.host) fail('host_only'); }
  match(r) { return {epoch: r.epoch, seed: r.seed, config: r.config, players: r.roster}; }
  join(c, r, name) {
    const p = {id: r.next++, slot: r.players.size, name: cleanName(name) || 'Player', character: 0,
      ready: false, loaded: false, sequence: -1, connection: c, token: randomBytes(32).toString('base64url'), expires: 0};
    c.room = r; c.player = p; r.players.set(p.id, p); this.sessions.set(p.token, {r, p});
    c.send({op: 'welcome', id: p.id, token: p.token}); this.broadcastRoom(r);
  }
  resume(c, token) {
    if (c.room || typeof token !== 'string') fail('invalid_request');
    const session = this.sessions.get(token);
    if (!session) fail('session_expired');
    if (session.p.connection) fail('session_active');
    if (session.p.expires <= this.now()) fail('session_expired');
    const {r, p} = session; p.connection = c; p.expires = 0; c.room = r; c.player = p;
    c.send({op: 'welcome', id: p.id, token: p.token}); this.broadcastRoom(r);
    if (r.state !== 'lobby') c.send({op: 'start', ...this.match(r)});
    if (r.snapshot) c.send(r.snapshot);
    if (r.result) c.send(r.result);
  }
  disconnect(c) {
    if (!c.room || c.player?.connection !== c) return;
    const p = c.player; p.connection = null; p.expires = this.now() + this.grace;
    if (c.room.state === 'lobby') p.ready = false;
    this.broadcastRoom(c.room);
  }
  remove(r, p, reason) {
    if (p.id === r.host || r.state !== 'lobby') {
      // Host migration cannot recover an authoritative simulation. Never invent a winner.
      this.close(r, p.id === r.host ? 'host_left' : reason); return;
    }
    p.connection?.send({op: 'closed', reason});
    if (p.connection) { p.connection.room = null; p.connection.player = null; }
    this.sessions.delete(p.token); r.players.delete(p.id); this.broadcastRoom(r);
  }
  close(r, reason) {
    this.broadcast(r, {op: 'closed', reason});
    for (const p of r.players.values()) {
      this.sessions.delete(p.token);
      if (p.connection) { p.connection.room = null; p.connection.player = null; }
    }
    this.rooms.delete(r.code);
  }
  sweep() {
    for (const r of this.rooms.values()) {
      if (this.now() - r.touched > 1800000) { this.close(r, 'room_expired'); continue; }
      if (r.state === 'loading' && this.now() - r.loadingAt > 60000) { this.close(r, 'load_timeout'); continue; }
      if (r.state === 'playing' && this.now() - r.authoritySeen > this.grace) { this.close(r, 'authority_timeout'); continue; }
      for (const p of r.players.values()) if (!p.connection && p.expires <= this.now()) {
        this.remove(r, p, 'reconnect_timeout'); if (!this.rooms.has(r.code)) break;
      }
    }
  }
  view(r) {
    return {op: 'room', code: r.code, host: r.host, capacity: r.capacity, state: r.state, config: r.config,
      players: [...r.players.values()].map(p => ({id: p.id, slot: p.slot, name: p.name, character: p.character,
        ready: p.ready, connected: !!p.connection}))};
  }
  broadcastRoom(r) { this.broadcast(r, this.view(r)); }
  broadcast(r, message, except = 0) {
    for (const p of r.players.values()) if (p.id !== except) p.connection?.send(message);
  }
}
