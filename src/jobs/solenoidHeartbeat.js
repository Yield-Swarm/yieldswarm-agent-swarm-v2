'use strict';

const { solenoidEngine } = require('../infrastructure/solenoid-engine');

async function processPillarElevatorHeartbeat() {
  const status = solenoidEngine.getStatus();
  console.log(
    `[PILLAR HEARTBEAT] Mode: ${status.activeSolenoidMode} | Dimension: ${status.activeDimension}D`,
  );

  const pool = await solenoidEngine.getPool();
  if (!pool) {
    console.log('[HEARTBEAT] DATABASE_URL unset — skipping pool_cache evolution (nominal idle).');
    const anchor = solenoidEngine.generateStateAnchor({
      heartbeat: 'idle',
      mode: status.activeSolenoidMode,
      pillars: status.pillarCount,
    });
    return { skipped: true, reason: 'no_database', stateAnchor: anchor.stateAnchor };
  }

  const client = await pool.connect();
  try {
    const rawCacheQuery = await client.query(
      'SELECT * FROM pool_cache ORDER BY updated_at DESC LIMIT 50',
    );
    const records = rawCacheQuery.rows;

    if (records.length === 0) {
      console.log('[HEARTBEAT ALERT] Data registers dry. Skipping evolution cycles.');
      return { skipped: true, reason: 'empty_pool_cache' };
    }

    let processed = 0;
    for (const dataNode of records) {
      const cleanAddress = solenoidEngine.particilizeRawString(dataNode.pool_address);
      const cleanName = solenoidEngine.particilizeRawString(dataNode.pool_name);
      const aprValue = parseFloat(dataNode.apr) || 0.0;
      const tvlValue = parseFloat(dataNode.tvl_usd) || 0.0;
      const protocolStabilityFactor = tvlValue > 10_000_000 ? 1.0 : 0.4;
      const impermanentLossPenalty = 0.15;
      const trueNetYield = aprValue * protocolStabilityFactor - impermanentLossPenalty;

      const performancePayload = {
        address: cleanAddress,
        name: cleanName,
        netYield: parseFloat(trueNetYield.toFixed(4)),
        timestamp: Date.now(),
      };

      solenoidEngine.generateStateAnchor(performancePayload);

      await client.query(
        `INSERT INTO yield_history (chain_slug, pool_address, apr, tvl_usd, recorded_at)
         VALUES ($1, $2, $3, $4, NOW())
         ON CONFLICT (chain_slug, pool_address, recorded_at) DO NOTHING`,
        [dataNode.chain_slug, cleanAddress, parseFloat(trueNetYield.toFixed(4)), tvlValue],
      );
      processed += 1;
    }

    console.log(
      `[EVOLUTION LOG] Synchronized ${processed} nodes. State root: ${solenoidEngine.stateChainHash}`,
    );
    return { skipped: false, processed, stateChainHash: solenoidEngine.stateChainHash };
  } catch (err) {
    console.error('[CORE DEGRADATION ERROR] Elevator loop fault:', err.message);
    return { skipped: true, error: err.message };
  } finally {
    client.release();
  }
}

if (require.main === module) {
  processPillarElevatorHeartbeat()
    .then((result) => {
      console.log(JSON.stringify(result, null, 2));
      process.exit(result.error ? 1 : 0);
    })
    .catch((err) => {
      console.error(err);
      process.exit(1);
    });
}

module.exports = { processPillarElevatorHeartbeat };
