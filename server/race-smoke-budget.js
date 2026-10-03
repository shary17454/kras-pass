import {readFileSync} from 'node:fs';

const budget = JSON.parse(readFileSync(new URL('../tests/race_smoke_budget.json', import.meta.url), 'utf8'));
for (const value of Object.values(budget)) {
  if (!Number.isSafeInteger(value) || value <= 0) throw new Error('Invalid race smoke budget');
}

export function kartPeerDeadline(tournament) {
  return budget.setup_seconds + (tournament
    ? budget.tournament_races * budget.race_seconds + budget.maximum_finals * budget.final_seconds
    : budget.ordinary_races * budget.race_seconds);
}

export function kartProcessDeadline(tournament) {
  return (kartPeerDeadline(tournament) + budget.node_grace_seconds) * 1000;
}
