import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {labPeerDeadline, labProcessDeadline} from './lab-smoke-budget.js';

test('lab budgets cover authored rounds, bounded finals and every CI peer group', () => {
  assert.equal(labPeerDeadline(false), 240);
  assert.equal(labPeerDeadline(true), 1140);
  assert.equal(labProcessDeadline(false), 300000);
  assert.equal(labProcessDeadline(true), 1200000);
  const catalog = JSON.parse(readFileSync(new URL('../data/minigames.json', import.meta.url), 'utf8'));
  const budget = JSON.parse(readFileSync(new URL('../tests/lab_smoke_budget.json', import.meta.url), 'utf8'));
  assert.equal(catalog.games.find(game => game.id === 'lab_crates').duration, budget.round_seconds);
  const workflow = readFileSync(new URL('../.github/workflows/game-quality.yml', import.meta.url), 'utf8');
  const minutes = Number(/scenario == 'lab_crates' && (\d+)/.exec(workflow)?.[1]);
  assert.ok(Number.isFinite(minutes));
  const allGroups = 3 * labProcessDeadline(false) + 3 * labProcessDeadline(true);
  assert.ok(minutes * 60000 >= allGroups + 600000, 'CI includes random groups, seeded regression and setup');
});
