const finite = value => Number.isFinite(value) && Math.abs(value) <= 10000;
const vector = value => Array.isArray(value) && value.length === 3 && value.every(finite);

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

export function validGoalGuardWorld(data, count) {
  return count >= 2 && count <= 4 && data != null && typeof data === 'object' && !Array.isArray(data)
    && Array.isArray(data.charges) && data.charges.length === count
    && data.charges.every(value => Number.isFinite(value) && value >= 0 && value <= 1)
    && Array.isArray(data.balls) && data.balls.length >= 1 && data.balls.length <= count
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
