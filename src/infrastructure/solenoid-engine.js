'use strict';

const crypto = require('crypto');

const GENESIS_SEED = 'HELIX_GENESIS_ROOT_AXIS';

const PILLAR_ELEVATORS = [
  '01_greek_vaults',
  '02_infra_oracles',
  '03_zk_mayhem_core',
  '04_akash_gpu_workers',
  '05_arena_leaderboard',
  '06_cross_chain_exec',
  '07_depin_orchestration',
  '08_emission_routing',
  '09_agentswarm_os',
  '10_security_tee_mpc',
  '11_telemetry_observability',
  '12_governance',
  '13_treasury_yield',
  '14_valhalla_portal',
];

const LUA_RATE_LIMIT = `
  local key = KEYS[1]
  local limit = tonumber(ARGV[1])
  local window = tonumber(ARGV[2])
  local current = tonumber(redis.call('get', key) or "0")
  if current + 1 > limit then
    return {0, limit - current}
  else
    redis.call('incrby', key, 1)
    if current == 0 then
      redis.call('expire', key, window)
    end
    return {1, limit - (current + 1)}
  end
`;

class SolenoidStateEngine {
  constructor() {
    this.stateChainHash = crypto.createHash('sha256').update(GENESIS_SEED).digest('hex');
    this.difficultyPrefix = '0000';
    this.activeDimension = 1;
    this.pillarCount = 14;
    this.pillarElevators = [...PILLAR_ELEVATORS];
    this.activeSolenoidMode = 'QUADRILATERAL';
    this.localCacheMap = new Map();
    this._pool = null;
    this._redis = null;
    this._redisBroken = false;
  }

  particilizeRawString(inputData) {
    if (typeof inputData !== 'string') return '';
    return inputData.replace(/[\x00-\x1F\x7F-\x9F]/g, '').trim();
  }

  generateStateAnchor(payloadBuffer, targetLocale = 'en') {
    const serialized =
      typeof payloadBuffer === 'string'
        ? this.particilizeRawString(payloadBuffer)
        : this.particilizeRawString(JSON.stringify(payloadBuffer ?? {}));
    const contentPayload = `${serialized}_${this.stateChainHash}_MODE_${this.activeSolenoidMode}_DIM_${this.activeDimension}_LOC_${targetLocale}`;
    const calculatedHash = crypto.createHash('sha256').update(contentPayload).digest('hex');
    this.stateChainHash = calculatedHash;
    return {
      stateAnchor: `0x${calculatedHash}`,
      activeMode: this.activeSolenoidMode,
      dimensionLevel: this.activeDimension,
      pillarCount: this.pillarCount,
      timestamp: Date.now(),
    };
  }

  shiftToPentagramSolenoid() {
    this.activeSolenoidMode = 'PENTAGRAM';
    this.activeDimension = 3;
    const shiftLogHash = crypto
      .createHash('sha256')
      .update(`PENTAGRAM_SHIFT_${Date.now()}`)
      .digest('hex');
    this.stateChainHash = shiftLogHash;
    return {
      mode: this.activeSolenoidMode,
      dimension: this.activeDimension,
      stateChainHash: this.stateChainHash,
    };
  }

  launchPillarElevators() {
    this.activeSolenoidMode = '14X_ELEVATORS';
    this.activeDimension = 4;
    const elevateLogHash = crypto
      .createHash('sha256')
      .update(`ELEVATOR_LAUNCH_${Date.now()}`)
      .digest('hex');
    this.stateChainHash = elevateLogHash;
    return {
      mode: this.activeSolenoidMode,
      dimension: this.activeDimension,
      pillars: this.pillarElevators,
      stateChainHash: this.stateChainHash,
    };
  }

  async getPool() {
    const url = process.env.DATABASE_URL;
    if (!url) return null;
    if (!this._pool) {
      const { Pool } = require('pg');
      this._pool = new Pool({
        connectionString: url,
        ssl: url.includes('localhost') ? false : { rejectUnauthorized: false },
      });
    }
    return this._pool;
  }

  async getRedis() {
    if (this._redisBroken || !process.env.REDIS_URL) return null;
    if (!this._redis) {
      try {
        const Redis = require('ioredis');
        this._redis = new Redis(process.env.REDIS_URL, {
          maxRetriesPerRequest: 1,
          enableOfflineQueue: false,
        });
        this._redis.on('error', (err) => {
          console.error('[SOLENOID REDIS CRITICAL ERROR]:', err.message);
          this._redisBroken = true;
        });
      } catch (err) {
        console.error('[SOLENOID REDIS INIT]:', err.message);
        this._redisBroken = true;
        return null;
      }
    }
    return this._redis;
  }

  async readThroughCache(key, loader, ttlSeconds = 60) {
    const redis = await this.getRedis();
    if (redis && !this._redisBroken) {
      try {
        const cached = await redis.get(key);
        if (cached) return JSON.parse(cached);
      } catch {
        /* safety canopy */
      }
    }

    const value = await loader();
    if (redis && !this._redisBroken) {
      try {
        await redis.setex(key, ttlSeconds, JSON.stringify(value));
      } catch {
        /* in-memory only */
      }
    } else {
      this.localCacheMap.set(key, { value, expiresAt: Date.now() + ttlSeconds * 1000 });
    }
    return value;
  }

  async enforceRateLimit(identityKey, limitCapacity = 100, windowTimeSeconds = 60) {
    const cleanKey = this.particilizeRawString(String(identityKey || 'anonymous'));
    const redis = await this.getRedis();

    if (!redis || this._redisBroken) {
      const now = Math.floor(Date.now() / 1000);
      const userRecord = this.localCacheMap.get(`limit:${cleanKey}`) || {
        tokens: limitCapacity,
        lastRefill: now,
      };
      const timePassed = now - userRecord.lastRefill;
      userRecord.tokens = Math.min(
        limitCapacity,
        userRecord.tokens + timePassed * (limitCapacity / windowTimeSeconds),
      );
      userRecord.lastRefill = now;
      if (userRecord.tokens < 1) {
        return { allowed: false, remaining: 0, fallback: true };
      }
      userRecord.tokens -= 1;
      this.localCacheMap.set(`limit:${cleanKey}`, userRecord);
      return { allowed: true, remaining: Math.floor(userRecord.tokens), fallback: true };
    }

    try {
      const result = await redis.eval(
        LUA_RATE_LIMIT,
        1,
        `helix_limit:${cleanKey}`,
        limitCapacity,
        windowTimeSeconds,
      );
      return { allowed: result[0] === 1, remaining: result[1], fallback: false };
    } catch (err) {
      console.error('[SAFETY CANOPY FALLBACK ACTIVE] Rate limit fault:', err.message);
      return { allowed: true, remaining: 1, fallback: true };
    }
  }

  getStatus() {
    return {
      stateChainHash: this.stateChainHash,
      activeSolenoidMode: this.activeSolenoidMode,
      activeDimension: this.activeDimension,
      pillarCount: this.pillarCount,
      pillarElevators: this.pillarElevators,
      redisConnected: Boolean(this._redis) && !this._redisBroken,
      databaseConfigured: Boolean(process.env.DATABASE_URL),
    };
  }
}

const solenoidEngine = new SolenoidStateEngine();

module.exports = {
  SolenoidStateEngine,
  solenoidEngine,
  PILLAR_ELEVATORS,
};
