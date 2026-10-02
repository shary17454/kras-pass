const finite = value => Number.isFinite(value) && Math.abs(value) <= 10000;
const vector = value => Array.isArray(value) && value.length === 3 && value.every(finite);

export function validBlastWorld(data) {
  return data != null && typeof data === 'object' && !Array.isArray(data)
    && ['position', 'velocity', 'explosion_position'].every(key => vector(data[key]))
    && ['generation', 'explosion_sequence'].every(key => Number.isInteger(data[key]) && data[key] >= 0 && data[key] <= 1000000)
    && typeof data.detonated === 'boolean'
    && Number.isFinite(data.fuse_max) && data.fuse_max > 0 && data.fuse_max <= 60
    && Number.isFinite(data.fuse) && data.fuse >= 0 && data.fuse <= data.fuse_max
    && (!data.detonated || data.fuse === 0);
}

export function validCrumbleWorld(data, tileCount = 113) {
  return !!data && Array.isArray(data.tiles) && data.tiles.length === tileCount
    && data.tiles.every(row => Array.isArray(row) && row.length === 4 && row.every(Number.isFinite)
      && Number.isInteger(row[0]) && row[0] >= 0 && row[0] <= 3
      && row[1] >= 0 && row[1] <= 10 && row[2] >= -32 && row[2] <= 0
      && Number.isInteger(row[3]) && row[3] >= 0 && row[3] <= 1000000
      && (row[0] !== 0 || (row[1] === 0 && row[2] === 0))
      && (row[0] !== 1 || (row[1] <= .9 && row[2] === 0)));
}

export function validColorWorld(data) {
  return validCrumbleWorld(data, 121)
    && Array.isArray(data.colors) && data.colors.length === 121
    && data.colors.every(color => Number.isInteger(color) && color >= 0 && color <= 3)
    && Number.isInteger(data.called) && data.called >= 0 && data.called <= 3
    && Number.isInteger(data.stage) && data.stage >= 0 && data.stage <= 2
    && Number.isFinite(data.timer) && data.timer >= 0 && data.timer <= 60
    && ['call_sequence', 'drop_sequence'].every(key => Number.isInteger(data[key]) && data[key] >= 0 && data[key] <= 1000000);
}

export function validSkyWorld(data, count) {
  return validGoalGuardWorld(data, count)
    && Object.entries({bank: 1, warning: 1.2, tilting: 4, cycle: 9}).every(([key, limit]) => Number.isFinite(data[key]) && data[key] >= 0 && data[key] <= limit)
    && Number.isInteger(data.engine) && data.engine >= -1 && data.engine <= 3
    && ['warning_sequence', 'tilt_sequence'].every(key => Number.isInteger(data[key]) && data[key] >= 0 && data[key] <= 1000000)
    && (data.engine >= 0 || (data.bank === 0 && data.warning === 0 && data.tilting === 0));
}

export function validStormWorld(data, count) {
  return validGoalGuardWorld(data, count, 2)
    && Number.isFinite(data.rotor) && data.rotor >= 0 && data.rotor <= Math.PI * 2
    && Number.isFinite(data.windup) && data.windup >= 0 && data.windup <= 1.6
    && Number.isFinite(data.volley_timer) && data.volley_timer >= 0 && data.volley_timer <= 8
    && ['warning_sequence', 'volley_sequence'].every(key => Number.isInteger(data[key]) && data[key] >= 0 && data[key] <= 1000000);
}

export function validMagnetWorld(data, count) {
  return validGoalGuardWorld(data, count)
    && Array.isArray(data.magnet_charge) && data.magnet_charge.length === count
    && data.magnet_charge.every(value => Number.isFinite(value) && value >= 0 && value <= 1)
    && Array.isArray(data.magnet_active) && data.magnet_active.length === count
    && data.magnet_active.every(value => Number.isFinite(value) && value >= 0 && value <= 1.1)
    && Array.isArray(data.held) && data.held.length === data.balls.length
    && data.held.every(owner => Number.isInteger(owner) && owner >= -1 && owner < count);
}

export function validSaboteurWorld(data, count) {
  return validPaintWorld(data, count) && vector(data.drone)
    && vector(data.scrub_position)
    && ['warning_sequence', 'scrub_sequence'].every(key => Number.isInteger(data[key]) && data[key] >= 0 && data[key] <= 1000000)
    && Number.isFinite(data.rotor) && data.rotor >= 0 && data.rotor <= Math.PI * 2
    && Number.isInteger(data.target) && data.target >= -1 && data.target < 169
    && Number.isFinite(data.mark) && data.mark >= 0 && data.mark <= 1.5
    && Number.isFinite(data.cycle) && data.cycle >= 0 && data.cycle <= 3.4
    && (data.target >= 0 || data.mark === 0);
}

export function validDrawWorld(data, count) {
  const integer = (value, max) => Number.isInteger(value) && value >= 0 && value <= max;
  if (!Number.isInteger(count) || count < 2 || count > 4 || !data || typeof data !== 'object'
    || Array.isArray(data) || Object.keys(data).length !== 8
    || !integer(data.stage, 2) || !integer(data.prompt, 1000000)
    || !['signal_sequence', 'correct_sequence', 'wrong_sequence', 'resolve_sequence']
      .every(key => integer(data[key], 1000000))
    || !Array.isArray(data.locked) || data.locked.length !== count
    || !data.locked.every(value => typeof value === 'boolean')
    || !Array.isArray(data.order) || data.order.length > count) return false;
  const seen = new Set();
  for (const slot of data.order) {
    if (!integer(slot, count - 1) || seen.has(slot) || data.locked[slot]) return false;
    seen.add(slot);
  }
  return data.stage !== 0 || data.order.length === 0;
}

export function validPaintWorld(data, count) {
  return Number.isInteger(count) && count >= 2 && count <= 4 && data != null && typeof data === 'object' && !Array.isArray(data)
    && Array.isArray(data.owners) && data.owners.length === 169
    && data.owners.every(owner => Number.isInteger(owner) && owner >= -1 && owner < count);
}

export function validTagWorld(data, count) {
  return Number.isInteger(count) && count >= 2 && count <= 4 && data != null && typeof data === 'object' && !Array.isArray(data)
    && Number.isInteger(data.hunter) && data.hunter >= -1 && data.hunter < count
    && Number.isFinite(data.grace) && data.grace >= 0 && data.grace <= 1.31;
}

export function validZoneWorld(data) {
  return data != null && typeof data === 'object' && !Array.isArray(data)
    && vector(data.position) && Number.isFinite(data.radius) && data.radius >= .1 && data.radius <= 10
    && typeof data.color === 'string' && /^[0-9a-fA-F]{8}$/.test(data.color);
}

export function validRelicWorld(data, count) {
  return Number.isInteger(count) && count >= 2 && count <= 4 && data != null && typeof data === 'object' && !Array.isArray(data)
    && Number.isInteger(data.holder) && data.holder >= -1 && data.holder < count
    && Array.isArray(data.items) && data.items.length <= 1
    && (data.holder < 0 || data.items.length === 0)
    && validCollectionWorld({items: data.items, carrying: Array(count).fill(0)}, count, 'gem');
}

export function validGoalGuardWorld(data, count, extraBalls = 0) {
  return count >= 2 && count <= 4 && data != null && typeof data === 'object' && !Array.isArray(data)
    && Array.isArray(data.charges) && data.charges.length === count
    && data.charges.every(value => Number.isFinite(value) && value >= 0 && value <= 1)
    && Array.isArray(data.balls) && data.balls.length >= 1 && data.balls.length <= count + extraBalls
    && data.balls.every(ball => ball != null && typeof ball === 'object'
      && typeof ball.heavy === 'boolean' && Number.isInteger(ball.generation)
      && ball.generation >= 0 && ball.generation <= 1000000
      && vector(ball.position) && vector(ball.velocity));
}

export function validCollectionWorld(data, count, kind) {
  if (count < 2 || count > 4 || !data || typeof data !== 'object' || Array.isArray(data)
    || !Array.isArray(data.carrying) || data.carrying.length !== count
    || !data.carrying.every(v => Number.isInteger(v) && v >= 0 && v <= 8)
    || !Array.isArray(data.items) || data.items.length > 256) return false;
  const ids = new Set();
  return data.items.every(row => {
    if (!row || typeof row !== 'object' || typeof row.id !== 'string'
      || !/^[1-9][0-9]{0,18}$/.test(row.id) || BigInt(row.id) > 9223372036854775807n || ids.has(row.id)) return false;
    ids.add(row.id);
    return row.kind === kind && vector(row.position)
      && Number.isFinite(row.rotation) && Math.abs(row.rotation) <= 3.142
      && typeof row.color === 'string' && /^[0-9a-fA-F]{8}$/.test(row.color)
      && Number.isFinite(row.size) && row.size >= .05 && row.size <= 3
      && Number.isInteger(row.value) && row.value >= 1 && row.value <= 1000000;
  });
}
