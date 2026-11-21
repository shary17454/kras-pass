import test from 'node:test';
import assert from 'node:assert/strict';
import {inspectExportLog} from './check-ios-export-log.mjs';

const path = 'res://addons/kras_apple_runtime/kras_apple.gdextension';
const known = `ERROR: No GDExtension library found for current OS and architecture (macos.arm64) in configuration file: ${path}\nERROR: GDExtension dynamic library not found: '${path}'.\nERROR: Error loading extension: '${path}'.`;

test('clean logs remain distinguishable from expected editor diagnostics', () => {
  assert.deepEqual(inspectExportLog('Godot Engine\nExport complete'), {fatal: [], platformDiagnostics: [], clean: true});
  const result = inspectExportLog(known);
  assert.equal(result.clean, false);
  assert.equal(result.fatal.length, 0);
  assert.equal(result.platformDiagnostics.length, 3);
});

test('unknown errors mixed with expected diagnostics still fail', () => {
  for (const message of ['ERROR: texture import failed', 'SCRIPT ERROR: missing method',
    'Parse Error: invalid script', 'Error importing: asset', 'Failed to load resource',
    'ERROR: GDExtension dynamic library not found: res://other.gdextension',
    'ERROR: ObjectDB instances leaked']) {
    assert.equal(inspectExportLog(known + '\n' + message).fatal.length, 1);
  }
});

test('wrong platform or extension cannot use the exception', () => {
  for (const altered of [known.replaceAll(path, 'res://other.gdextension'),
    known.replace('macos.arm64', 'ios.arm64'), known.replace('macos.arm64', 'linux.x86_64')]) {
    assert.equal(inspectExportLog(altered).fatal.length, 3);
  }
  assert.equal(inspectExportLog(`ERROR: GDExtension dynamic library not found: '${path}'.`).fatal.length, 1);
});

test('colored diagnostics retain all errors', () => {
  const result = inspectExportLog('\x1b[31m' + known + '\x1b[0m\nERROR: invalid dependency');
  assert.equal(result.fatal.length, 1);
  assert.equal(result.platformDiagnostics.length, 3);
});
