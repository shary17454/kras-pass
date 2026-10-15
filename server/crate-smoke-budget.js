import {readFileSync} from 'node:fs';

const budget = JSON.parse(readFileSync(new URL('../tests/crate_smoke_budget.json', import.meta.url), 'utf8'));
for (const value of Object.values(budget)) {
  if (!Number.isSafeInteger(value) || value <= 0) throw new Error('Invalid crate smoke budget');
}

export function cratePeerDeadline(tournament) {
  const matches = tournament ? budget.tournament_matches + budget.maximum_finals : 1;
  return budget.setup_seconds + matches * budget.rounds_per_match * budget.round_seconds;
}

export function crateProcessDeadline(tournament) {
  return (cratePeerDeadline(tournament) + budget.node_grace_seconds) * 1000;
}
