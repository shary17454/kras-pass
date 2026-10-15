import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { balanceSourceFingerprint } from './balance-source.mjs';

const count = (value, minimum) => Number.isSafeInteger(value) && value >= minimum;

// A review index, not campaign attestation or a device/release approval.
export function indexBalanceSamples(entries, { sourceFingerprint, gameIds,
  engineVersion = '4.7.1-stable (official)' }) {
  if (!/^[a-f0-9]{64}$/.test(sourceFingerprint) || !Array.isArray(entries) ||
      !Array.isArray(gameIds) || !gameIds.length ||
      gameIds.some(id => typeof id !== 'string' || !id) ||
      new Set(gameIds).size !== gameIds.length) throw new Error('Invalid review identity');
  const games = new Map(gameIds.map(id => [id, { id, samples: [], flags: new Set() }]));
  const labels = new Set();
  for (const { label, report } of entries) {
    if (typeof label !== 'string' || !label || labels.has(label) ||
        !report || !Array.isArray(report.games) || !report.games.length) {
      throw new Error('Invalid or duplicate report');
    }
    labels.add(label);
    const seen = new Set();
    for (const sample of report.games) {
      if (!sample || !games.has(sample.id) || seen.has(sample.id)) {
        throw new Error('Unknown or duplicate game in report');
      }
      seen.add(sample.id);
      const issues = [];
      const current = report.simulation_source_start === sourceFingerprint &&
        report.simulation_source_end === sourceFingerprint;
      if (!current) issues.push('missing, changed or stale simulation source');
      if (report.engine_version !== engineVersion) issues.push('unverified engine version');
      if (report.sample_mode !== 'natural' || sample.sample_mode !== 'natural') {
        issues.push('natural round evidence required');
      }
      if (!count(sample.runs, 24) || sample.attempted_runs !== sample.runs) {
        issues.push('incomplete baseline');
      }
      if (!count(sample.difficulty_completed, 16) ||
          sample.difficulty_attempted !== sample.difficulty_completed ||
          sample.difficulty_pairing !== 'matched_seed_character') {
        issues.push('incomplete paired difficulty');
      }
      const flagsValid = Array.isArray(sample.flags) &&
        sample.flags.every(flag => typeof flag === 'string' && flag.trim().length);
      if (!flagsValid) issues.push('invalid balance flags');
      if (!Number.isInteger(sample.severity) || sample.severity < 0 || sample.severity > 2 ||
          (flagsValid && ((sample.flags.length > 0) !== (sample.severity > 0)))) {
        issues.push('contradictory severity');
      }
      const game = games.get(sample.id);
      const flags = flagsValid ? [...new Set(sample.flags)] : [];
      // Current warnings remain visible even when another part of a sample is incomplete.
      if (current) for (const flag of flags) game.flags.add(flag);
      game.samples.push({ label, current, eligible: issues.length === 0, issues,
        flags, runs: sample.runs ?? null, paired: sample.difficulty_completed ?? null,
        seedOffset: report.seed_offset ?? null, severity: sample.severity ?? null });
    }
  }
  return {
    sourceFingerprint, campaignAttestationVerified: false, releaseReady: false,
    games: [...games.values()].map(game => {
      const current = game.samples.filter(sample => sample.current);
      return { id: game.id, flags: [...game.flags].sort(), samples: game.samples,
        hasEligibleSample: current.some(sample => sample.eligible),
        requiresBalanceReview: !current.length || game.flags.size > 0 ||
          current.some(sample => !sample.eligible), requiresDeviceReview: true };
    }),
    limitations: ['Preserves recheck history; does not replace strict campaign attestation.',
      'Overlapping sample seeds are not added together as independent matches.',
      'No device, gameplay, archive, upload or release approval is inferred.'],
  };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const [rootArg, ...files] = process.argv.slice(2);
    if (!rootArg || !files.length) throw new Error('Usage: balance-sample-index.mjs ROOT REPORT...');
    const root = path.resolve(rootArg);
    const catalogue = JSON.parse(fs.readFileSync(path.join(root, 'data/minigames.json'), 'utf8'));
    const entries = files.map(filename => ({ label: path.resolve(filename),
      report: JSON.parse(fs.readFileSync(filename, 'utf8')) }));
    console.log(JSON.stringify(indexBalanceSamples(entries, {
      sourceFingerprint: balanceSourceFingerprint(root),
      gameIds: catalogue.games.map(game => game.id),
    }), null, 2));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
