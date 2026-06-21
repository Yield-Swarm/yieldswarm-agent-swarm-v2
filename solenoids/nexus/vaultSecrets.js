/**
 * Vault secret fetcher for all solenoids — AppRole auth + KV v2 read.
 */

export class VaultSecretClient {
  constructor(options = {}) {
    this.addr = options.addr || process.env.VAULT_ADDR || '';
    this.kvMount = options.kvMount || process.env.VAULT_KV_MOUNT || 'yieldswarm';
    this.roleId = options.roleId || process.env.VAULT_ROLE_ID || '';
    this.secretId = options.secretId || process.env.VAULT_SECRET_ID || '';
    this.token = options.token || process.env.VAULT_TOKEN || '';
    this.tokenExpiresAt = 0;
    this.cache = new Map();
    this.cacheTtlMs = options.cacheTtlMs || 60_000;
  }

  configured() {
    return Boolean(this.addr && (this.token || (this.roleId && this.secretId)));
  }

  async authenticate() {
    if (this.token) return this.token;
    if (!this.roleId || !this.secretId) {
      throw new Error('vault credentials not configured');
    }
    const res = await fetch(`${this.addr}/v1/auth/approle/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ role_id: this.roleId, secret_id: this.secretId }),
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok) throw new Error(`vault login failed: ${res.status}`);
    const data = await res.json();
    this.token = data.auth.client_token;
    const lease = data.auth.lease_duration || 3600;
    this.tokenExpiresAt = Date.now() + lease * 1000;
    return this.token;
  }

  async _ensureToken() {
    if (this.token && Date.now() < this.tokenExpiresAt - 30_000) {
      return this.token;
    }
    return this.authenticate();
  }

  async readKv(path) {
    const cacheKey = path;
    const cached = this.cache.get(cacheKey);
    if (cached && Date.now() < cached.expiresAt) {
      return cached.data;
    }

    if (!this.configured()) {
      return null;
    }

    const token = await this._ensureToken();
    const url = `${this.addr}/v1/${this.kvMount}/data/${path}`;
    const res = await fetch(url, {
      headers: { 'X-Vault-Token': token },
      signal: AbortSignal.timeout(10_000),
    });
    if (!res.ok) throw new Error(`vault read failed: ${res.status}`);
    const data = await res.json();
    const secrets = data?.data?.data || {};
    this.cache.set(cacheKey, { data: secrets, expiresAt: Date.now() + this.cacheTtlMs });
    return secrets;
  }

  async readPaths(paths) {
    const out = {};
    for (const p of paths) {
      out[p] = await this.readKv(p);
    }
    return out;
  }

  async secretsForSolenoid(solenoidConfig) {
    const paths = solenoidConfig.vault_secret_paths || [];
    return this.readPaths(paths);
  }
}
