import {fork} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {NetworkTiming} from './network-timing.js';

function response(child, type, send = false) {
  return new Promise((resolve, reject) => {
    const cleanup = () => {
      clearTimeout(timer);
      child.off('message', message);
      child.off('error', error);
      child.off('exit', exit);
    };
    const error = cause => { cleanup(); child.kill(); reject(cause); };
    const exit = () => error(new Error('Scheduling probe exited before response'));
    const message = value => {
      if (value?.type !== type) return;
      cleanup(); resolve(value.report);
    };
    const timer = setTimeout(() => error(new Error('Scheduling probe response timed out')), 5000);
    child.on('message', message);
    child.on('error', error);
    child.on('exit', exit);
    if (send) child.send({type: 'stop'}, cause => { if (cause) error(cause); });
  });
}

// Optional smoke-only process: no network, room payloads or account data.
export async function startSchedulingProbe() {
  const child = fork(fileURLToPath(import.meta.url), [], {stdio: ['ignore', 'ignore', 'ignore', 'ipc']});
  const exited = new Promise(resolve => child.once('close', resolve));
  try { await response(child, 'ready'); }
  catch (error) { child.kill(); await exited; throw error; }
  return {
    async stop() {
      try { return await response(child, 'report', true); }
      finally { child.kill(); await exited; }
    },
  };
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const timing = new NetworkTiming();
  const timer = setInterval(() => timing.sample([]), 100);
  process.on('message', message => {
    if (message?.type !== 'stop') return;
    clearInterval(timer);
    process.send({type: 'report', report: timing.report()}, () => process.disconnect());
  });
  process.on('disconnect', () => clearInterval(timer));
  process.send({type: 'ready'});
}
