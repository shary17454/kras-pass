import {performance} from 'node:perf_hooks';

// Smoke diagnostics contain operation names and room phases, never payloads.
export class NetworkTiming {
  constructor({now = () => performance.now(), cpu = () => process.cpuUsage()} = {}) {
    this.now = now;
    this.cpu = cpu;
    this.operations = new Map();
    this.stalls = [];
    this.worstStall = null;
    this.previousTime = now();
    this.previousCpu = cpu();
  }

  recordOperation(op, elapsedMs, cpuMs = null) {
    if (typeof op !== 'string' || !/^[a-z_]{1,40}$/.test(op)
      || !Number.isFinite(elapsedMs) || elapsedMs < 0) return;
    if (!this.operations.has(op) && this.operations.size >= 32) return;
    const row = this.operations.get(op) ?? {count: 0, totalMs: 0, maxMs: 0};
    const previousMax = row.maxMs;
    const measuredCpu = Number.isFinite(cpuMs) && cpuMs >= 0;
    row.count++;
    row.totalMs += elapsedMs;
    row.maxMs = Math.max(row.maxMs, elapsedMs);
    if (measuredCpu) {
      row.cpu ??= {count: 0, totalMs: 0, maxMs: 0, atMaxWallMs: null};
      row.cpu.count++;
      row.cpu.totalMs += cpuMs;
      row.cpu.maxMs = Math.max(row.cpu.maxMs, cpuMs);
    }
    if (row.cpu && elapsedMs >= previousMax) row.cpu.atMaxWallMs = measuredCpu ? cpuMs : null;
    this.operations.set(op, row);
  }

  sample(rooms, intervalMs = 100) {
    const time = this.now(), cpu = this.cpu();
    const elapsedMs = time - this.previousTime;
    const cpuMs = (cpu.user - this.previousCpu.user + cpu.system - this.previousCpu.system) / 1000;
    this.previousTime = time;
    this.previousCpu = cpu;
    const delayMs = Math.max(0, elapsedMs - intervalMs);
    if (delayMs < 100) return null;
    const row = {delayMs, elapsedMs, cpuMs, rooms: Array.from(rooms, room => ({
      state: room.state, epoch: room.epoch, game: room.matchConfig?.game,
      arena: room.matchConfig?.arena}))};
    if (!this.worstStall || delayMs > this.worstStall.delayMs) this.worstStall = row;
    if (this.stalls.length < 50) this.stalls.push(row);
    return row;
  }

  report() {
    return {operations: Object.fromEntries(this.operations), stalls: this.stalls,
      worstStall: this.worstStall};
  }
}
