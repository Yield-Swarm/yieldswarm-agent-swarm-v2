/**
 * Structured pillar telemetry events — consumed by oracle-bridge + Mayhem harnesses.
 */

/**
 * @param {string} pillarId
 * @param {string} event
 * @param {object} payload
 * @returns {object}
 */
export function logPillarTelemetry(pillarId, event, payload = {}) {
  const record = {
    source: "oracle-bridge",
    pillarId,
    event,
    payload,
    timestamp: new Date().toISOString(),
  };
  console.log(JSON.stringify(record));
  return record;
}

export default logPillarTelemetry;
