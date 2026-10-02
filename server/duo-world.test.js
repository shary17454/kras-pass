import test from 'node:test';
import assert from 'node:assert/strict';
import {validDuoWorld} from './world-snapshots.js';

test('duo world binds team points, lives and hazards to the selected arena', () => {
  for (const arena of ['sweeper_ring', 'bumper_bowl']) {
    const hazards = arena === 'sweeper_ring' ? {angles: [0, 1, -1]}
      : {hits: [0, 1, 2, 3, 4], scales: Array.from({length: 5}, () => [1, 1, 1])};
    const world = {lives: [2, 1, 0, 2], damage: [0, 10, 20, 0], team_scores: [2, 4], arena, hazards};
    assert.equal(validDuoWorld(world, 4, arena), true);
    assert.equal(validDuoWorld(world, 4, arena === 'sweeper_ring' ? 'bumper_bowl' : 'sweeper_ring'), false);
    for (const field of Object.keys(world)) {
      const bad = {...world}; delete bad[field];
      assert.equal(validDuoWorld(bad, 4, arena), false);
    }
    for (const bad of [null, [], {...world, extra: 1}, {...world, arena: 'duel_pit'}, {...world, hazards: {}},
      {...world, lives: [3, 1, 0, 2]}, {...world, damage: [0, 0]}, {...world, team_scores: [1, 2, 3]}]) {
      assert.equal(validDuoWorld(bad, 4, arena), false);
    }
    for (const score of [-1, .5, 100001, Infinity, NaN, '2', true]) {
      assert.equal(validDuoWorld({...world, team_scores: [score, 4]}, 4, arena), false);
    }
  }
});
