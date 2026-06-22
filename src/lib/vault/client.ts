/**
 * HashiCorp Vault KV v2 client — AppRole login + read.
 * Mount: yieldswarm (same as lib/secrets.py and vault/scripts/seed-secrets.sh).
 */

export type VaultKvData = Record<string, string>;

export interface VaultClientOptions {
  addr?: string;
  mount?: string;
  roleId?: string;
  secretId?: string;
  token?: string;
}

function env(name: string): string {
  return process.env[name]?.trim() || "";
}

async function vaultFetch(
  base: string,
  path: string,
  token: string,
  init?: RequestInit,
): Promise<Response> {
  const url = `${base.replace(/\/$/, "")}/v1/${path}`;
  const res = await fetch(url, {
    ...init,
    headers: {
      "X-Vault-Token": token,
      "Content-Type": "application/json",
      ...(init?.headers || {}),
    },
  });
  return res;
}

export async function vaultAppRoleLogin(opts: VaultClientOptions = {}): Promise<string> {
  const addr = opts.addr || env("VAULT_ADDR");
  const roleId = opts.roleId || env("VAULT_ROLE_ID");
  const secretId = opts.secretId || env("VAULT_SECRET_ID");
  if (!addr || !roleId || !secretId) {
    throw new Error("VAULT_ADDR, VAULT_ROLE_ID, and VAULT_SECRET_ID required for AppRole login");
  }

  const res = await fetch(`${addr.replace(/\/$/, "")}/v1/auth/approle/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ role_id: roleId, secret_id: secretId }),
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Vault AppRole login failed (${res.status}): ${body}`);
  }
  const json = (await res.json()) as { auth?: { client_token?: string } };
  const token = json.auth?.client_token;
  if (!token) throw new Error("Vault AppRole login returned no client_token");
  return token;
}

export async function vaultReadKv(
  logicalPath: string,
  opts: VaultClientOptions = {},
): Promise<VaultKvData> {
  const addr = opts.addr || env("VAULT_ADDR");
  const mount = opts.mount || env("VAULT_KV_MOUNT") || "yieldswarm";
  if (!addr) throw new Error("VAULT_ADDR not configured");

  let token = opts.token || env("VAULT_TOKEN");
  if (!token) {
    token = await vaultAppRoleLogin(opts);
  }

  const apiPath = `${mount}/data/${logicalPath}`;
  const res = await vaultFetch(addr, apiPath, token, { method: "GET" });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Vault read ${logicalPath} failed (${res.status}): ${body}`);
  }
  const json = (await res.json()) as { data?: { data?: VaultKvData } };
  return json.data?.data || {};
}
