import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {kartPeerDeadline, kartProcessDeadline} from './race-smoke-budget.js';

test('kart fixture budgets all ordinary races and bounded contender finals', () => {
  assert.equal(kartPeerDeadline(false), 900);
  assert.equal(kartPeerDeadline(true), 1680);
  assert.equal(kartProcessDeadline(false), 960000);
  assert.equal(kartProcessDeadline(true), 1740000);
  const workflow = readFileSync(new URL('../.github/workflows/game-quality.yml', import.meta.url), 'utf8');
  const minutes = Number(/scenario == 'kart_sprint' && (\d+)/.exec(workflow)?.[1]);
  assert.ok(Number.isFinite(minutes));
  const allGroups = 2 * kartProcessDeadline(false) + 3 * kartProcessDeadline(true);
  assert.ok(minutes * 60000 >= allGroups + 600000, 'CI includes every peer group and setup');
});
