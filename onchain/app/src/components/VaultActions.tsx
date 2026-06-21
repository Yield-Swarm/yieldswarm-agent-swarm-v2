import { useState } from 'react';

interface VaultActionsProps {
  onDeposit: (lamports: bigint) => Promise<void>;
  onWithdraw: (lamports: bigint) => Promise<void>;
  onClaim: () => Promise<void>;
}

export function VaultActions({ onDeposit, onWithdraw, onClaim }: VaultActionsProps) {
  const [amount, setAmount] = useState('0.1');
  const [busy, setBusy] = useState(false);

  const toLamports = (sol: string) => BigInt(Math.floor(parseFloat(sol || '0') * 1e9));

  const run = async (fn: () => Promise<void>) => {
    setBusy(true);
    try {
      await fn();
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="actions">
      <label>
        Amount (SOL)
        <input
          type="number"
          step="0.01"
          min="0"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
        />
      </label>
      <div className="btn-row">
        <button type="button" className="btn" disabled={busy} onClick={() => run(() => onDeposit(toLamports(amount)))}>
          Deposit
        </button>
        <button type="button" className="btn" disabled={busy} onClick={() => run(() => onWithdraw(toLamports(amount)))}>
          Withdraw
        </button>
        <button type="button" className="btn primary" disabled={busy} onClick={() => run(onClaim)}>
          Claim yield
        </button>
      </div>
    </div>
  );
}
