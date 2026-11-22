import fs from 'node:fs';
import path from 'node:path';
import {execFileSync, spawnSync} from 'node:child_process';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';

const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const options = Object.fromEntries(process.argv.slice(2).filter(arg => arg.startsWith('--') && arg.includes('='))
  .map(arg => { const i = arg.indexOf('='); return [arg.slice(2, i), arg.slice(i + 1)]; }));
if (!process.argv.includes('--slot-authorized')) throw Error('Godot is gated: obtain parent slot permission first');
if (!['import', 'tests', 'main-tests', 'capture', 'live'].includes(options.stage)) throw Error('Explicit --stage=import|tests|main-tests|capture|live required');
if (!options.output || !path.isAbsolute(options.output)) throw Error('Absolute fresh --output directory required');
const output = path.resolve(options.output);
if (output === project || output.startsWith(project + path.sep) || fs.existsSync(output)) throw Error('Output must be fresh and outside Git');
const method = options.method ?? 'mobile';
if (!['mobile', 'forward_plus'].includes(method)) throw Error('No renderer fallback is allowed');
if (options.stage === 'live' && (!['1','4'].includes(options.humans ?? '4') || !['ar','en'].includes(options.locale ?? 'ar'))) throw Error('Live cases require humans=1|4 and locale=ar|en');
const live = execFileSync('ps', ['-axo', 'pid,command'], {encoding:'utf8'}).split('\n')
  .filter(line => line.includes('/Applications/Godot.app/Contents/MacOS/Godot') && /--headless|--path/.test(line));
if (live.length >= 3 || live.some(line => line.includes(project))) throw Error('No free slot or existing own Godot process');
const engine = '/Applications/Godot.app/Contents/MacOS/Godot';
const git = (...args) => execFileSync('git', args, {cwd:project, encoding:'utf8'}).trim();
const captureSource = () => {
  const files = git('ls-files', '--cached', '--others', '--exclude-standard').split('\n');
  const hashes = {};
  for (const file of files) {
    if (!/^(src|tests|data)\//.test(file) && file !== 'project.godot') continue;
    const full = path.join(project, file);
    if (fs.statSync(full).isFile()) hashes[file] = createHash('sha256').update(fs.readFileSync(full)).digest('hex');
  }
  return {head:git('rev-parse', 'HEAD'), status:git('status', '--porcelain=v1'), hashes};
};
const write = (name, value) => fs.writeFileSync(path.join(output, name), JSON.stringify(value, null, 2) + '\n', {flag:'wx'});
const before = captureSource();
if (options['expected-commit'] && (!/^[a-f0-9]{40}$/.test(options['expected-commit'])
  || before.head !== options['expected-commit'])) throw Error('Unexpected requested source commit');
fs.mkdirSync(output, {recursive:true});
write('source-before.json', before);
const args = options.stage === 'import' ? ['--headless', '--editor', '--import', '--path', project]
  : ['tests', 'main-tests'].includes(options.stage) ? ['--headless', '--fixed-fps', '60', '--path', project,
    options.stage === 'main-tests' ? 'tests/test_runner.tscn' : 'tests/duel_visibility_runner.tscn']
  : ['--path', project, '--rendering-driver', 'metal', '--rendering-method', method,
    options.stage === 'live' ? 'tests/duel_visibility_live.tscn' : 'tests/duel_visibility_capture.tscn'];
args.splice(args.indexOf('--path'), 0, '--log-file', path.join(output, 'engine.log'));
args.push('--', '--test-data-dir=' + path.join(output, 'save'));
if (options.stage === 'main-tests') args.push('--suite=duel_visibility');
if (['capture', 'live'].includes(options.stage)) args.push('--expect-method=' + method);
if (options.stage === 'live') args.push('--games=duel_pit', '--play-seconds=3', '--humans=' + (options.humans ?? '4'), '--locale=' + (options.locale ?? 'ar'));
write('command.json', {engine, args, stage:options.stage, method, startedAt:new Date().toISOString()});
const fd = fs.openSync(path.join(output, 'stdout.log'), 'wx');
let child;
try { child = spawnSync(engine, args, {cwd:project, stdio:['ignore', fd, fd], timeout:['tests','main-tests'].includes(options.stage) ? 120000 : 300000}); }
finally { fs.closeSync(fd); }
write('terminal.json', {exit:child.status, signal:child.signal, error:child.error?.message ?? null, at:new Date().toISOString()});
const after = captureSource();
write('source-after.json', after);
const guards = ['stdout.log', 'engine.log'].map(file => {
  const r = spawnSync('sh', ['tools/check_godot_log.sh', path.join(output, file), ['tests','main-tests'].includes(options.stage) ? 'tests' : 'runtime'], {cwd:project, encoding:'utf8'});
  return {file, exit:r.status, output:r.stdout + r.stderr};
});
const result = {stage:options.stage, processExit:child.status, stable:JSON.stringify(before) === JSON.stringify(after), guards,
  engineQualified:false, renderedImprovementVerified:false, physicalDeviceQualified:false, releaseReady:false};
write('result.json', result);
console.log(JSON.stringify(result, null, 2));
if (child.status !== 0 || !result.stable || guards.some(g => g.exit !== 0)) process.exitCode = 1;
