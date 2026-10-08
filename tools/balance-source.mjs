import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';

const roots = ['src', 'scenes', 'data', 'tools'];
const extensions = new Set(['gd', 'tscn', 'scn', 'tres', 'res', 'json', 'gdshader']);
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');

// Mirrors tools/balance_evidence.gd, not an archive or asset fingerprint.
export function balanceSourceFingerprint(root) {
  const entries = new Map();
  function capture(relative) {
    const filename = path.join(root, relative);
    if (!fs.lstatSync(filename).isFile()) throw new Error(`Invalid source file: ${relative}`);
    entries.set(`res://${relative.split(path.sep).join('/')}`, sha256(fs.readFileSync(filename)));
  }
  function walk(relative) {
    for (const entry of fs.readdirSync(path.join(root, relative), { withFileTypes: true })) {
      const child = path.join(relative, entry.name);
      if (entry.isSymbolicLink()) throw new Error(`Source symlink is not qualified: ${child}`);
      if (entry.isDirectory()) {
        if (!entry.name.startsWith('.')) walk(child);
      } else if (extensions.has(path.extname(entry.name).slice(1))) {
        capture(child);
      }
    }
  }
  for (const directory of roots) walk(directory);
  capture('project.godot');
  const names = [...entries.keys()].sort((a, b) => Buffer.compare(Buffer.from(a), Buffer.from(b)));
  return sha256(names.map(name => `${name}:${entries.get(name)}`).join('\n'));
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    console.log(balanceSourceFingerprint(path.resolve(process.argv[2] ?? '.')));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
