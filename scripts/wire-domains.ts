/**
 * Poseidon Delta Trident v3.05911111100 — Unstoppable Domains + infra wiring.
 *
 * Usage:
 *   npx tsx scripts/wire-domains.ts
 *   npx tsx scripts/wire-domains.ts --dry-run
 */
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, '..');
const MANIFEST = JSON.parse(
  readFileSync(resolve(ROOT, 'config/trident/domains.json'), 'utf8'),
) as DomainManifest;

type DomainManifest = {
  version: string;
  layers: Record<
    string,
    { label: string; domains: Array<Record<string, string>> }
  >;
};

const DRY_RUN = process.argv.includes('--dry-run');
const UD_API_KEY = process.env.UD_API_KEY ?? '';
const UD_API_BASE =
  process.env.UD_API_BASE ?? 'https://api.unstoppabledomains.com';
const VERCEL_TOKEN = process.env.VERCEL_TOKEN ?? '';
const VERCEL_PROJECT_ID = process.env.VERCEL_PROJECT_ID ?? '';
const AKASH_HOST = process.env.AKASH_WORKER_HOST ?? '';
const TRIDENT_VERSION = process.env.TRIDENT_VERSION ?? MANIFEST.version;

type WireResult = {
  host: string;
  role: string;
  target: string;
  status: 'ok' | 'skipped' | 'error';
  detail: string;
};

function log(msg: string) {
  console.error(`[wire-domains] ${msg}`);
}

async function wireUdCrypto(
  host: string,
  record: string,
  address: string,
): Promise<WireResult> {
  if (!UD_API_KEY) {
    return {
      host,
      role: 'ud-crypto',
      target: record,
      status: 'skipped',
      detail: 'UD_API_KEY unset',
    };
  }
  if (DRY_RUN) {
    return {
      host,
      role: 'ud-crypto',
      target: record,
      status: 'ok',
      detail: `dry-run set ${record}=${address.slice(0, 10)}…`,
    };
  }
  try {
    const res = await fetch(`${UD_API_BASE}/domains/${host}/records`, {
      method: 'PUT',
      headers: {
        Authorization: `Bearer ${UD_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ type: record, address }),
    });
    if (!res.ok) {
      const body = await res.text();
      return {
        host,
        role: 'ud-crypto',
        target: record,
        status: 'error',
        detail: `UD API ${res.status}: ${body.slice(0, 120)}`,
      };
    }
    return {
      host,
      role: 'ud-crypto',
      target: record,
      status: 'ok',
      detail: 'crypto record updated',
    };
  } catch (err) {
    return {
      host,
      role: 'ud-crypto',
      target: record,
      status: 'error',
      detail: String(err),
    };
  }
}

async function wireVercel(host: string): Promise<WireResult> {
  if (!VERCEL_TOKEN || !VERCEL_PROJECT_ID) {
    return {
      host,
      role: 'vercel',
      target: 'cname.vercel-dns.com',
      status: 'skipped',
      detail: 'VERCEL_TOKEN or VERCEL_PROJECT_ID unset',
    };
  }
  if (DRY_RUN) {
    return {
      host,
      role: 'vercel',
      target: 'cname.vercel-dns.com',
      status: 'ok',
      detail: 'dry-run attach',
    };
  }
  try {
    const res = await fetch(
      `https://api.vercel.com/v10/projects/${VERCEL_PROJECT_ID}/domains`,
      {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${VERCEL_TOKEN}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ name: host }),
      },
    );
    return {
      host,
      role: 'vercel',
      target: 'cname.vercel-dns.com',
      status: res.ok ? 'ok' : 'error',
      detail: res.ok ? 'domain attached' : `Vercel ${res.status}`,
    };
  } catch (err) {
    return {
      host,
      role: 'vercel',
      target: 'cname.vercel-dns.com',
      status: 'error',
      detail: String(err),
    };
  }
}

async function wireDomain(
  entry: Record<string, string>,
): Promise<WireResult> {
  const host = entry.host;
  const target = entry.target ?? 'vercel';
  const role = entry.role ?? 'unknown';

  switch (target) {
    case 'ud-crypto':
      return wireUdCrypto(
        host,
        entry.record ?? 'crypto.ETH.address',
        process.env.TREASURY_EVM_ADDRESS ??
          process.env.NEXUS_TREASURY_EVM ??
          '0x9505578Bd5b32468E3cEa632664F7b8d2e46128c',
      );
    case 'vercel':
      return wireVercel(host);
    case 'akash':
    case 'wss-ingest':
      return {
        host,
        role,
        target: AKASH_HOST || 'pending-akash-lease',
        status: AKASH_HOST ? 'ok' : 'skipped',
        detail: AKASH_HOST
          ? `route ${entry.path ?? '/'} → ${AKASH_HOST}`
          : 'AKASH_WORKER_HOST unset — deploy Akash first',
      };
    case 'ipfs':
      return {
        host,
        role,
        target: entry.cname ?? 'gateway.pinata.cloud',
        status: 'ok',
        detail: 'IPFS CNAME — configure in UD dashboard or Cloudflare',
      };
    default:
      return {
        host,
        role,
        target,
        status: 'skipped',
        detail: `unknown target ${target}`,
      };
  }
}

async function main() {
  log(`Trident v${TRIDENT_VERSION} domain wiring (dry_run=${DRY_RUN})`);
  const results: WireResult[] = [];

  for (const layer of Object.values(MANIFEST.layers)) {
    log(`Layer: ${layer.label}`);
    for (const domain of layer.domains) {
      const result = await wireDomain(domain);
      results.push(result);
      log(`${result.status.toUpperCase()} ${result.host} — ${result.detail}`);
    }
  }

  const summary = {
    trident_version: TRIDENT_VERSION,
    dry_run: DRY_RUN,
    total: results.length,
    ok: results.filter((r) => r.status === 'ok').length,
    skipped: results.filter((r) => r.status === 'skipped').length,
    errors: results.filter((r) => r.status === 'error').length,
    results,
  };

  console.log(JSON.stringify(summary, null, 2));
  process.exit(summary.errors > 0 ? 1 : 0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
