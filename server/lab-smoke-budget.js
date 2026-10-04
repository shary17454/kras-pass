import {readFileSync} from 'node:fs';

const budget = JSON.parse(readFileSync(new URL('../tests/lab_smoke_budget.json', import.meta.url), 'utf8'));
for (const value of Object.values(budget)) {
  if (!Number.isSafeInteger(value) || value <= 0) throw new Error('Invalid lab smoke budget');
}

export function labPeerDeadline(tournament) {
  const matches = tournament ? budget.tournament_matches + budget.maximum_finals : 1;
  return budget.setup_seconds + matches * budget.rounds_per_match * budget.round_seconds;
}

export function labProcessDeadline(tournament) {
  return (labPeerDeadline(tournament) + budget.node_grace_seconds) * 1000;
}
