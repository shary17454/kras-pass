import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {cratePeerDeadline, crateProcessDeadline} from './crate-smoke-budget.js';

test('crate qualification covers authored rounds, bounded finals and both CI peer groups', () => {
  assert.equal(cratePeerDeadline(false), 210);
  assert.equal(cratePeerDeadline(true), 960);
  assert.equal(crateProcessDeadline(false), 270000);
  assert.equal(crateProcessDeadline(true), 1020000);
  const catalog = JSON.parse(readFileSync(new URL('../data/minigames.json', import.meta.url), 'utf8'));
  const budget = JSON.parse(readFileSync(new URL('../tests/crate_smoke_budget.json', import.meta.url), 'utf8'));
  assert.equal(catalog.games.find(game => game.id === 'crate_smash').duration, budget.round_seconds);
  const workflow = readFileSync(new URL('../.github/workflows/game-quality.yml', import.meta.url), 'utf8');
  const minutes = Number(/scenario == 'crate_smash' && (\d+)/.exec(workflow)?.[1]);
  assert.ok(Number.isFinite(minutes));
  assert.ok(minutes * 60000 >= 2 * (crateProcessDeadline(false) + crateProcessDeadline(true)) + 600000);
});
