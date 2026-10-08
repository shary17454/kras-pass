import test from 'node:test';
import assert from 'node:assert/strict';
import {requireSimulatorArchitecture} from './check-ios-simulator-arch.mjs';

test('requires actual arm64 for native Apple Silicon simulator builds', () => {
  assert.throws(() => requireSimulatorArchitecture('x86_64\n', 'arm64'), /lacks arm64/);
  assert.equal(requireSimulatorArchitecture('x86_64 arm64\n', 'arm64'), 'arm64');
});

test('explicit legacy x86_64 compilation remains possible', () => {
  assert.equal(requireSimulatorArchitecture('x86_64\n', 'x86_64'), 'x86_64');
  assert.throws(() => requireSimulatorArchitecture('arm64\n', 'x86_64'), /lacks x86_64/);
});

test('rejects missing or unsupported architectures and partial names', () => {
  for (const requested of ['', 'arm', 'arm64e', undefined]) {
    assert.throws(() => requireSimulatorArchitecture('arm64 x86_64', requested), /Unsupported/);
  }
  assert.throws(() => requireSimulatorArchitecture('arm64e', 'arm64'), /lacks arm64/);
});
