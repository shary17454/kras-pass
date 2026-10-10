import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {spawnSync} from 'node:child_process';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';

const guard = fileURLToPath(new URL('./check_godot_log.sh', import.meta.url));

function inspect(log, mode = 'runtime') {
  const directory = fs.mkdtempSync(join(tmpdir(), 'kras-log-guard-'));
  const filename = join(directory, 'engine.log');
  try {
    fs.writeFileSync(filename, log);
    const result = spawnSync('sh', [guard, filename, mode], {encoding: 'utf8'});
    assert.equal(result.error, undefined);
    assert.equal(result.signal, null);
    return result.status;
  } finally {
    fs.rmSync(directory, {recursive: true});
  }
}

test('resource and scene loading failures cannot pass with exit zero', () => {
  for (const message of ['ERROR: Failed loading resource: res://missing.tscn.',
    'ERROR: Failed loading scene: res://missing.tscn.']) {
    assert.notEqual(inspect(message), 0);
  }
});

test('compile requires a positive count and completed success summary', () => {
  for (const log of ['Godot Engine\n', 'compile check: 456 scripts\n',
    'compile check: 0 scripts\nOK - every script compiles\n',
    'OK - every script compiles\n']) {
    assert.notEqual(inspect(log, 'compile'), 0);
  }
  assert.equal(inspect('compile check: 456 scripts\nOK - every script compiles\n', 'compile'), 0);
});

test('fatal diagnostics override a positive summary', () => {
  for (const message of ['SCRIPT ERROR: missing method', 'Parse Error: invalid script',
    'ObjectDB instances leaked', 'FAILED - 1 failed',
    'ERROR: Failed loading resource: res://missing.tscn.']) {
    assert.notEqual(inspect(`compile check: 456 scripts\nOK - every script compiles\n${message}`, 'compile'), 0);
  }
});

test('test completion requires at least one assertion', () => {
  assert.equal(inspect('ALL TESTS PASSED - 12 assertions\n', 'tests'), 0);
  assert.notEqual(inspect('ALL TESTS PASSED - 0 assertions\n', 'tests'), 0);
  assert.notEqual(inspect('Godot Engine\n', 'tests'), 0);
});

test('runtime preserves intentional error injection and platform warnings', () => {
  assert.equal(inspect('ERROR: intentional save failure injection\n'), 0);
  assert.equal(inspect('ERROR: Condition "ret != noErr" is true. Returning: ""\n'), 0);
  assert.equal(inspect('balance simulation completed\n'), 0);
});

test('import remains stricter than runtime', () => {
  assert.notEqual(inspect('ERROR: import failure\n', 'import'), 0);
  assert.equal(inspect('import completed\n', 'import'), 0);
});

test('unexpected save failures invalidate runtime qualification', () => {
  const failure = 'ERROR: [ERR][Save] cannot open /tmp/isolated/profile.json.tmp for write\n';
  for (const mode of ['runtime', 'balance', 'stability', 'compile']) {
    assert.notEqual(inspect(`compile check: 458 scripts\nOK - every script compiles\n${failure}`, mode), 0);
  }
  // Save regression suites intentionally simulate unwritable destinations.
  assert.equal(inspect(`${failure}ALL TESTS PASSED - 12 assertions\n`, 'tests'), 0);
  assert.notEqual(inspect(failure, 'tests'), 0);
});
