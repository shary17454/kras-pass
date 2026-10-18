import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export function summarizeBalance(entries, { commit, run, gameIds, characterIds = [], bossGameIds = [], partial = false, requirePaired = false, seedOffset = 0, engineVersion = '4.7.1-stable (official)', sourceFingerprint = null }) {
  if (!/^[a-f0-9]{40}$/.test(commit) || !run || !Array.isArray(gameIds) ||
      !gameIds.length || new Set(gameIds).size !== gameIds.length ||
      !Number.isSafeInteger(seedOffset) || seedOffset < 0 || seedOffset > 1000000000 ||
      !Array.isArray(bossGameIds) || new Set(bossGameIds).size !== bossGameIds.length ||
      bossGameIds.some(id => !gameIds.includes(id)) ||
      typeof engineVersion !== 'string' || !engineVersion.trim() ||
      (sourceFingerprint !== null && (typeof sourceFingerprint !== 'string' || !/^[a-f0-9]{64}$/.test(sourceFingerprint)))) {
    throw new Error('Invalid expected campaign identity');
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
    const difficultyRuns = paired ? 16 : 12;
    if ((source.difficultyPolicy !== undefined && !paired) || (requirePaired && !paired)) {
      throw new Error('Unqualified difficulty pairing policy');
    }
    if (source.commit !== commit || checkout.trim() !== commit || String(source.run) !== String(run) ||
        !expected.has(source.game) || seen.has(source.game) || source.mode !== 'natural' ||
        report.sample_mode !== 'natural' || report.games?.length !== 1 || game?.id !== source.game ||
        game.sample_mode !== 'natural' || source.runs !== 24 || game.attempted_runs !== 24 || game.runs !== 24 ||
        source.difficultyRuns !== difficultyRuns || game.difficulty_attempted !== difficultyRuns || game.difficulty_completed !== difficultyRuns ||
        source.smokeRuns !== 2 || report.mutator_smoke?.length !== 1 || smoke?.id !== source.game ||
        smoke.mutated_ok !== true || smoke.chaos_ok !== true || smoke.severity !== 0 ||
        !Array.isArray(smoke.flags) || smoke.flags.length || !Array.isArray(game.flags) ||
        game.flags.some(flag => typeof flag !== 'string' || !flag.length) ||
        ![0, 1].includes(game.severity) || (game.flags.length > 0) !== (game.severity === 1)) {
      throw new Error(`Invalid or incomplete campaign evidence: ${source.game}`);
    }
    // Experimental compositions are not interchangeable with the existing campaign.
    if (game.roster_policy !== undefined && game.roster_policy !== 'adjacent_rotation') {
      throw new Error(`Unqualified roster policy: ${source.game}`);
    }
    for (const value of [source.seedOffset, report.seed_offset, game.seed_offset]) {
      if ((value ?? 0) !== seedOffset || (seedOffset !== 0 && value === undefined)) {
        throw new Error('Mismatched campaign seed offset');
      }
    }
    if (seedOffset !== 0 || game.baseline_seeds !== undefined) {
      if (!Array.isArray(game.baseline_seeds) || game.baseline_seeds.length !== 24 ||
          game.baseline_seeds.some((seed, i) => seed !== seedOffset + 9001 + i * 613)) {
        throw new Error('Mismatched baseline seed evidence');
      }
    }
    if (seedOffset !== 0 || smoke.mutated_seed !== undefined || smoke.chaos_seed !== undefined) {
      if (smoke.mutated_seed !== seedOffset + 5501 || smoke.chaos_seed !== seedOffset + 5502) {
        throw new Error('Mismatched mutator seed evidence');
      }
    }
    if (paired) verifyPairs(game, characterIds, seedOffset);
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
    matchesCompleted: entries.reduce((total, entry) => total + 26 + entry.source.difficultyRuns, 0),
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

function verifyPairs(game, characterIds, seedOffset) {
  const samples = game.difficulty_samples;
  if (game.difficulty_pairing !== 'matched_seed_character' || !Array.isArray(samples) || samples.length !== 16 ||
      characterIds.length !== 8 || new Set(characterIds).size !== 8) throw new Error('Missing paired difficulty evidence');
  const seen = new Set();
  for (let i = 0; i < 16; i += 2) {
    const first = samples[i]; const second = samples[i + 1];
    if (first.seed !== seedOffset + 4242 + (i / 2) * 97 || first.seed !== second.seed || first.character !== second.character ||
        !characterIds.includes(first.character) || seen.has(first.character) ||
        JSON.stringify(first.expert_slots) !== '[0,1]' || JSON.stringify(second.expert_slots) !== '[2,3]' ||
        first.completed !== true || second.completed !== true) throw new Error('Mismatched difficulty pair');
    seen.add(first.character);
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
    if (!root) throw new Error('Usage: node tools/balance-report.mjs ARTIFACTS COMMIT RUN [--partial] [--paired] [--seed-offset=N] [--source-fingerprint=SHA256]');
    const catalogue = JSON.parse(fs.readFileSync(new URL('../data/minigames.json', import.meta.url), 'utf8'));
    const characters = JSON.parse(fs.readFileSync(new URL('../data/characters.json', import.meta.url), 'utf8'));
    const offsetArgument = process.argv.find(value => value.startsWith('--seed-offset='));
    const fingerprintArgument = process.argv.find(value => value.startsWith('--source-fingerprint='));
    const offsetText = offsetArgument?.slice('--seed-offset='.length) ?? '0';
    if (!/^\d+$/.test(offsetText)) throw new Error('Invalid campaign seed offset');
    const summary = summarizeBalance(readBalanceEntries(root), {
      commit, run, gameIds: catalogue.games.map(game => game.id), partial: process.argv.includes('--partial'),
      characterIds: characters.characters.map(character => character.id), requirePaired: process.argv.includes('--paired'),
      bossGameIds: catalogue.games.filter(game => game.boss === true).map(game => game.id),
      seedOffset: Number(offsetText),
      sourceFingerprint: fingerprintArgument?.slice('--source-fingerprint='.length) ?? null,
    });
    console.log(JSON.stringify(summary, null, 2));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
