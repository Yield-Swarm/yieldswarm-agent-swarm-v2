/**
 * TV Command Center dashboard aggregator.
 */

import fs from 'node:fs/promises';
import { getHelixDeltaTelemetry } from './helixDeltaV5.js';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as akash from './akash.js';
import { getVaultTelemetry } from './vaultTelemetry.js';
import * as miningFleet from './miningFleet.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..', '..', '..');

const AGENT_TARGET = Number(process.env.AGENT_COUNT_TOTAL || '10080');
const VAULT_TARGET_USD = Number(process.env.VAULT_TARGET_USD || '5000000');

const NEXUS_TREASURY_SOLANA =
  process.env.TREASURY_SOLANA_ADDRESS ||
  process.env.NEXUS_TREASURY_SOLANA ||
  'kuTcpVPbdC8oYB6gkT2s5tZKzsBsG1hHe7C9zhRpXSN';

const TREASURY_EVM =
  process.env.TREASURY_EVM_ADDRESS ||
  process.env.EMISSION_ROUTER_EVM_ADDRESS ||
  '0x9505578Bd5b32468E3cEa632664F7b8d2e46128c';

const TREASURY_IOTEX =
  process.env.IOTEX_TREASURY_ADDRESS ||
  process.env.TREASURY_IOTEX_ADDRESS ||
  process.env.IOTEX_TREASURY ||
  '';

const MINING_ROOTS = [
  { chain: 'TAO', address: process.env.MINING_ROOT_TAO || '5GwCZMWxtmkjpMzA7p1EFynRFicebo8FNjjqoVugxNMkSQSF' },
  { chain: 'Base ETC', address: process.env.MINING_ROOT_BASE_ETC || '0x3ec1E8B08c2f543b23fD6B21CD812bB31f2E9F00' },
  { chain: 'ZEC', address: process.env.MINING_ROOT_ZEC || 't1KCti3km9DJLxYot3t7NgzYW2FpTnVCvrY' },
  { chain: 'SOL', address: NEXUS_TREASURY_SOLANA },
  { chain: 'IoTeX', address: TREASURY_IOTEX || '0x8f3d03e4c0f36670aa1b6f1e7befa85d50c3a567' },
];

const DOMAINS = [
  { id: 'official', label: 'yieldswarm.xyz', host: 'yieldswarm.xyz', resolved: true },
  { id: 'helix', label: 'helixchain', host: 'helixchain.blockchain', resolved: false },
  { id: 'nexus', label: 'nexuschain', host: 'nexuschain.blockchain', resolved: false },
  { id: 'shadow', label: 'shadowchain', host: 'shadowchain.blockchain', resolved: false },
];

function solanaRpc() {
  const key = process.env.HELIUS_API_KEY;
  if (key) return `https://mainnet.helius-rpc.com/?api-key=${key}`;
  return process.env.SOLANA_RPC_URL || '';
}

function evmRpc() {
  return process.env.QUICKNODE_RPC_URL || process.env.ETHEREUM_RPC_URL || 'https://eth.llamarpc.com';
}

async function fetchSolanaBalance(address) {
  const rpc = solanaRpc();
  if (!rpc || !address) {
    return { chain: 'Solana (Nexus)', address, balance: '—', balanceUsd: null, live: false };
  }
  try {
    const res = await fetch(rpc, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'getBalance', params: [address] }),
    });
    const data = await res.json();
    const sol = (data?.result?.value ?? 0) / 1e9;
    return {
      chain: 'Solana (Nexus)',
      address,
      balance: `${sol.toFixed(4)} SOL`,
      balanceUsd: sol * 150,
      live: true,
    };
  } catch {
    return { chain: 'Solana (Nexus)', address, balance: '—', balanceUsd: null, live: false };
  }
}

async function fetchEvmBalance(address) {
  if (!address) return { chain: 'EVM', address: '', balance: '—', balanceUsd: null, live: false };
  try {
    const res = await fetch(evmRpc(), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jsonrpc: '2.0',
        id: 1,
        method: 'eth_getBalance',
        params: [address, 'latest'],
      }),
    });
    const data = await res.json();
    const wei = BigInt(data?.result || '0x0');
    const eth = Number(wei) / 1e18;
    return { chain: 'EVM', address, balance: `${eth.toFixed(4)} ETH`, balanceUsd: eth * 3200, live: true };
  } catch {
    return { chain: 'EVM', address, balance: '—', balanceUsd: null, live: false };
  }
}

async function readHelixState() {
  try {
    const raw = await fs.readFile(path.join(REPO_ROOT, 'dashboard', 'helix-state.json'), 'utf8');
    const d = JSON.parse(raw);
    return {
      activated: Boolean(d.activated),
      phase: String(d.phase || 'genesis'),
      readiness: Number(d.readinessScore || 72),
    };
  } catch {
    return { activated: false, phase: 'genesis', readiness: 72 };
  }
}

async function fetchMultiCloudStatus() {
  const workers = await akash.getWorkers();
  return [
    {
      id: 'akash',
      label: 'Akash Network',
      live: workers.live,
      workers: workers.totalWorkers || 0,
      detail: workers.live ? 'connected' : 'offline',
    },
    {
      id: 'azure',
      label: 'Azure',
      live: Boolean(process.env.AZURE_SUBSCRIPTION_ID),
      detail: process.env.AZURE_SUBSCRIPTION_ID ? 'configured' : 'unknown',
    },
    {
      id: 'local',
      label: 'Local GPU',
      live: Boolean(process.env.MINING_FLEET_INSTANCES),
      detail: 'fleet env',
    },
    {
      id: 'runpod',
      label: 'RunPod',
      live: Boolean(process.env.RUNPOD_API_KEY),
      detail: process.env.RUNPOD_API_KEY ? 'configured' : 'unknown',
    },
  ];
}

export async function buildTvDashboard() {
  const [vaultTelemetry, helix, clouds, solBal, evmBal, deltaV5] = await Promise.all([
    getVaultTelemetry(),
    readHelixState(),
    fetchMultiCloudStatus(),
    fetchSolanaBalance(NEXUS_TREASURY_SOLANA),
    fetchEvmBalance(TREASURY_EVM),
    Promise.resolve().then(() => getHelixDeltaTelemetry()),
  ]);

  const miningRoutes = miningFleet.getRewardRoutes();
  const miningRoots = MINING_ROOTS.map((r) => ({
    ...r,
    configured: Boolean(r.address),
  }));

  const netWorth = Number(vaultTelemetry.net_worth_usd || 0);
  const blendedApy = Number(vaultTelemetry.blended_apy || 0.37);

  return {
    generatedAt: new Date().toISOString(),
    agents: {
      active: vaultTelemetry.counts?.agents || AGENT_TARGET,
      target: AGENT_TARGET,
      cronsFiring: Number(process.env.CRON_SHARD_COUNT || 120),
      deitiesOnline: 169,
      shards: Number(process.env.CRON_SHARD_COUNT || 120),
    },
    vault: {
      netWorthUsd: netWorth,
      targetUsd: VAULT_TARGET_USD,
      progress: Math.min(1, netWorth / VAULT_TARGET_USD),
      blendedApy,
      treasuryUsd: Number(vaultTelemetry.treasury_usd || 0),
      live: Boolean(vaultTelemetry.live),
    },
    chains: {
      helix,
      nexus: { treasury: NEXUS_TREASURY_SOLANA, solenoid: 1 },
      shadow: { status: process.env.SHADOW_CHAIN_ENABLED === '1' ? 'active' : 'standby' },
    },
    treasury: {
      solana: solBal,
      evm: evmBal,
      iotex: {
        chain: 'IoTeX',
        address: TREASURY_IOTEX,
        balance: '—',
        balanceUsd: null,
        live: Boolean(TREASURY_IOTEX),
      },
    },
    miningRoots,
    miningRoutes: miningRoutes.routes,
    clouds,
    domains: DOMAINS,
    revenueUsd: Number(vaultTelemetry.treasury_usd || 0),
    helixDeltaV5: deltaV5,
  };
}

export default { buildTvDashboard };
