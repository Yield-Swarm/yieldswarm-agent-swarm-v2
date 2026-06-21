import { FC, useState } from 'react';
import { useConnection, useWallet } from '@solana/wallet-adapter-react';
import {
  PublicKey,
  Transaction,
  TransactionInstruction,
} from '@solana/web3.js';
import { CROSS_CHAIN_PROGRAM_ID } from '@yieldswarm/cross-chain-sdk';

type TxAction = 'deposit' | 'withdraw' | 'claim_rewards';

interface TxPanelProps {
  pendingReferralRewards: bigint;
  onLog: (message: string) => void;
}

export const TxPanel: FC<TxPanelProps> = ({ pendingReferralRewards, onLog }) => {
  const { connection } = useConnection();
  const { publicKey, sendTransaction } = useWallet();
  const [amount, setAmount] = useState('0.1');
  const [loading, setLoading] = useState<TxAction | null>(null);

  const runMemoTx = async (action: TxAction, memo: string) => {
    if (!publicKey) {
      onLog('Connect wallet first');
      return;
    }
    setLoading(action);
    onLog(`Submitting ${action}…`);
    try {
      const ix = new TransactionInstruction({
        keys: [{ pubkey: publicKey, isSigner: true, isWritable: true }],
        programId: new PublicKey('MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr'),
        data: new TextEncoder().encode(`YieldSwarm:${action}:${memo}`) as unknown as Buffer,
      });
      const tx = new Transaction().add(ix);
      const sig = await sendTransaction(tx, connection);
      await connection.confirmTransaction(sig, 'confirmed');
      onLog(`${action} confirmed: ${sig.slice(0, 16)}…`);
    } catch (e) {
      onLog(`${action} failed: ${e instanceof Error ? e.message : 'unknown error'}`);
    } finally {
      setLoading(null);
    }
  };

  const deposit = () => runMemoTx('deposit', `${amount} SOL → vault`);
  const withdraw = () => runMemoTx('withdraw', `${amount} SOL ← vault`);
  const claimRewards = () =>
    runMemoTx('claim_rewards', `${pendingReferralRewards.toString()} lamports referral`);

  return (
    <section className="panel tx-panel">
      <h2>Transactions</h2>
      <label className="field">
        <span>Amount (SOL)</span>
        <input
          type="number"
          min="0"
          step="0.01"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
        />
      </label>
      <div className="btn-row">
        <button type="button" disabled={!!loading} onClick={deposit}>
          {loading === 'deposit' ? 'Depositing…' : 'Deposit'}
        </button>
        <button type="button" disabled={!!loading} onClick={withdraw}>
          {loading === 'withdraw' ? 'Withdrawing…' : 'Withdraw'}
        </button>
        <button
          type="button"
          disabled={!!loading || pendingReferralRewards === 0n}
          onClick={claimRewards}
        >
          {loading === 'claim_rewards' ? 'Claiming…' : 'Claim Rewards'}
        </button>
      </div>
      <p className="hint">
        On-chain program: <code>{CROSS_CHAIN_PROGRAM_ID.toBase58().slice(0, 12)}…</code>
      </p>
    </section>
  );
};
