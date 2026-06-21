import { FC } from 'react';
import { WalletMultiButton } from '@solana/wallet-adapter-react-ui';
import { formatApy, formatLamports } from '@yieldswarm/cross-chain-sdk';
import type { YieldVaultState } from '@yieldswarm/cross-chain-sdk';
import { useCrossChainBridge } from '@yieldswarm/cross-chain-sdk';

interface VaultPanelProps {
  vault: YieldVaultState;
}

export const VaultPanel: FC<VaultPanelProps> = ({ vault }) => {
  const bridge = useCrossChainBridge();

  return (
    <section className="panel vault-panel">
      <div className="panel-header">
        <h2>Yield Vault</h2>
        <WalletMultiButton />
      </div>
      {vault.loading && <p className="loading">Loading on-chain state…</p>}
      {vault.error && <p className="error">{vault.error}</p>}
      {!vault.loading && !vault.error && (
        <dl className="stats">
          <div>
            <dt>Current APY</dt>
            <dd>{formatApy(vault.apyBps)}</dd>
          </div>
          <div>
            <dt>Your Deposits</dt>
            <dd>{formatLamports(vault.userDeposits)} SOL</dd>
          </div>
          <div>
            <dt>Pending Referral Rewards</dt>
            <dd>{formatLamports(vault.pendingReferralRewards)} SOL</dd>
          </div>
          <div>
            <dt>Total Cross-Chain Received</dt>
            <dd>{formatLamports(vault.totalReceived)} SOL</dd>
          </div>
          <div>
            <dt>Est. Bridge Gas</dt>
            <dd>{formatLamports(BigInt(bridge.gasEstimate.totalLamports))} SOL</dd>
          </div>
        </dl>
      )}
    </section>
  );
};
