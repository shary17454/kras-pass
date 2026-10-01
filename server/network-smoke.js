// Real Godot processes + real WebSocket service, with no production credentials.
import {createServer} from 'node:http';
import {once} from 'node:events';
import {spawn} from 'node:child_process';
import {mkdtemp, writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
import {attachMultiplayer} from './multiplayer.js';

const root = fileURLToPath(new URL('../', import.meta.url));
const out = await mkdtemp(join(tmpdir(), 'kras-network-smoke-'));
const server = createServer();
const service = attachMultiplayer(server, {enabled: true});
const closeRoom = service.rooms.close.bind(service.rooms);
service.rooms.close = (room, reason) => {
  console.log(JSON.stringify({event: 'room_closed', state: room.state, reason,
    authorityAge: Date.now() - (room.authoritySeen || Date.now())}));
  closeRoom(room, reason);
};
const children = [];
server.listen(0, '127.0.0.1'); await once(server, 'listening');
const url = `ws://127.0.0.1:${server.address().port}/multiplayer`;
console.log(`Evidence: ${out}`);
try {
  for (const humans of [2, 4]) {
    let resolveRoom;
    const roomCode = new Promise(resolve => { resolveRoom = resolve; });
    function peer(index, code = '') {
      const name = `${humans}-players-${index}`;
      const child = spawn(process.env.GODOT_BIN || 'godot', ['--headless', '--path', root,
        '--log-file', join(out, `${name}.log`), 'tests/network_peer.tscn', '--',
        `--test-data-dir=${join(out, `${name}-save`)}`, `--humans=${humans}`,
        index === 0 ? '--host' : `--room=${code}`, ...(index === 0 ? ['--drop-host-result'] : [])],
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
        const timer = setTimeout(() => { child.kill('SIGTERM'); reject(new Error(`${name} timeout`)); }, 180000);
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
    assert.equal(new Set(results.map(r => r.id)).size, humans);
    assert.ok(results.some(r => r.reconnected));
    assert.equal(results[0].reconnected, true, 'host result must survive transport loss');
    console.log(JSON.stringify({humans, status: 'PASS', results}));
  }
} finally {
  for (const child of children) if (child.exitCode === null) child.kill('SIGTERM');
  service.close(); await new Promise(resolve => server.close(resolve));
}
