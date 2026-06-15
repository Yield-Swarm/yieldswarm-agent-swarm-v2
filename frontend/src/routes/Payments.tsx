import { useMemo, useState } from "react";

import { useBalance, useTransfer, useWallet } from "@/wallet";
import { NAMESPACE_LABEL, getChain } from "@/wallet";
import type { ChainNamespace } from "@/wallet";
import { ConnectGate } from "../components/ConnectGate";

const NAMESPACES: ChainNamespace[] = ["evm", "solana", "ton", "bitcoin"];

/**
 * Example treasury / deposit addresses per ecosystem. In production these come
 * from your backend; here they demonstrate the deposit flow end to end.
 */
const TREASURY: Partial<Record<ChainNamespace, string>> = {
  evm: "0x9505578Bd5b32468E3cEa632664F7b8d2e46128c",
  solana: "8JC3My2QqsK4fyTC8Ki3SJ6YZQ4miavzmAt82K1Kpump",
  ton: "EQByfield0000000000000000000000000000000000000000",
  bitcoin: "bc1qexampletreasuryaddressxxxxxxxxxxxxxx",
};

type Mode = "deposit" | "withdraw";

/**
 * Payments — deposit & withdrawal flows. Builds, signs and broadcasts transfers
 * through the unified wallet layer, working identically across EVM/Solana/TON/BTC.
 */
export function Payments() {
  return (
    <ConnectGate
      title="Payments"
      subtitle="Connect a wallet to deposit or withdraw across chains."
    >
      <PaymentsInner />
    </ConnectGate>
  );
}

function PaymentsInner() {
  const wallet = useWallet();
  const connected = useMemo(
    () => NAMESPACES.filter((ns) => wallet.accounts[ns]),
    [wallet.accounts],
  );

  const [namespace, setNamespace] = useState<ChainNamespace>(
    wallet.activeNamespace ?? connected[0] ?? "evm",
  );
  const [mode, setMode] = useState<Mode>("deposit");
  const [amount, setAmount] = useState("");
  const [recipient, setRecipient] = useState("");

  const { data: balance } = useBalance({ namespace });
  const { send, status, result, error, reset } = useTransfer();

  const chain = getChain(wallet.accounts[namespace]?.chainId ?? "");
  const to = mode === "deposit" ? TREASURY[namespace] ?? "" : recipient;
  const busy = status === "signing" || status === "pending";
  const canSubmit = Boolean(to) && Number(amount) > 0 && !busy;

  const handleSubmit = async () => {
    reset();
    await send({ to, amount }, namespace);
  };

  return (
    <section className="page">
      <div className="page__head">
        <h1>Payments</h1>
        <p className="ysw-muted">Deposit to the treasury or withdraw to any address.</p>
      </div>

      <div className="panel pay">
        <div className="pay__row">
          <label>Chain</label>
          <select value={namespace} onChange={(e) => setNamespace(e.target.value as ChainNamespace)}>
            {connected.map((ns) => (
              <option key={ns} value={ns}>
                {NAMESPACE_LABEL[ns]}
              </option>
            ))}
          </select>
        </div>

        <div className="pay__tabs">
          <button
            className={`ysw-tab ${mode === "deposit" ? "ysw-tab--active" : ""}`}
            onClick={() => setMode("deposit")}
          >
            Deposit
          </button>
          <button
            className={`ysw-tab ${mode === "withdraw" ? "ysw-tab--active" : ""}`}
            onClick={() => setMode("withdraw")}
          >
            Withdraw
          </button>
        </div>

        {mode === "withdraw" && (
          <div className="pay__row">
            <label>Recipient</label>
            <input
              placeholder={`${NAMESPACE_LABEL[namespace]} address`}
              value={recipient}
              onChange={(e) => setRecipient(e.target.value)}
            />
          </div>
        )}

        {mode === "deposit" && (
          <div className="pay__row">
            <label>To treasury</label>
            <div className="ysw-mono ysw-muted" style={{ wordBreak: "break-all" }}>{to || "—"}</div>
          </div>
        )}

        <div className="pay__row">
          <label>Amount</label>
          <div className="pay__amount">
            <input
              type="number"
              min="0"
              step="any"
              placeholder="0.0"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
            />
            <span className="ysw-chip">{chain?.nativeCurrency.symbol ?? ""}</span>
          </div>
          <div className="ysw-muted">
            Balance: {balance ? `${balance.formatted} ${balance.symbol}` : "—"}
            {balance && (
              <button
                className="ysw-link"
                onClick={() => setAmount(balance.formatted)}
                type="button"
              >
                Max
              </button>
            )}
          </div>
        </div>

        <button className="ysw-btn" onClick={handleSubmit} disabled={!canSubmit}>
          {busy ? (
            <>
              <span className="ysw-spinner" /> {status === "signing" ? "Confirm in wallet…" : "Broadcasting…"}
            </>
          ) : mode === "deposit" ? (
            "Deposit"
          ) : (
            "Withdraw"
          )}
        </button>

        {status === "success" && result && (
          <div className="pay__result pay__result--ok">
            Transaction sent.
            {result.explorerUrl && (
              <a href={result.explorerUrl} target="_blank" rel="noreferrer">
                View on explorer
              </a>
            )}
          </div>
        )}
        {status === "error" && error && (
          <div className="ysw-error" style={{ margin: "12px 0 0" }}>{error.message}</div>
        )}
      </div>
    </section>
  );
}
