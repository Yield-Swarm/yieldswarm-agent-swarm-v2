/**
 * Sepolia testnet wallet + faucet helper for autonomous agents (browser + Cursor).
 */
export class SepoliaAgentWallet {
  constructor(provider = typeof window !== 'undefined' ? window.ethereum : null) {
    this.provider = provider;
  }

  async connect() {
    if (!this.provider) {
      throw new Error('No injected wallet (window.ethereum)');
    }
    const accounts = await this.provider.request({ method: 'eth_requestAccounts' });
    return accounts[0];
  }

  async requestTestnetFunds(address) {
    const faucets = [
      { url: 'https://sepoliafaucet.com/api/claim', body: { address } },
      { url: 'https://faucet.sepolia.dev/api/claim', body: { address } },
    ];
    for (const { url, body } of faucets) {
      try {
        const res = await fetch(url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
        });
        if (res.ok) return { success: true, faucet: url };
      } catch {
        /* try next */
      }
    }
    return { success: false, error: 'All Sepolia faucets failed or rate-limited' };
  }
}

export default SepoliaAgentWallet;
