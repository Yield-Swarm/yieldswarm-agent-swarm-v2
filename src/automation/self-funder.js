/**
 * Sepolia self-funding daemon — requests testnet ETH for agent wallets on a schedule.
 *
 * Usage: node src/automation/self-funder.js
 * Env: SEPOLIA_AGENT_ADDRESSES (comma-separated), SELF_FUNDER_INTERVAL_MS
 */

import SepoliaAgentWallet from '../agent/wallet/sepolia-agent-wallet.js';

const ADDRESSES = (process.env.SEPOLIA_AGENT_ADDRESSES || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

const INTERVAL_MS = Number(process.env.SELF_FUNDER_INTERVAL_MS || 86_400_000); // 24h

async function fundAddress(wallet, address) {
  const result = await wallet.requestTestnetFunds(address);
  if (result.success) {
    console.log(`[self-funder] funded ${address} via ${result.faucet}`);
  } else {
    console.warn(`[self-funder] failed ${address}: ${result.error}`);
  }
  return result;
}

async function tick() {
  if (ADDRESSES.length === 0) {
    console.log('[self-funder] no SEPOLIA_AGENT_ADDRESSES configured — skipping');
    return;
  }

  const wallet = new SepoliaAgentWallet(null);
  for (const address of ADDRESSES) {
    await fundAddress(wallet, address);
  }
}

async function main() {
  console.log(`[self-funder] monitoring ${ADDRESSES.length} address(es), interval=${INTERVAL_MS}ms`);
  await tick();
  setInterval(() => {
    tick().catch((err) => console.error('[self-funder] tick failed:', err.message));
  }, INTERVAL_MS);
}

main().catch((err) => {
  console.error('[self-funder] fatal:', err);
  process.exit(1);
});
