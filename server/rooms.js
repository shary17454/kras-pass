import {randomBytes, randomInt} from 'node:crypto';
import {performance} from 'node:perf_hooks';
import {Tournament} from './tournament.js';
import {validGoalGuardWorld, validCollectionWorld, validZoneWorld, validRelicWorld, validTagWorld, validPaintWorld, validSaboteurWorld, validMagnetWorld, validStormWorld, validSkyWorld, validCrumbleWorld, validBlastWorld, validColorWorld, validDrawWorld} from './world-snapshots.js';

export const PROTOCOL = 1;
export const ONLINE_ARENAS = Object.freeze({ring_rumble: ['vortex_ring', 'storm_ring'], goal_guard: ['quad_court'],
  gem_grab: ['gem_hollow', 'glass_terrace'], star_rush: ['star_meadow'], zone_hold: ['dune_ring'],
  relic_hold: ['star_meadow', 'gem_hollow'], tag_hunt: ['star_meadow', 'paint_grid'],
  paint_grid: ['paint_grid'], mnatiq: ['paint_grid'], mukharrib: ['paint_grid'], magnet_court: ['quad_court'], storm_heart: ['quad_court'], sky_court: ['quad_court'], crumble_court: ['crumble_court'], blast_ball: ['ember_pit'], color_stand: ['color_floor'], quick_draw: ['draw_stage']});
export const ONLINE_GAMES = Object.keys(ONLINE_ARENAS);
const CODE = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const fail = code => { throw new Error(code); };
const integer = (v, min, max) => Number.isInteger(v) && v >= min && v <= max;
const validInput = m => integer(m.sequence, 0, Number.MAX_SAFE_INTEGER)
  && Array.isArray(m.axes) && m.axes.length === 4
  && m.axes.every(v => Number.isFinite(v) && Math.abs(v) <= 1) && integer(m.bits, 0, 31);
const cleanName = v => typeof v === 'string' ? v.replace(/[\p{C}<>]/gu, '').trim().slice(0, 24) : '';

function tournamentSettings(value) {
  if (value == null) return null;
  if (!['points', 'cups'].includes(value.mode) || !integer(value.target, 3, 10)
    || !['manual', 'random_no_repeat'].includes(value.rotation)
    || !Array.isArray(value.entries) || value.entries.length < 1 || value.entries.length > 39
    || !Array.isArray(value.points) || value.points.length !== 4
    || value.points.some((v, i) => !integer(v, 0, 100) || (i > 0 && v > value.points[i - 1]))) fail('invalid_config');
  const entries = value.entries.map(e => {
    if (!e || !ONLINE_GAMES.includes(e.game) || !ONLINE_ARENAS[e.game].includes(e.arena)) fail('invalid_config');
    return {game: e.game, arena: e.arena};
  });
  if (new Set(entries.map(e => `${e.game}:${e.arena}`)).size !== entries.length) fail('invalid_config');
  return {mode: value.mode, target: value.target, rotation: value.rotation, entries, points: [...value.points]};
}

function validSnapshot(data, count, game) {
  if (!data || typeof data !== 'object' || Array.isArray(data)) return false;
  if (game === 'goal_guard' && !validGoalGuardWorld(data.world, count)) return false;
  if (game === 'magnet_court' && !validMagnetWorld(data.world, count)) return false;
  if (game === 'storm_heart' && !validStormWorld(data.world, count)) return false;
  if (game === 'sky_court' && !validSkyWorld(data.world, count)) return false;
  if (game === 'crumble_court' && !validCrumbleWorld(data.world)) return false;
  if (game === 'blast_ball' && !validBlastWorld(data.world)) return false;
  if (game === 'color_stand' && !validColorWorld(data.world)) return false;
  if (game === 'quick_draw' && !validDrawWorld(data.world, count)) return false;
  if (game === 'zone_hold' && !validZoneWorld(data.world)) return false;
  if (game === 'relic_hold' && !validRelicWorld(data.world, count)) return false;
  if (game === 'tag_hunt' && !validTagWorld(data.world, count)) return false;
  if (['paint_grid', 'mnatiq'].includes(game) && !validPaintWorld(data.world, count)) return false;
  if (game === 'mukharrib' && !validSaboteurWorld(data.world, count)) return false;
  if (['gem_grab', 'star_rush'].includes(game) && !validCollectionWorld(data.world, count, game === 'gem_grab' ? 'gem' : 'star')) return false;
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
  constructor({now = () => performance.now(), grace = 30000, maxRooms = 200} = {}) {
    this.now = now; this.grace = grace; this.maxRooms = maxRooms;
    this.rooms = new Map(); this.sessions = new Map();
  }

  connect(send) { return {send, room: null, player: null, retiredMatch: null}; }

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
        state: 'lobby', touched: this.now(), epoch: 0, snapshot: null, result: null, tournament: null,
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
    if (m.op === 'leave' && !r) return;
    // Drain only well-formed input already in flight on this room's connection.
    // This short-lived marker conveys no membership, forwarding or authority.
    if (!r && !p && m.op === 'input' && c.retiredMatch
      && this.now() < c.retiredMatch.until && integer(m.epoch, 1, c.retiredMatch.epoch)
      && validInput(m)) return;
    if (!r || !p || p.connection !== c) fail('not_joined');
    r.touched = this.now();
    if (m.op === 'leave') { this.remove(r, p, 'left'); return; }
    if (m.op === 'ready') {
      if (!(r.state === 'lobby' || (r.state === 'results' && r.tournament && !r.tournament.complete))
        || typeof m.ready !== 'boolean') fail('invalid_state');
      p.ready = m.ready; this.broadcastRoom(r); return;
    }
    if (m.op === 'character') {
      if (r.state !== 'lobby' || !integer(m.character, 0, 7)) fail('invalid_request');
      p.character = m.character; p.ready = false; this.broadcastRoom(r); return;
    }
    if (m.op === 'configure') {
      this.host(c); if (r.state !== 'lobby') fail('invalid_state');
      const cfg = m.config;
      if (!cfg || !ONLINE_GAMES.includes(cfg.game) || !ONLINE_ARENAS[cfg.game].includes(cfg.arena)
        || !integer(cfg.rounds, 1, 10) || typeof cfg.bots !== 'boolean' || !integer(cfg.difficulty, 0, 3)) fail('invalid_config');
      const tournament = tournamentSettings(cfg.tournament);
      r.config = {game: cfg.game, arena: cfg.arena, rounds: cfg.rounds, bots: cfg.bots, difficulty: cfg.difficulty, tournament};
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
      // Slots are contiguous for the shared match runtime; peer IDs stay stable.
      [...r.players.values()].forEach((p, slot) => { p.slot = slot; p.loaded = false; p.sequence = -1; });
      r.roster = [...r.players.values()].map(p => ({id: p.id, slot: p.slot, name: p.name, character: p.character}));
      const count = r.config.bots ? r.capacity : r.roster.length;
      while (r.roster.length < count) r.roster.push({id: 0, slot: r.roster.length, name: '', character: r.roster.length % 8});
      r.tournament = r.config.tournament ? new Tournament(count, r.config.tournament, randomInt(1, 2147483647)) : null;
      this.beginRound(r); return;
    }
    if (m.op === 'next') {
      this.host(c);
      if (r.state !== 'results' || !r.tournament || r.tournament.complete) fail('invalid_state');
      if ([...r.players.values()].some(p => !p.ready || !p.connection)) fail('not_ready');
      this.beginRound(r); return;
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
      // A guest can have input in flight when the host finishes or advances.
      // Never apply it to the results screen or to a different round.
      if (integer(m.epoch, 1, r.epoch)
        && (m.epoch < r.epoch || r.state === 'results')) return;
      if (r.state !== 'playing' || m.epoch !== r.epoch) fail('invalid_state');
      if (!validInput(m) || m.sequence <= p.sequence) fail('invalid_input');
      p.sequence = m.sequence;
      r.players.get(r.host)?.connection?.send({op: 'input', id: p.id, slot: p.slot,
        epoch: r.epoch, sequence: m.sequence, axes: m.axes, bits: m.bits}); return;
    }
    if (m.op === 'snapshot') {
      this.host(c);
      if (integer(m.epoch, 1, r.epoch)
        && (m.epoch < r.epoch || r.state === 'results')) return;
      if (r.state !== 'playing' || m.epoch !== r.epoch) fail('invalid_state');
      if (!validSnapshot(m.data, r.roster.length, r.matchConfig.game) || !integer(m.tick, 0, Number.MAX_SAFE_INTEGER) || m.tick <= (r.snapshot?.tick ?? -1)
        || Buffer.byteLength(JSON.stringify(m.data)) > 48000) fail('invalid_snapshot');
      r.snapshot = {op: 'snapshot', epoch: r.epoch, tick: m.tick, data: m.data};
      r.authoritySeen = this.now();
      this.broadcast(r, r.snapshot, p.id); return;
    }
    if (m.op === 'result') {
      this.host(c);
      if (r.state !== 'playing' || m.epoch !== r.epoch || !Array.isArray(m.scores)
        || m.scores.length !== r.roster.length || m.scores.some(v => !integer(v, -1000000, 1000000))) fail('invalid_result');
      if (r.tournament) r.tournament.record(r.epoch, m.scores);
      for (const peer of r.players.values()) peer.ready = false;
      r.state = 'results'; r.result = {op: 'result', epoch: r.epoch, scores: m.scores, tournament: r.tournament?.view() ?? null};
      this.broadcast(r, r.result); this.broadcastRoom(r); return;
    }
    if (m.op === 'lobby') {
      this.host(c); if (r.state !== 'results') fail('invalid_state');
      r.state = 'lobby'; r.snapshot = null; r.result = null; r.tournament = null;
      for (const peer of r.players.values()) peer.ready = false;
      this.broadcastRoom(r); return;
    }
    fail('unknown_operation');
  }

  host(c) { if (c.player.id !== c.room.host) fail('host_only'); }
  beginRound(r) {
    r.state = 'loading'; r.loadingAt = this.now(); r.epoch++; r.seed = randomInt(1, 2147483647);
    r.snapshot = null; r.result = null;
    r.matchConfig = {...r.config};
    if (r.tournament) r.matchConfig = {...r.config, ...r.tournament.next(), rounds: 1};
    for (const p of r.players.values()) { p.loaded = false; p.sequence = -1; p.ready = false; }
    this.broadcastRoom(r); this.broadcast(r, {op: 'start', ...this.match(r)});
  }
  match(r) { return {epoch: r.epoch, seed: r.seed, config: r.matchConfig, players: r.roster,
    tournament: r.tournament?.view() ?? null}; }
  join(c, r, name) {
    const usedSlots = new Set([...r.players.values()].map(p => p.slot));
    let slot = 0;
    while (usedSlots.has(slot)) slot++;
    const p = {id: r.next++, slot, name: cleanName(name) || 'Player', character: 0,
      ready: false, loaded: false, sequence: -1, connection: c, token: randomBytes(32).toString('base64url'), expires: 0};
    c.retiredMatch = null;
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
    c.retiredMatch = null;
    if (p.id === r.host && r.state === 'playing') r.authoritySeen = this.now();
    c.send({op: 'welcome', id: p.id, token: p.token}); this.broadcastRoom(r);
    if (r.state !== 'lobby') c.send({op: 'start', ...this.match(r)});
    if (r.state !== 'lobby' && r.snapshot) c.send(r.snapshot);
    if (r.state === 'results' && r.result) c.send(r.result);
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
      if (p.connection) {
        p.connection.retiredMatch = r.epoch > 0 ? {epoch: r.epoch, until: this.now() + 1000} : null;
        p.connection.room = null; p.connection.player = null;
      }
    }
    this.rooms.delete(r.code);
  }
  sweep() {
    for (const r of this.rooms.values()) {
      if (this.now() - r.touched > 1800000) { this.close(r, 'room_expired'); continue; }
      if (r.state === 'loading' && this.now() - r.loadingAt > 60000) { this.close(r, 'load_timeout'); continue; }
      // A disconnected host has its own full grace period starting at disconnect.
      if (r.state === 'playing' && r.players.get(r.host)?.connection
        && this.now() - r.authoritySeen > this.grace) { this.close(r, 'authority_timeout'); continue; }
      for (const p of r.players.values()) if (!p.connection && p.expires <= this.now()) {
        this.remove(r, p, 'reconnect_timeout'); if (!this.rooms.has(r.code)) break;
      }
    }
  }
  view(r) {
    return {op: 'room', code: r.code, host: r.host, capacity: r.capacity, state: r.state, config: r.config,
      tournament: r.tournament?.view() ?? null,
      players: [...r.players.values()].map(p => ({id: p.id, slot: p.slot, name: p.name, character: p.character,
        ready: p.ready, connected: !!p.connection}))};
  }
  broadcastRoom(r) { this.broadcast(r, this.view(r)); }
  broadcast(r, message, except = 0) {
    for (const p of r.players.values()) if (p.id !== except) p.connection?.send(message);
  }
}
