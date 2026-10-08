import assert from 'node:assert/strict';
import {Tournament} from './tournament.js';

// Run 37834212081, job 113507017038: retain the recorded preceding results.
// The final itself still runs through real Godot inputs and projectiles.
export const TANK_FINAL_SEED = 15775892;
export function restoreTankFinal(room) {
  assert.equal(room.roster.length, 4);
  assert.equal(room.epoch, 0);
  assert.equal(room.config.game, 'tank_arena');
  const settings = {mode: 'points', target: 3, rotation: 'manual', points: [5, 3, 2, 1],
    entries: ['tank_oasis', 'tank_foundry', 'tank_frost', 'tank_oasis']
      .map(arena => ({game: 'tank_arena', arena}))};
  const tournament = new Tournament(4, settings, TANK_FINAL_SEED);
  const scores = [[475, 475, 500, 472], [500, 485, 500, 440], [475, 450, 435, 500]];
  scores.forEach((result, index) => {
    tournament.next();
    tournament.record(index + 1, result);
  });
  assert.deepEqual(tournament.contenders, [0, 2]);
  assert.deepEqual(tournament.points, [10, 7, 10, 7]);
  assert.equal(tournament.complete, false);
  room.tournament = tournament;
  room.epoch = 3;
  return tournament.view();
}
