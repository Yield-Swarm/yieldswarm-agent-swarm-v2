/**
 * Akash wallet connection for YieldSwarm integrations.
 * Uses Keplr / Leap when available; falls back to address paste.
 */
(function (global) {
  const CHAIN_ID = 'akashnet-2';

  async function detectWallet() {
    if (global.keplr) return 'keplr';
    if (global.leap) return 'leap';
    return null;
  }

  async function connectAkash() {
    const kind = await detectWallet();
    if (!kind) {
      const manual = global.prompt('Paste Akash address (akash1…):');
      if (!manual || !manual.startsWith('akash1')) throw new Error('Invalid Akash address');
      return { address: manual, provider: 'manual' };
    }
    const wallet = kind === 'keplr' ? global.keplr : global.leap;
    await wallet.enable(CHAIN_ID);
    const offline = await wallet.getOfflineSigner(CHAIN_ID);
    const accounts = await offline.getAccounts();
    if (!accounts.length) throw new Error('No Akash accounts');
    return { address: accounts[0].address, provider: kind };
  }

  async function getBalance(address) {
    const res = await fetch(
      `https://rest.cosmos.directory/akash/cosmos/bank/v1beta1/balances/${address}`
    );
    if (!res.ok) throw new Error('Balance fetch failed');
    const data = await res.json();
    const uakt = data.balances?.find((b) => b.denom === 'uakt');
    return uakt ? Number(uakt.amount) / 1e6 : 0;
  }

  global.YieldSwarmAkash = { connectAkash, getBalance, CHAIN_ID };
})(typeof window !== 'undefined' ? window : globalThis);
