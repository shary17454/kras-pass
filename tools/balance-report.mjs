import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { balanceSourceFingerprint } from './balance-source.mjs';

const PAIR_POLICY = 'pair_balanced_affine_plane_rotation';
const PAIR_SCHEDULE = { cycle_length: 56, appearances_per_cycle: 28,
  appearances_per_seat_per_cycle: 7, pair_coappearances_per_cycle: 12 };
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
const digestPattern = /^[a-f0-9]{64}$/;
const difficultyRunsFor = runs => Math.max(16, 2 * Math.ceil(runs / 4));
const canonical = value => JSON.stringify(value, (_, item) => item && typeof item === 'object' && !Array.isArray(item)
  ? Object.fromEntries(Object.keys(item).sort().map(key => [key, item[key]])) : item);

// Separate measurement identity: neither tests nor .mjs are covered by the simulation fingerprint.
// Capture at BOTH campaign boundaries, outside the simulator; do not backfill old evidence.
export function captureTestSchedule() {
  const files = ['tests/balance_pair_sim.gd', 'tests/balance_pair_sim.tscn',
    'tests/balance_pair_schedule.gd', 'tools/balance-report.mjs', 'tools/balance-source.mjs'];
  return { entrypoint: 'res://tests/balance_pair_sim.tscn', files: Object.fromEntries(files.map(file => {
    const url = new URL(`../${file}`, import.meta.url);
    if (!fs.lstatSync(url).isFile()) throw new Error('Invalid measurement file');
    return [file, sha256(fs.readFileSync(url))];
  })) };
}

export const balanceReportDigest = report => sha256(canonical(report));

// Opt-in contract: pairBalanced is a separately retained, trusted measurement manifest:
// {commit, run, seedOffset, runs, simulationSource, testSchedule, reports: {GAME: canonicalReportSHA256}}.
// source.testScheduleStart/End must be recorded at execution boundaries. Pin the original
// report before review: this detects edits (including removed warnings), not fabricated runs.
// Keep this manifest independently of mutable artifacts. It is an explicit trust input,
// not a signature, RNG replay, source/asset attestation, or a substitute for human review.
// Use captureTestSchedule() before/after execution and balanceReportDigest(parsedReport)
// when sealing original outputs. Partial manifests may omit games not yet measured.
// The CLI uses --pair-balanced-attestation=FILE and --source-fingerprint=SHA256; the API
// additionally requires gameDefinitions from the pinned catalogue (default arena/duration).
// 56/112 are diagnostic; 224 equalizes difficulty allocation but is NOT acceptance.
export function summarizeBalance(entries, { commit, run, gameIds, characterIds = [], bossGameIds = [], partial = false, requirePaired = false, seedOffset = 0, engineVersion = '4.7.1-stable (official)', sourceFingerprint = null, pairBalanced = null, gameDefinitions = [] }) {
  if (!/^[a-f0-9]{40}$/.test(commit) || !run || !Array.isArray(gameIds) ||
      !gameIds.length || new Set(gameIds).size !== gameIds.length ||
      !Number.isSafeInteger(seedOffset) || seedOffset < 0 || seedOffset > 1000000000 ||
      !Array.isArray(bossGameIds) || new Set(bossGameIds).size !== bossGameIds.length ||
      bossGameIds.some(id => !gameIds.includes(id)) ||
      typeof engineVersion !== 'string' || !engineVersion.trim() ||
      (sourceFingerprint !== null && (typeof sourceFingerprint !== 'string' || !/^[a-f0-9]{64}$/.test(sourceFingerprint)))) {
    throw new Error('Invalid expected campaign identity');
  }
  const balanced = pairBalanced !== null;
  const baselineRuns = balanced ? pairBalanced.runs : 24;
  if (balanced && (!Number.isSafeInteger(baselineRuns) || baselineRuns < 56 || baselineRuns > 10000 || baselineRuns % 56 ||
      characterIds.length !== 8 || new Set(characterIds).size !== 8 ||
      characterIds.some(id => typeof id !== 'string' || !id.trim()) ||
      pairBalanced.commit !== commit || pairBalanced.run !== String(run) || pairBalanced.seedOffset !== seedOffset ||
      sourceFingerprint === null || pairBalanced.simulationSource !== sourceFingerprint ||
      canonical(pairBalanced.testSchedule) !== canonical(captureTestSchedule()) ||
      !pairBalanced.reports || Array.isArray(pairBalanced.reports) ||
      (!partial && Object.keys(pairBalanced.reports).length !== gameIds.length) ||
      Object.entries(pairBalanced.reports).some(([id, digest]) => !gameIds.includes(id) || typeof digest !== 'string' || !digestPattern.test(digest)) ||
      !Array.isArray(gameDefinitions) || gameDefinitions.length !== gameIds.length ||
      new Set(gameDefinitions.map(game => game.id)).size !== gameIds.length ||
      gameIds.some(id => !gameDefinitions.some(game => game.id === id && Array.isArray(game.arenas) &&
        typeof game.arenas[0] === 'string' && game.arenas[0].length > 0 &&
        ['lives', 'points', 'race_time', 'survival'].includes(game.scoring) &&
        Number.isFinite(game.duration) && game.duration > 0)))) {
    throw new Error('Invalid pair-balanced campaign attestation');
  }
  const expected = new Set(gameIds);
  const seen = new Set();
  const reviews = [];
  const characterWins = Object.create(null);
  const bossBaseline = [];
  const bossComparisons = [];
  let pairingVerified = entries.length > 0;
  let observedFingerprint = null;
  for (const { source, checkout, report } of entries) {
    const fingerprint = report.simulation_source_start;
    if (typeof fingerprint !== 'string' || !/^[a-f0-9]{64}$/.test(fingerprint) ||
        report.simulation_source_end !== fingerprint || report.engine_version !== engineVersion ||
        (sourceFingerprint !== null && fingerprint !== sourceFingerprint) ||
        (observedFingerprint !== null && fingerprint !== observedFingerprint)) {
      throw new Error('Mismatched simulation source fingerprint or engine');
    }
    observedFingerprint = fingerprint;
    if (report.arena_override !== undefined && report.arena_override !== '') {
      throw new Error('Targeted arena evidence cannot replace the default-arena campaign');
    }
    const game = report.games?.[0];
    const smoke = report.mutator_smoke?.[0];
    const paired = source.difficultyPolicy === 'matched_seed_character';
    const difficultyRuns = balanced ? difficultyRunsFor(baselineRuns) : paired ? 16 : 12;
    if ((source.difficultyPolicy !== undefined && !paired) || ((requirePaired || balanced) && !paired)) {
      throw new Error('Unqualified difficulty pairing policy');
    }
    if (source.commit !== commit || checkout.trim() !== commit || String(source.run) !== String(run) ||
        !expected.has(source.game) || seen.has(source.game) || source.mode !== 'natural' ||
        report.sample_mode !== 'natural' || report.games?.length !== 1 || game?.id !== source.game ||
        game.sample_mode !== 'natural' || source.runs !== baselineRuns || game.attempted_runs !== baselineRuns || game.runs !== baselineRuns ||
        source.difficultyRuns !== difficultyRuns || game.difficulty_attempted !== difficultyRuns || game.difficulty_completed !== difficultyRuns ||
        source.smokeRuns !== 2 || report.mutator_smoke?.length !== 1 || smoke?.id !== source.game ||
        smoke.mutated_ok !== true || smoke.chaos_ok !== true || smoke.severity !== 0 ||
        !Array.isArray(smoke.flags) || smoke.flags.length || !Array.isArray(game.flags) ||
        game.flags.some(flag => typeof flag !== 'string' || !flag.length) ||
        ![0, 1].includes(game.severity) || (game.flags.length > 0) !== (game.severity === 1)) {
      throw new Error(`Invalid or incomplete campaign evidence: ${source.game}`);
    }
    // Experimental compositions are not interchangeable with the existing campaign.
    const rosterPolicy = balanced ? PAIR_POLICY : 'adjacent_rotation';
    if ((source.rosterPolicy !== undefined && source.rosterPolicy !== rosterPolicy) ||
        (balanced ? game.roster_policy !== rosterPolicy :
          (game.roster_policy !== undefined && game.roster_policy !== rosterPolicy) ||
          source.testScheduleStart !== undefined || source.testScheduleEnd !== undefined || game.pair_schedule !== undefined)) {
      throw new Error(`Unqualified roster policy: ${source.game}`);
    }
    if (balanced) {
      // This is a single, default-campaign measurement format, not an adapter for
      // custom scene/asset/preset provenance. Unknown source metadata fails closed.
      const sourceKeys = new Set(['commit', 'run', 'game', 'mode', 'runs', 'difficultyRuns',
        'difficultyPolicy', 'smokeRuns', 'seedOffset', 'rosterPolicy', 'testScheduleStart', 'testScheduleEnd']);
      if (report.runs_per_game !== baselineRuns || report.arena_override !== '' ||
          Object.keys(source).some(key => !sourceKeys.has(key)) ||
          source.seedOffset !== seedOffset || report.seed_offset !== seedOffset || game.seed_offset !== seedOffset ||
          canonical(source.testScheduleStart) !== canonical(pairBalanced.testSchedule) ||
          canonical(source.testScheduleEnd) !== canonical(pairBalanced.testSchedule) ||
          balanceReportDigest(report) !== pairBalanced.reports[game.id]) {
        throw new Error('Changed or missing pair-balanced measurement attestation');
      }
      const definition = gameDefinitions.find(def => def.id === game.id);
      if (game.arena_id !== definition.arenas[0] || game.round_window !== definition.duration ||
          Boolean(definition.boss) !== bossGameIds.includes(game.id)) {
        throw new Error('Pair-balanced evidence must use the default catalogue arena/window');
      }
      verifyBalancedSchedule(game, characterIds, baselineRuns);
      if (definition.scoring === 'points' && game.zero_score_runs > 0 &&
          !game.flags.some(flag => /^\d+ run\(s\) scored nothing$/.test(flag))) {
        throw new Error('Missing balanced zero-score warning');
      }
    }
    for (const value of [source.seedOffset, report.seed_offset, game.seed_offset]) {
      if ((value ?? 0) !== seedOffset || (seedOffset !== 0 && value === undefined)) {
        throw new Error('Mismatched campaign seed offset');
      }
    }
    if (balanced || seedOffset !== 0 || game.baseline_seeds !== undefined) {
      if (!Array.isArray(game.baseline_seeds) || game.baseline_seeds.length !== baselineRuns ||
          game.baseline_seeds.some((seed, i) => seed !== seedOffset + 9001 + i * 613)) {
        throw new Error('Mismatched baseline seed evidence');
      }
    }
    if (balanced || seedOffset !== 0 || smoke.mutated_seed !== undefined || smoke.chaos_seed !== undefined) {
      if (smoke.mutated_seed !== seedOffset + 5501 || smoke.chaos_seed !== seedOffset + 5502) {
        throw new Error('Mismatched mutator seed evidence');
      }
    }
    if (paired) verifyPairs(game, characterIds, seedOffset, balanced ? difficultyRuns : 16, balanced);
    if (bossGameIds.includes(game.id) || game.boss_outcomes !== undefined) {
      bossBaseline.push({ game: game.id, ...verifyBossOutcomeEvidence(game, seedOffset) });
      bossComparisons.push({ game: game.id, ...verifyBossComparisonEvidence(game, smoke, seedOffset) });
    }
    pairingVerified &&= paired;
    seen.add(source.game);
    if (game.flags.length) reviews.push({ game: game.id, flags: game.flags });
    for (const [character, wins] of Object.entries(game.wins_by_character ?? {})) {
      if (!Number.isSafeInteger(wins) || wins < 0) throw new Error('Invalid character win count');
      characterWins[character] = (characterWins[character] ?? 0) + wins;
    }
  }
  const missing = gameIds.filter(id => !seen.has(id));
  if (missing.length && !partial) throw new Error(`Missing campaign games: ${missing.join(', ')}`);
  return {
    commit, run: String(run), seedOffset, complete: missing.length === 0,
    sourceFingerprint: observedFingerprint,
    engineVersion: entries.length > 0 ? engineVersion : null,
    sourceConsistencyVerified: entries.length > 0 && missing.length === 0,
    gamesCompleted: seen.size, gamesExpected: gameIds.length,
    matchesCompleted: entries.reduce((total, entry) => total + baselineRuns + 2 + entry.source.difficultyRuns, 0),
    ...(balanced ? { rosterPolicy: PAIR_POLICY, baselineRuns,
      testSchedule: pairBalanced.testSchedule, reportDigests: pairBalanced.reports,
      difficultyAllocationEqual: pairingVerified && missing.length === 0 && (difficultyRunsFor(baselineRuns) / 2) % 8 === 0,
      measurementOnly: true } : {}),
    difficultyPairingVerified: pairingVerified && missing.length === 0,
    missing, reviews, characterWins, bossBaseline, bossComparisons,
    balanceReviewComplete: false,
    releaseReady: false,
  };
}

export function verifyBossOutcomeEvidence(game, seedOffset = 0) {
  const samples = game.boss_outcomes;
  const counts = { defeated: 0, survived: 0, unknown: 0 };
  if (!Number.isSafeInteger(seedOffset) || seedOffset < 0 || seedOffset > 1000000000 ||
      !Number.isSafeInteger(game.runs) || game.runs < 1 ||
      !Array.isArray(samples) || samples.length !== game.runs) {
    throw new Error('Missing boss objective evidence');
  }
  for (const [i, sample] of samples.entries()) {
    if (!sample || sample.seed !== seedOffset + 9001 + i * 613 ||
        !['defeated', 'survived'].includes(sample.outcome)) {
      throw new Error('Invalid seeded boss objective evidence');
    }
    counts[sample.outcome]++;
  }
  for (const [outcome, count] of Object.entries(counts)) {
    const recorded = game[`boss_${outcome}_runs`];
    if (!Number.isSafeInteger(recorded) || recorded !== count) {
      throw new Error('Mismatched boss objective counters');
    }
  }
  const noDefeat = 'boss never defeated in baseline sample';
  if (!Array.isArray(game.flags) || game.flags.includes(noDefeat) !== (counts.defeated === 0) ||
      (counts.defeated === 0 && game.severity !== 1)) {
    throw new Error('Missing or contradictory boss objective warning');
  }
  return counts;
}

export function verifyBossComparisonEvidence(game, smoke, seedOffset = 0) {
  const samples = game.difficulty_samples;
  const difficulty = { defeated: 0, survived: 0 };
  if (!Number.isSafeInteger(seedOffset) || seedOffset < 0 || seedOffset > 1000000000 ||
      !Number.isSafeInteger(game.difficulty_attempted) || game.difficulty_attempted < 1 ||
      !Array.isArray(samples) || samples.length !== game.difficulty_attempted) {
    throw new Error('Missing boss difficulty objective evidence');
  }
  for (const [i, sample] of samples.entries()) {
    if (!sample || sample.seed !== seedOffset + 4242 + Math.floor(i / 2) * 97 ||
        sample.completed !== true || !['defeated', 'survived'].includes(sample.boss_outcome)) {
      throw new Error('Invalid boss difficulty objective evidence');
    }
    difficulty[sample.boss_outcome]++;
  }
  const stress = {};
  for (const [mode, delta] of [['mutated', 5501], ['chaos', 5502]]) {
    if (smoke?.id !== game.id || smoke[`${mode}_seed`] !== seedOffset + delta ||
        smoke[`${mode}_ok`] !== true || !['defeated', 'survived'].includes(smoke[`${mode}_boss_outcome`])) {
      throw new Error('Invalid boss stress objective evidence');
    }
    stress[mode] = smoke[`${mode}_boss_outcome`];
  }
  return { difficulty, stress };
}

function verifyBalancedSchedule(game, characterIds, runs) {
  if (canonical(game.pair_schedule) !== canonical(PAIR_SCHEDULE) ||
      !Array.isArray(game.baseline_rosters) || game.baseline_rosters.length !== runs) {
    throw new Error('Missing pair-balanced schedule rows');
  }
  for (let start = 0; start < runs; start += 56) {
    const seats = new Map(characterIds.map(id => [id, [0, 0, 0, 0]]));
    const pairs = new Map();
    for (let index = start; index < start + 56; index++) {
      const roster = game.baseline_rosters[index];
      if (!Array.isArray(roster) || roster.length !== 4 || new Set(roster).size !== 4 ||
          roster.some(id => !seats.has(id))) throw new Error('Invalid pair-balanced roster');
      // Each quartet is seated four times in order, not just equal campaign totals.
      const first = game.baseline_rosters[index - index % 4];
      if (roster.some((id, slot) => id !== first[(slot + index % 4) % 4])) {
        throw new Error('Invalid pair-balanced seat rotation');
      }
      roster.forEach((id, slot) => seats.get(id)[slot]++);
      for (let i = 0; i < 4; i++) for (let j = i + 1; j < 4; j++) {
        const key = JSON.stringify([roster[i], roster[j]].sort());
        pairs.set(key, (pairs.get(key) ?? 0) + 1);
      }
    }
    if ([...seats.values()].some(counts => counts.some(count => count !== 7)) ||
        pairs.size !== 28 || [...pairs.values()].some(count => count !== 12)) {
      throw new Error('Unbalanced character/seat/pair distribution within a 56-match cycle');
    }
  }
  const wins = game.wins_by_character;
  const slotWins = game.wins_by_slot;
  if (!wins || Array.isArray(wins) || Object.keys(wins).some(id => !characterIds.includes(id)) ||
      !Array.isArray(slotWins) || slotWins.length !== 4 || game.character_buckets !== 8 ||
      [...Object.values(wins), ...slotWins].some(value => !Number.isSafeInteger(value) || value < 0) ||
      characterIds.some(id => (wins[id] ?? 0) > runs / 2) || slotWins.some(value => value > runs)) {
    throw new Error('Invalid balanced win buckets');
  }
  const counts = characterIds.map(id => wins[id] ?? 0);
  const total = counts.reduce((sum, value) => sum + value, 0);
  const bias = values => Math.max(...values) / total - 1 / values.length;
  const tieCount = game.tie_rate * runs;
  const ties = Math.round(tieCount);
  // is_draw() means 2..4 first-place slots; winners() credits every one.
  // Allow only JSON rounding of the integer count (15 digits, runs <= 10000).
  if (total < runs || total > runs * 4 || total !== slotWins.reduce((sum, value) => sum + value, 0) ||
      !Number.isFinite(game.character_bias) || Math.abs(game.character_bias - bias(counts)) > 1e-12 ||
      !Number.isFinite(game.slot_bias) || Math.abs(game.slot_bias - bias(slotWins)) > 1e-12 ||
      !Number.isFinite(game.tie_rate) || game.tie_rate < 0 || game.tie_rate > 1 ||
      Math.abs(tieCount - ties) > 1e-10 || total < runs + ties || total > runs + 3 * ties ||
      !Number.isFinite(game.avg_duration) || game.avg_duration < 0 ||
      !Number.isSafeInteger(game.zero_score_runs) || game.zero_score_runs < 0 || game.zero_score_runs > runs) {
    throw new Error('Inconsistent balanced metrics');
  }
  // The Godot p95 is NOT recomputed with a different RNG here. Preserve it via the
  // trusted original-report digest, along with all other original warnings.
  if ((game.tie_rate > 0.4 && !game.flags.some(flag => /^ties .*% of the time$/.test(flag))) ||
      (game.avg_duration < 3 && !game.flags.includes('ends almost immediately')) ||
      (game.expert_edge < 0.52 && !game.flags.includes('expert bots no better than easy'))) {
    throw new Error('Missing balanced metric warning');
  }
}

function verifyPairs(game, characterIds, seedOffset, count = 16, balanced = false) {
  const samples = game.difficulty_samples;
  if (game.difficulty_pairing !== 'matched_seed_character' || !Array.isArray(samples) || samples.length !== count ||
      characterIds.length !== 8 || new Set(characterIds).size !== 8) throw new Error('Missing paired difficulty evidence');
  const seen = new Set();
  let expertPoints = 0; let totalPoints = 0;
  const outcomes = { samples: count, expert_wins: 0, easy_wins: 0, shared_first: 0,
    incomplete: 0, invalid: 0, expert_outright_win_share: null };
  for (let i = 0; i < count; i += 2) {
    const first = samples[i]; const second = samples[i + 1];
    if (!first || !second || first.seed !== seedOffset + 4242 + (i / 2) * 97 || first.seed !== second.seed || first.character !== second.character ||
        !characterIds.includes(first.character) || (balanced ? first.character !== characterIds[(i / 2) % 8] : seen.has(first.character)) ||
        JSON.stringify(first.expert_slots) !== '[0,1]' || JSON.stringify(second.expert_slots) !== '[2,3]' ||
        first.completed !== true || second.completed !== true) throw new Error('Mismatched difficulty pair');
    seen.add(first.character);
    if (balanced) for (const sample of [first, second]) {
      if (!Array.isArray(sample.places) || sample.places.length !== 4 ||
          sample.places.some(place => !Number.isInteger(place) || place < 1 || place > 4) || !sample.places.includes(1) ||
          !Array.isArray(sample.scores) || sample.scores.length !== 4 || sample.scores.some(score => !Number.isSafeInteger(score))) {
        throw new Error('Invalid balanced difficulty result');
      }
      sample.places.forEach((place, slot) => {
        const points = 5 - place;
        totalPoints += points;
        if (sample.expert_slots.includes(slot)) expertPoints += points;
      });
      const winners = sample.places.map((place, slot) => place === 1 ? slot : -1).filter(slot => slot >= 0);
      if (winners.length > 1) outcomes.shared_first++;
      else if (sample.expert_slots.includes(winners[0])) outcomes.expert_wins++;
      else outcomes.easy_wins++;
    }
  }
  if (balanced && (!Number.isFinite(game.expert_edge) || Math.abs(game.expert_edge - expertPoints / totalPoints) > 1e-12)) {
    throw new Error('Inconsistent balanced difficulty placement share');
  }
  if (balanced) {
    const outright = outcomes.expert_wins + outcomes.easy_wins;
    if (outright > 0) outcomes.expert_outright_win_share = outcomes.expert_wins / outright;
    const recorded = game.difficulty_outcomes;
    const shareKey = 'expert_outright_win_share';
    const share = recorded?.[shareKey];
    const expectedShare = outcomes[shareKey];
    // Godot serializes floats to 15 digits; counters and nullness remain exact.
    if (!recorded || Array.isArray(recorded) || Object.keys(recorded).length !== Object.keys(outcomes).length ||
        Object.keys(outcomes).some(key => !Object.hasOwn(recorded, key) || (key !== shareKey && recorded[key] !== outcomes[key])) ||
        (expectedShare === null ? share !== null :
          !Number.isFinite(share) || share < 0 || share > 1 || Math.abs(share - expectedShare) > 1e-12)) {
      throw new Error('Inconsistent balanced difficulty outcomes');
    }
  }
}

export function readBalanceEntries(root) {
  const entries = [];
  function visit(dir) {
    const children = fs.readdirSync(dir, { withFileTypes: true });
    if (children.some(child => child.isFile() && child.name === 'balance-source.json')) {
      entries.push({
        source: JSON.parse(fs.readFileSync(path.join(dir, 'balance-source.json'), 'utf8')),
        checkout: fs.readFileSync(path.join(dir, 'balance-checkout.txt'), 'utf8'),
        report: JSON.parse(fs.readFileSync(path.join(dir, 'balance-report/report.json'), 'utf8')),
      });
      return;
    }
    for (const child of children) if (child.isDirectory()) visit(path.join(dir, child.name));
  }
  visit(root);
  return entries;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const [root, commit, run] = process.argv.slice(2);
    if (!root) throw new Error('Usage: node tools/balance-report.mjs ARTIFACTS COMMIT RUN [--partial] [--paired] [--seed-offset=N] [--source-fingerprint=SHA256] [--pair-balanced-attestation=FILE]');
    const catalogue = JSON.parse(fs.readFileSync(new URL('../data/minigames.json', import.meta.url), 'utf8'));
    const characters = JSON.parse(fs.readFileSync(new URL('../data/characters.json', import.meta.url), 'utf8'));
    const offsetArgument = process.argv.find(value => value.startsWith('--seed-offset='));
    const fingerprintArgument = process.argv.find(value => value.startsWith('--source-fingerprint='));
    const attestationArgument = process.argv.find(value => value.startsWith('--pair-balanced-attestation='));
    if (attestationArgument) {
      const flags = process.argv.slice(5);
      const keys = flags.map(flag => flag.split('=')[0]);
      if (new Set(keys).size !== keys.length || flags.some(flag =>
        !['--partial', '--paired'].includes(flag) &&
        !/^--(seed-offset|source-fingerprint|pair-balanced-attestation)=.+$/.test(flag))) {
        throw new Error('Unknown or duplicate pair-balanced campaign option');
      }
    }
    const pairBalanced = attestationArgument ? JSON.parse(fs.readFileSync(attestationArgument.slice('--pair-balanced-attestation='.length), 'utf8')) : null;
    if (attestationArgument && (!pairBalanced || typeof pairBalanced !== 'object' ||
        fingerprintArgument?.slice('--source-fingerprint='.length) !== balanceSourceFingerprint(fileURLToPath(new URL('..', import.meta.url))))) {
      throw new Error('Pair-balanced CLI requires an explicit current simulation source pin');
    }
    const offsetText = offsetArgument?.slice('--seed-offset='.length) ?? '0';
    if (!/^\d+$/.test(offsetText)) throw new Error('Invalid campaign seed offset');
    const summary = summarizeBalance(readBalanceEntries(root), {
      commit, run, gameIds: catalogue.games.map(game => game.id), partial: process.argv.includes('--partial'),
      characterIds: characters.characters.map(character => character.id), requirePaired: process.argv.includes('--paired'),
      bossGameIds: catalogue.games.filter(game => game.boss === true).map(game => game.id),
      seedOffset: Number(offsetText),
      sourceFingerprint: fingerprintArgument?.slice('--source-fingerprint='.length) ?? null,
      pairBalanced, gameDefinitions: catalogue.games,
    });
    console.log(JSON.stringify(summary, null, 2));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
