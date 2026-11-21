import test from 'node:test';
import assert from 'node:assert/strict';
import {startSchedulingProbe} from './scheduling-probe.js';

test('independent scheduling probe starts, reports and exits without room payloads', async () => {
  const probe = await startSchedulingProbe();
  const report = await probe.stop();
  assert.deepEqual(report.operations, {});
  assert.ok(Array.isArray(report.stalls));
  assert.ok(report.stalls.length <= 50);
  for (const row of report.stalls) {
    assert.deepEqual(row.rooms, []);
    assert.ok(row.endEpochMs >= row.startEpochMs);
  }
});
