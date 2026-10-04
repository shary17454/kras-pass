// Real Godot processes + real WebSocket service, with no production credentials.
import {createServer} from 'node:http';
import {once} from 'node:events';
import {spawn} from 'node:child_process';
import {mkdtemp, writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
import {monitorEventLoopDelay, performance} from 'node:perf_hooks';
import {NetworkTiming} from './network-timing.js';
import {attachMultiplayer} from './multiplayer.js';
import {ONLINE_GAMES, Rooms} from './rooms.js';
import {kartProcessDeadline} from './race-smoke-budget.js';
import {labProcessDeadline} from './lab-smoke-budget.js';
import {restoreFawdaFinal, assertFawdaNetworkEvidence, FAWDA_FINAL_SEED} from './fawda-final-checkpoint.js';

const root = fileURLToPath(new URL('../', import.meta.url));
const out = await mkdtemp(join(tmpdir(), 'kras-network-smoke-'));
const server = createServer();
const seedText = process.argv.find(arg => arg.startsWith('--seed='))?.slice(7);
const fawdaFinalCheckpoint = process.argv.includes('--fawda-final-checkpoint');
assert.ok(seedText === undefined || (/^[0-9]+$/.test(seedText)
  && Number.isSafeInteger(Number(seedText)) && Number(seedText) >= 1 && Number(seedText) <= 2147483646));
const service = attachMultiplayer(server, {enabled: true,
  rooms: fawdaFinalCheckpoint ? new Rooms({seed: () => FAWDA_FINAL_SEED})
    : seedText === undefined ? new Rooms() : new Rooms({seed: () => Number(seedText)})});
if (fawdaFinalCheckpoint) {
  const beginRound = service.rooms.beginRound.bind(service.rooms);
  service.rooms.beginRound = room => {
    if (room.epoch === 0) {
      console.log(JSON.stringify({event: 'restored_fawda_final', standings: restoreFawdaFinal(room)}));
    }
    beginRound(room);
  };
}
const loopDelay = monitorEventLoopDelay({resolution: 20});
loopDelay.enable();
const timing = new NetworkTiming();
const timingInterval = setInterval(() => timing.sample(service.rooms.rooms.values()), 100);
timingInterval.unref();
const handle = service.rooms.handle.bind(service.rooms);
service.rooms.handle = (connection, message) => {
  const began = performance.now();
  const beganCpu = process.cpuUsage();
  try {
    const result = handle(connection, message);
    if (['start', 'next', 'loaded', 'resume', 'result'].includes(message.op)) {
      console.log(JSON.stringify({event: 'transition', op: message.op,
        state: connection.room?.state, epoch: connection.room?.epoch,
        game: connection.room?.matchConfig?.game, arena: connection.room?.matchConfig?.arena,
        host: connection.player?.id === connection.room?.host,
        serverLoopMaxMs: Math.round(loopDelay.max / 1e6)}));
    }
    return result;
  }
  catch (error) {
    console.error(JSON.stringify({event: 'protocol_error', op: message.op,
      state: connection.room?.state, epoch: message.epoch, reason: error.message}));
    throw error;
  }
  finally {
    const elapsed = performance.now() - began;
    const usedCpu = process.cpuUsage(beganCpu);
    timing.recordOperation(message.op, elapsed, (usedCpu.user + usedCpu.system) / 1000);
  }
};
const closeRoom = service.rooms.close.bind(service.rooms);
service.rooms.close = (room, reason) => {
  console.log(JSON.stringify({event: 'room_closed', state: room.state, reason,
    authorityAge: Math.round(service.rooms.now() - (room.authoritySeen ?? service.rooms.now()))}));
  closeRoom(room, reason);
};
const children = [];
const tournament = process.argv.includes('--tournament');
const duoTiebreak = process.argv.includes('--duo-tiebreak');
const raceTiebreak = process.argv.includes('--race-tiebreak');
const siegeTiebreak = process.argv.includes('--siege-tiebreak');
const forgeTiebreak = process.argv.includes('--forge-tiebreak');
const dreadTiebreak = process.argv.includes('--dread-tiebreak');
const sovereignTiebreak = process.argv.includes('--sovereign-tiebreak');
const game = process.argv.find(arg => arg.startsWith('--game='))?.slice(7)
  ?? (process.argv.includes('--goal-guard') ? 'goal_guard' : 'ring_rumble');
assert.ok(ONLINE_GAMES.includes(game));
assert.ok(!duoTiebreak || (tournament && game === 'duo_clash'));
assert.ok(!raceTiebreak || (tournament && ['kart_sprint', 'sabaq_sawarikh'].includes(game)));
assert.ok(!siegeTiebreak || (tournament && game === 'base_siege'));
assert.ok(!forgeTiebreak || (tournament && game === 'boss_forge'));
assert.ok(!dreadTiebreak || (tournament && game === 'boss_dreadnought'));
assert.ok(!sovereignTiebreak || (tournament && game === 'boss_sovereign'));
const selectedHumans = process.argv.find(arg => arg.startsWith('--humans='))?.slice(9);
assert.ok(!fawdaFinalCheckpoint || (tournament && game === 'fawda' && selectedHumans === '2' && seedText === undefined));
assert.ok(selectedHumans === undefined || ['2', '4'].includes(selectedHumans));
assert.ok(!duoTiebreak || selectedHumans === undefined || selectedHumans === '4');
assert.ok(!raceTiebreak || selectedHumans === undefined || selectedHumans === '4');
assert.ok(!siegeTiebreak || selectedHumans === undefined || selectedHumans === '4');
assert.ok(!forgeTiebreak || selectedHumans === undefined || selectedHumans === '4');
assert.ok(!dreadTiebreak || selectedHumans === undefined || selectedHumans === '4');
assert.ok(!sovereignTiebreak || selectedHumans === undefined || selectedHumans === '4');
server.listen(0, '127.0.0.1'); await once(server, 'listening');
const url = `ws://127.0.0.1:${server.address().port}/multiplayer`;
console.log(`Evidence: ${out}`);
try {
  for (const humans of selectedHumans ? [Number(selectedHumans)] : (duoTiebreak || raceTiebreak || siegeTiebreak || forgeTiebreak || dreadTiebreak || sovereignTiebreak ? [4] : [2, 4])) {
    let resolveRoom;
    const roomCode = new Promise(resolve => { resolveRoom = resolve; });
    function peer(index, code = '') {
      const name = `${humans}-players-${index}`;
      const child = spawn(process.env.GODOT_BIN || 'godot', ['--headless', '--path', root,
        '--log-file', join(out, `${name}.log`), 'tests/network_peer.tscn', '--',
        `--test-data-dir=${join(out, `${name}-save`)}`, `--humans=${humans}`,
        `--game=${game}`,
        index === 0 ? '--host' : `--room=${code}`, ...(index === 0 ? ['--drop-host-result'] : []),
        ...(tournament ? ['--tournament'] : []), ...(duoTiebreak ? ['--duo-tiebreak'] : []),
        ...(fawdaFinalCheckpoint ? ['--fawda-final-checkpoint'] : []),
        ...(raceTiebreak ? ['--race-tiebreak'] : []), ...(siegeTiebreak ? ['--siege-tiebreak'] : []),
        ...(forgeTiebreak ? ['--forge-tiebreak'] : []), ...(dreadTiebreak ? ['--dread-tiebreak'] : []),
        ...(sovereignTiebreak ? ['--sovereign-tiebreak'] : [])],
      {env: {...process.env, KRAS_MULTIPLAYER_URL: url}, stdio: ['ignore', 'pipe', 'pipe']});
      children.push(child);
      let output = '', roomAnnounced = false;
      const collect = chunk => {
        output += chunk.toString();
        const match = /NETWORK_ROOM=([A-Z2-9]{6})/.exec(output);
        if (index === 0 && match && !roomAnnounced) { roomAnnounced = true; resolveRoom(match[1]); }
      };
      child.stdout.on('data', collect); child.stderr.on('data', collect);
      return new Promise((resolve, reject) => {
        const deadline = game === 'kart_sprint' ? kartProcessDeadline(tournament)
          : game === 'lab_crates' ? labProcessDeadline(tournament)
          : game === 'sabaq_sawarikh' ? (tournament ? 960000 : 660000)
          : ['boss_forge', 'boss_dreadnought', 'boss_sovereign', 'boss_colossus'].includes(game) ? (tournament ? 800000 : 450000) : (tournament ? 360000 : 180000);
        const timer = setTimeout(() => { child.kill('SIGTERM'); reject(new Error(`${name} timeout`)); }, deadline);
        child.on('error', reject);
        child.on('exit', async code => {
          clearTimeout(timer); await writeFile(join(out, `${name}.stdout`), output);
          if (code !== 0 || /SCRIPT ERROR:|NETWORK_FAIL=|Parse Error:|ObjectDB instances leaked/.test(output)) {
            reject(new Error(`${name} failed: ${output.slice(-5000)}`)); return;
          }
          const result = /NETWORK_FINISHED=(.+)/.exec(output);
          if (!result) { reject(new Error(`${name}: no result`)); return; }
          resolve(JSON.parse(result[1]));
        });
      });
    }
    const host = peer(0);
    const code = await Promise.race([roomCode, host.then(() => { throw new Error('host exited before room'); })]);
    const results = await Promise.all([host, ...Array.from({length: humans - 1}, (_, i) => peer(i + 1, code))]);
    for (const result of results) assert.deepEqual(result.scores, results[0].scores);
    if (game === 'fawda') {
      assertFawdaNetworkEvidence(results, fawdaFinalCheckpoint);
    }
    assert.equal(new Set(results.map(r => r.id)).size, humans);
    assert.ok(results.some(r => r.reconnected));
    assert.equal(results[0].reconnected, true, 'host result must survive transport loss');
    if (tournament) {
      for (const result of results) {
        assert.ok(result.matches >= (fawdaFinalCheckpoint ? 1 : 3));
        assert.equal(result.tournament.complete, true);
        assert.deepEqual(result.tournament, results[0].tournament);
      }
    }
    if (duoTiebreak) {
      assert.ok(results[0].matches > 3, 'an individual tiebreak must actually run');
      assert.deepEqual(results[0].tournament.points, [3, 3, 3, 3]);
      assert.deepEqual(results[0].tournament.awards, [0, 0, 0, 0]);
      assert.ok(results[0].tournament.tie_attempts > 0);
    }
    if (raceTiebreak) {
      assert.ok(results[0].matches > 3, 'a one-lap race final must actually run');
      assert.deepEqual(results[0].tournament.points, [3, 3, 3, 3]);
      assert.deepEqual(results[0].tournament.awards, [0, 0, 0, 0]);
      assert.ok(results[0].tournament.tie_attempts > 0);
    }
    if (siegeTiebreak) {
      assert.ok(results[0].matches > 3, 'a Siege final must actually run');
      assert.deepEqual(results[0].tournament.points, [3, 3, 3, 3]);
      assert.deepEqual(results[0].tournament.awards, [0, 0, 0, 0]);
      assert.ok(results[0].tournament.tie_attempts > 0);
    }
    if (forgeTiebreak || dreadTiebreak || sovereignTiebreak) {
      assert.ok(results[0].matches > 3, 'a boss final must actually run');
      assert.deepEqual(results[0].tournament.points, [3, 3, 3, 3]);
      assert.deepEqual(results[0].tournament.awards, [0, 0, 0, 0]);
      assert.ok(results[0].tournament.tie_attempts > 0);
    }
    console.log(JSON.stringify({humans, status: 'PASS', results}));
  }
} finally {
  clearInterval(timingInterval);
  loopDelay.disable();
  await writeFile(join(out, 'server-timing.json'), JSON.stringify(timing.report(), null, 2));
  console.log(JSON.stringify({event: 'server_timing', maxMs: Math.round(loopDelay.max / 1e6)}));
  for (const child of children) if (child.exitCode === null) child.kill('SIGTERM');
  service.close(); await new Promise(resolve => server.close(resolve));
}
