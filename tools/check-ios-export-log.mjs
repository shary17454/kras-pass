import fs from 'node:fs';
import {fileURLToPath} from 'node:url';

const extension = 'res://addons/kras_apple_runtime/kras_apple.gdextension';

export function inspectExportLog(text) {
  const lines = text.replace(/\x1b\[[0-9;]*m/g, '').split(/\r?\n/);
  const platformDiagnostics = [], fatal = [];
  let unsupportedEditor = false;
  for (const line of lines) {
    if (/SCRIPT ERROR:|Parse Error:|Failed to load|Error importing|ObjectDB instances? (was |were )?leaked|resources still in use|RID allocations/.test(line)) {
      fatal.push(line);
      continue;
    }
    if (!/^\s*ERROR:/.test(line)) continue;
    const message = line.trim();
    if (message === `ERROR: No GDExtension library found for current OS and architecture (macos.arm64) in configuration file: ${extension}`) {
      unsupportedEditor = true;
      platformDiagnostics.push(message);
    } else if (unsupportedEditor && [
      `ERROR: GDExtension dynamic library not found: '${extension}'.`,
      `ERROR: Error loading extension: '${extension}'.`,
    ].includes(message)) {
      platformDiagnostics.push(message);
    } else {
      fatal.push(message);
    }
  }
  return {fatal, platformDiagnostics, clean: fatal.length === 0 && platformDiagnostics.length === 0};
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  try {
    const report = inspectExportLog(fs.readFileSync(process.argv[2], 'utf8'));
    console.log(JSON.stringify(report));
    if (report.platformDiagnostics.length) {
      console.log('Known iOS-only macOS editor diagnostics retained; this is NOT a clean import/export log.');
    }
    if (report.fatal.length) process.exitCode = 1;
  } catch (error) {
    console.error(`Cannot inspect export log: ${error.message}`);
    process.exitCode = 1;
  }
}
