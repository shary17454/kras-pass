import {createServer} from 'node:http';
import {once} from 'node:events';
import {performance, monitorEventLoopDelay} from 'node:perf_hooks';
import {writeFile} from 'node:fs/promises';
import WebSocket from '../server/node_modules/ws/wrapper.mjs';
import {attachMultiplayer} from '../server/multiplayer.js';
import {Rooms, PROTOCOL} from '../server/rooms.js';
import {NetworkTiming} from '../server/network-timing.js';

const server = createServer(), rooms = new Rooms(), timing = new NetworkTiming();
const handle = rooms.handle.bind(rooms);
rooms.handle = (client, message) => {
  const begin = performance.now(), cpu = process.cpuUsage();
  try { return handle(client, message); }
  finally {
    const used = process.cpuUsage(cpu);
    timing.recordOperation(message.op, performance.now() - begin, (used.user + used.system) / 1000);
  }
};
const service = attachMultiplayer(server, {rooms, enabled: true});
const clients = [], timers = [], errors = [], sentSnapshots = new Map(), sentInputs = new Map();
const snapshotLatencies = [], inputLatencies = [];
const loop = monitorEventLoopDelay({resolution: 10});
function percentile(values, fraction) {
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * fraction))] ?? null;
}
function metrics(values) {
  return {count: values.length, p50_ms: percentile(values, .5), p95_ms: percentile(values, .95),
    p99_ms: percentile(values, .99), max_ms: values.length ? Math.max(...values) : null};
}
try {
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  for (let slot = 0; slot < 4; slot++) {
    const ws = new WebSocket(`ws://127.0.0.1:${server.address().port}/multiplayer`);
    const pending = [], history = [];
    const client = {ws, history, send: m => ws.send(JSON.stringify({v: PROTOCOL, ...m})),
      wait: op => new Promise((resolve, reject) => {
        const timeout = setTimeout(() => reject(new Error(`timeout ${op}`)), 5000);
        timers.push(timeout);
        pending.push({op, resolve: message => { clearTimeout(timeout); resolve(message); }});
      })};
    clients.push(client);
    ws.on('error', error => errors.push(error.message));
    ws.on('message', data => {
      const message = JSON.parse(data); history.push(message.op);
      if (message.op === 'error') errors.push(message.code);
      if (message.op === 'snapshot' && sentSnapshots.has(message.tick))
        snapshotLatencies.push(performance.now() - sentSnapshots.get(message.tick));
      if (message.op === 'input') {
        const key = `${message.slot}:${message.sequence}`;
        if (sentInputs.has(key)) { inputLatencies.push(performance.now() - sentInputs.get(key)); sentInputs.delete(key); }
      }
      for (const waiter of [...pending]) if (waiter.op === message.op) {
        pending.splice(pending.indexOf(waiter), 1); waiter.resolve(message);
      }
    });
    await Promise.all([once(ws, 'open'), client.wait('hello')]);
  }
  const host = clients[0];
  let changed = host.wait('room'); host.send({op: 'create', capacity: 4, public: false});
  const code = (await changed).code;
  for (const client of clients.slice(1)) {
    changed = client.wait('room'); client.send({op: 'join', code}); await changed;
  }
  for (const client of clients) {
    changed = client.wait('room'); client.send({op: 'ready', ready: true}); await changed;
  }
  const starts = clients.map(client => client.wait('start')); host.send({op: 'start'});
  const epoch = (await Promise.all(starts))[0].epoch;
  const goes = clients.map(client => client.wait('go'));
  clients.forEach(client => client.send({op: 'loaded', epoch})); await Promise.all(goes);
  const data = {phase: 4, round: 0, countdown: 0, radius: 10, time: 50,
    scores: [0, 1, 0, 0], alive: [true, true, true, true],
    fighters: Array.from({length: 4}, () => ({position: [0, 0, 0], velocity: [0, 0, 0],
      facing: [0, 0, 1], health: 100, dash: 0, attack: 0, stun: 0, visible: true, alive: true}))};
  let sequence = 0, tick = 0;
  loop.enable(); const cpu = process.cpuUsage(), begin = performance.now();
  const inputTimer = setInterval(() => {
    sequence++;
    clients.slice(1).forEach((client, index) => {
      sentInputs.set(`${index + 1}:${sequence}`, performance.now());
      client.send({op: 'input', epoch, sequence, axes: [.5, 0, 0, 0], bits: 0});
    });
  }, 1000 / 30);
  const snapshotTimer = setInterval(() => {
    tick++; sentSnapshots.set(tick, performance.now());
    host.send({op: 'snapshot', epoch, tick, data});
  }, 50);
  const sampleTimer = setInterval(() => timing.sample(rooms.rooms.values()), 100);
  timers.push(inputTimer, snapshotTimer, sampleTimer);
  await new Promise(resolve => setTimeout(resolve, 30000));
  clearInterval(inputTimer); clearInterval(snapshotTimer); clearInterval(sampleTimer);
  await new Promise(resolve => setTimeout(resolve, 200));
  loop.disable(); const used = process.cpuUsage(cpu);
  const report = {source: 'dffeb06dc1c82ff57be9c7889e2f728f9d9df2f3',
    scope: 'loopback, one room, four synthetic Node clients, no Godot; not production or device acceptance',
    duration_ms: performance.now() - begin, cpu_ms: (used.user + used.system) / 1000,
    input_hz_per_guest: 30, snapshot_hz: 20, snapshot_bytes: Buffer.byteLength(JSON.stringify(data)),
    inputs_sent: sequence * 3, snapshots_sent: tick, input_latency: metrics(inputLatencies),
    snapshot_latency: metrics(snapshotLatencies), event_loop_max_ms: loop.max / 1e6,
    event_loop_p99_ms: loop.percentile(99) / 1e6, errors, timing: timing.report()};
  await writeFile('/tmp/kras-room-isolation-report.json', JSON.stringify(report, null, 2));
  console.log(JSON.stringify(report, null, 2));
  if (errors.length || inputLatencies.length !== sequence * 3 || snapshotLatencies.length !== tick * 3)
    throw new Error('traffic incomplete or protocol errors');
} finally {
  for (const timer of timers) clearTimeout(timer);
  clients.forEach(client => client.ws.terminate()); service.close();
  await new Promise(resolve => server.close(resolve));
}
