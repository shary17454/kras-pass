const finite = value => Number.isFinite(value) && Math.abs(value) <= 10000;
const vector = value => Array.isArray(value) && value.length === 3 && value.every(finite);

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
