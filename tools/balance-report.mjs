import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export function summarizeBalance(entries, { commit, run, gameIds, partial = false }) {
  if (!/^[a-f0-9]{40}$/.test(commit) || !run || !Array.isArray(gameIds) ||
      !gameIds.length || new Set(gameIds).size !== gameIds.length) {
    throw new Error('Invalid expected campaign identity');
  }
  const expected = new Set(gameIds);
  const seen = new Set();
  const reviews = [];
  const characterWins = Object.create(null);
  for (const { source, checkout, report } of entries) {
    const game = report.games?.[0];
    const smoke = report.mutator_smoke?.[0];
    if (source.commit !== commit || checkout.trim() !== commit || String(source.run) !== String(run) ||
        !expected.has(source.game) || seen.has(source.game) || source.mode !== 'natural' ||
        report.sample_mode !== 'natural' || report.games?.length !== 1 || game?.id !== source.game ||
        game.sample_mode !== 'natural' || source.runs !== 24 || game.attempted_runs !== 24 || game.runs !== 24 ||
        source.difficultyRuns !== 12 || game.difficulty_attempted !== 12 || game.difficulty_completed !== 12 ||
        source.smokeRuns !== 2 || report.mutator_smoke?.length !== 1 || smoke?.id !== source.game ||
        smoke.mutated_ok !== true || smoke.chaos_ok !== true || smoke.severity !== 0 ||
        !Array.isArray(smoke.flags) || smoke.flags.length || !Array.isArray(game.flags) ||
        game.flags.some(flag => typeof flag !== 'string' || !flag.length) ||
        ![0, 1].includes(game.severity) || (game.flags.length > 0) !== (game.severity === 1)) {
      throw new Error(`Invalid or incomplete campaign evidence: ${source.game}`);
    }
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
    commit, run: String(run), complete: missing.length === 0,
    gamesCompleted: seen.size, gamesExpected: gameIds.length, matchesCompleted: seen.size * 38,
    missing, reviews, characterWins,
    balanceReviewComplete: false,
    releaseReady: false,
  };
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
    if (!root) throw new Error('Usage: node tools/balance-report.mjs ARTIFACTS COMMIT RUN [--partial]');
    const catalogue = JSON.parse(fs.readFileSync(new URL('../data/minigames.json', import.meta.url), 'utf8'));
    const summary = summarizeBalance(readBalanceEntries(root), {
      commit, run, gameIds: catalogue.games.map(game => game.id), partial: process.argv.includes('--partial'),
    });
    console.log(JSON.stringify(summary, null, 2));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
