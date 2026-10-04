import test from 'node:test';
import assert from 'node:assert/strict';
import {restoreFawdaFinal, assertFawdaNetworkEvidence, FAWDA_FINAL_SEED} from './fawda-final-checkpoint.js';

test('recorded fawda standings restore the actual two-contender final', () => {
  const room = {roster: [0, 1, 2, 3], epoch: 0, config: {game: 'fawda'}};
  const restored = restoreFawdaFinal(room);
  assert.equal(FAWDA_FINAL_SEED, 1993721724);
  assert.equal(room.epoch, 3);
  assert.deepEqual(restored.contenders, [0, 2]);
  assert.deepEqual(restored.points, [11, 5, 11, 8]);
  assert.equal(restored.round, 3);
  assert.deepEqual(room.tournament.next(), {game: 'fawda', arena: 'storm_ring'});
  assert.throws(() => room.tournament.record(3, [6, 2, 8, 4]), /invalid_tournament_result/);
  room.tournament.record(4, [6, 2, 8, 4]);
  assert.deepEqual(room.tournament.champions, [2]);
  assert.equal(room.tournament.complete, true);
  assert.deepEqual(room.tournament.points, restored.points);
});

test('checkpoint cannot silently replace an unrelated or started match', () => {
  const room = {roster: [0, 1, 2, 3], epoch: 0, config: {game: 'fawda'}};
  assert.throws(() => restoreFawdaFinal({...room, epoch: 1}));
  assert.throws(() => restoreFawdaFinal({...room, roster: [0, 1]}));
  assert.throws(() => restoreFawdaFinal({...room, config: {game: 'ring_rumble'}}));
});

function peers() {
  const host = {matches: 1, fawda_event_coverage: {drop: true, pickup: true, throw: true, explode: true},
    fawda_worlds: [{arena: 'storm_ring', seed: FAWDA_FINAL_SEED, world: {
      bombs: [{fuse: 3.2166667, held: -1}], carrying: [0, 0, 0, 0], events: {explode: {sequence: 0}},
    }}], tournament: {champions: [2], points: [11, 5, 11, 8]}};
  return [host, structuredClone(host)];
}

test('early final does not invent an explosion, but world agreement is mandatory', () => {
  const results = peers();
  results.forEach(result => { result.fawda_event_coverage = {drop: true}; });
  assert.doesNotThrow(() => assertFawdaNetworkEvidence(results, true));
  assert.throws(() => assertFawdaNetworkEvidence(results), /pickup/);
});

test('ordinary campaigns still require each real ordnance event', () => {
  for (const kind of ['drop', 'pickup', 'throw', 'explode']) {
    const results = peers();
    delete results[1].fawda_event_coverage[kind];
    assert.throws(() => assertFawdaNetworkEvidence(results), /coverage is required/);
  }
});

test('agreement checks reject lost events, altered fuses, carriers and bombs', () => {
  for (const change of [
    world => { world.events.explode.sequence = 1; },
    world => { world.bombs[0].fuse = 0; },
    world => { world.bombs[0].held = 2; },
    world => { world.carrying[2] = 1; },
    world => { world.bombs = []; },
  ]) {
    const results = peers();
    change(results[1].fawda_worlds[0].world);
    assert.throws(() => assertFawdaNetworkEvidence(results, true), /agree with the host/);
  }
});

test('missing match history and a noncontender champion cannot pass', () => {
  let results = peers();
  results[1].fawda_worlds = [];
  assert.throws(() => assertFawdaNetworkEvidence(results, true));
  results = peers();
  results[0].tournament.champions = [1];
  assert.throws(() => assertFawdaNetworkEvidence(results, true));
});

test('decimal JSON round-trip noise is not a changed physical position', () => {
  const results = peers();
  results[0].fawda_worlds[0].world.bombs[0].position = [0, 0.000840793538372964, 0];
  results[1].fawda_worlds[0].world.bombs[0].position = [0, 0.00084079353837296, 0];
  assert.doesNotThrow(() => assertFawdaNetworkEvidence(results, true));
  results[1].fawda_worlds[0].world.bombs[0].position[1] += 1e-8;
  assert.throws(() => assertFawdaNetworkEvidence(results, true), /agree with the host/);
});
