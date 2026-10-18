import {execFileSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';

export function requireSimulatorArchitecture(available, requested) {
  if (!['arm64', 'x86_64'].includes(requested)) {
    throw new Error(`Unsupported simulator architecture: ${requested}`);
  }
  if (!available.trim().split(/\s+/).includes(requested)) {
    throw new Error(`Godot simulator library lacks ${requested} (actual: ${available.trim()}). Obtain a compatible engine template; XCFramework metadata is not architecture evidence.`);
  }
  return requested;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const [library, requested] = process.argv.slice(2);
    if (!library || !requested || process.argv.length !== 4) {
      throw new Error('Usage: check-ios-simulator-arch.mjs LIBRARY ARCH');
    }
    const available = execFileSync('lipo', ['-archs', library], {encoding: 'utf8'});
    console.log(requireSimulatorArchitecture(available, requested));
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
