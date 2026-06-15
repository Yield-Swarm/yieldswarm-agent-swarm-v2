import { useState } from "react";

import { useBalance, useChain, useWallet } from "@/wallet";
import { ConnectGate } from "../components/ConnectGate";

/**
 * Arena — the trading surface. Demonstrates auto-detected chain, live balance,
 * and signature-based session auth, all through the unified wallet layer.
 */
export function Arena() {
  return (
    <ConnectGate
      title="Enter the Arena"
      subtitle="Connect a wallet to trade. The Arena auto-detects your active chain."
    >
      <ArenaInner />
    </ConnectGate>
  );
}

function ArenaInner() {
  const wallet = useWallet();
  const { chain, canSwitch } = useChain();
  const { data: balance } = useBalance();
  const [authToken, setAuthToken] = useState<string | null>(null);
  const [authError, setAuthError] = useState<string | null>(null);
  const [authing, setAuthing] = useState(false);

  const handleAuth = async () => {
    setAuthing(true);
    setAuthError(null);
    try {
      const nonce = Math.random().toString(36).slice(2);
      const sig = await wallet.signMessage(
        `Sign in to YieldSwarm Arena\nNonce: ${nonce}`,
      );
      setAuthToken(sig.slice(0, 24) + "…");
    } catch (err) {
      setAuthError(err instanceof Error ? err.message : "Signature failed");
    } finally {
      setAuthing(false);
    }
  };

  return (
    <section className="page">
      <div className="page__head">
        <h1>Arena</h1>
        <p className="ysw-muted">Trade across chains with one wallet session.</p>
      </div>

      <div className="cards">
        <div className="card">
          <div className="card__label">Active chain (auto-detected)</div>
          <div className="card__value">
            {chain?.iconUrl && <img src={chain.iconUrl} alt="" width={22} height={22} />}
            {chain?.name ?? "—"}
          </div>
          {canSwitch && <div className="ysw-muted">Switchable via the account menu</div>}
        </div>

        <div className="card">
          <div className="card__label">Balance</div>
          <div className="card__value">
            {balance ? `${balance.formatted} ${balance.symbol}` : "—"}
          </div>
        </div>

        <div className="card">
          <div className="card__label">Session</div>
          {authToken ? (
            <div className="card__value" style={{ color: "#3ddc97" }}>Authenticated</div>
          ) : (
            <button className="ysw-btn" onClick={handleAuth} disabled={authing}>
              {authing ? "Signing…" : "Sign in to trade"}
            </button>
          )}
          {authToken && <div className="ysw-mono ysw-muted">{authToken}</div>}
          {authError && <div className="ysw-error" style={{ margin: "8px 0 0" }}>{authError}</div>}
        </div>
      </div>

      <div className="panel">
        <h3>Order ticket</h3>
        <p className="ysw-muted">
          A real exchange UI would render order books and routing here. The point
          for this PR is that the wallet, balance, chain detection, and signing
          all flow through the shared <code>@/wallet</code> layer — no
          per-feature wallet code.
        </p>
        <div className="ticket">
          <button className="ysw-btn" disabled={!authToken}>Buy $APN</button>
          <button className="ysw-btn ysw-btn--ghost" disabled={!authToken}>Sell $APN</button>
        </div>
      </div>
    </section>
  );
}
