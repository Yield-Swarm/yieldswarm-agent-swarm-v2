"use client";

import { useMemo, useState } from "react";
import { api } from "@/lib/api";
import { useWallet } from "@/components/wallet/WalletProvider";
import { useTon } from "@/components/wallet/useTon";
import { SquarePaymentForm } from "./SquarePaymentForm";
import { StripePaymentForm } from "./StripePaymentForm";
import type { ChainKind, PublicConfig } from "./types";

type Tab = "stripe" | "square" | "wise" | "web3";

const SQUARE_APP_CONFIGURED = Boolean(
  process.env.NEXT_PUBLIC_SQUARE_APP_ID && process.env.NEXT_PUBLIC_SQUARE_LOCATION_ID,
);

export function DepositPanel({
  config,
  onChange,
}: {
  config: PublicConfig;
  onChange: () => void;
}) {
  const [tab, setTab] = useState<Tab>(
    config.rails.stripe ? "stripe" : config.rails.square ? "square" : config.rails.wise ? "wise" : "web3",
  );

  return (
    <section className="panel p-5">
      <h2 className="text-lg font-semibold text-white">Deposit</h2>
      <p className="mt-1 text-xs text-swarm-muted">
        Card payments include a flat 1% platform fee added to your credit amount.
      </p>
      <div className="mt-3 flex gap-1 rounded-xl border border-swarm-border bg-black/30 p-1">
        {config.rails.stripe && (
          <button className={`tab flex-1 ${tab === "stripe" ? "tab-active" : ""}`} onClick={() => setTab("stripe")}>
            Stripe
          </button>
        )}
        <button className={`tab flex-1 ${tab === "square" ? "tab-active" : ""}`} onClick={() => setTab("square")}>
          Square
        </button>
        <button className={`tab flex-1 ${tab === "wise" ? "tab-active" : ""}`} onClick={() => setTab("wise")}>
          Wise
        </button>
        <button className={`tab flex-1 ${tab === "web3" ? "tab-active" : ""}`} onClick={() => setTab("web3")}>
          Web3
        </button>
      </div>

      <div className="mt-4">
        {tab === "stripe" && <StripeDeposit config={config} onChange={onChange} />}
        {tab === "square" && <SquareDeposit config={config} onChange={onChange} />}
        {tab === "wise" && <WiseDeposit config={config} onChange={onChange} />}
        {tab === "web3" && <Web3Deposit config={config} onChange={onChange} />}
      </div>
    </section>
  );
}

function AmountFields({
  amount,
  setAmount,
  currency,
  setCurrency,
  currencies,
}: {
  amount: string;
  setAmount: (v: string) => void;
  currency: string;
  setCurrency: (v: string) => void;
  currencies: string[];
}) {
  return (
    <div className="grid grid-cols-3 gap-2">
      <div className="col-span-2">
        <label className="label">Amount</label>
        <input className="input" inputMode="decimal" placeholder="100.00" value={amount} onChange={(e) => setAmount(e.target.value)} />
      </div>
      <div>
        <label className="label">Currency</label>
        <select className="input" value={currency} onChange={(e) => setCurrency(e.target.value)}>
          {currencies.map((c) => (
            <option key={c} value={c}>
              {c}
            </option>
          ))}
        </select>
      </div>
    </div>
  );
}

function StripeDeposit({ config, onChange }: { config: PublicConfig; onChange: () => void }) {
  const [amount, setAmount] = useState("");
  const [currency, setCurrency] = useState(config.fiatCurrencies[0] ?? "USD");

  if (!config.rails.stripe) {
    return (
      <Notice>
        Stripe is not configured on the server (set STRIPE_SECRET_KEY and STRIPE_WEBHOOK_SECRET).
      </Notice>
    );
  }

  return (
    <div className="space-y-3">
      <AmountFields
        amount={amount}
        setAmount={setAmount}
        currency={currency}
        setCurrency={setCurrency}
        currencies={config.fiatCurrencies}
      />
      <StripePaymentForm amount={amount} currency={currency} onChange={onChange} />
    </div>
  );
}

function SquareDeposit({ config, onChange }: { config: PublicConfig; onChange: () => void }) {
  const [amount, setAmount] = useState("");
  const [currency, setCurrency] = useState(config.fiatCurrencies[0] ?? "USD");
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<string | null>(null);
  const valid = /^\d+(\.\d+)?$/.test(amount) && Number(amount) > 0;

  if (!config.rails.square) {
    return <Notice>Square is not configured on the server (set SQUARE_ACCESS_TOKEN &amp; SQUARE_LOCATION_ID).</Notice>;
  }

  async function hostedCheckout() {
    setBusy(true);
    setStatus(null);
    try {
      const res = await api<{ checkoutUrl: string }>("/api/deposits/square", {
        body: { mode: "checkout", amount, currency, description: "YieldSwarm deposit" },
      });
      if (!res.ok || !res.data?.checkoutUrl) throw new Error(res.error ?? "Could not create checkout");
      window.location.href = res.data.checkoutUrl;
    } catch (e) {
      setStatus((e as Error).message);
      setBusy(false);
    }
  }

  return (
    <div className="space-y-3">
      <AmountFields
        amount={amount}
        setAmount={setAmount}
        currency={currency}
        setCurrency={setCurrency}
        currencies={config.fiatCurrencies}
      />
      {valid && SQUARE_APP_CONFIGURED ? (
        <SquarePaymentForm amount={amount} currency={currency} onChange={onChange} />
      ) : (
        <>
          <button className="btn-primary w-full" onClick={hostedCheckout} disabled={!valid || busy}>
            {busy ? "Redirecting…" : "Pay by card (Square Checkout)"}
          </button>
          {!SQUARE_APP_CONFIGURED && (
            <p className="text-xs text-swarm-muted">
              Set NEXT_PUBLIC_SQUARE_APP_ID to enable the embedded card &amp; ACH form. Hosted
              checkout (card) is available now.
            </p>
          )}
        </>
      )}
      {status && <p className="text-xs text-swarm-danger">{status}</p>}
    </div>
  );
}

function WiseDeposit({ config, onChange }: { config: PublicConfig; onChange: () => void }) {
  const [amount, setAmount] = useState("");
  const [currency, setCurrency] = useState(config.fiatCurrencies[0] ?? "USD");
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<any>(null);
  const [status, setStatus] = useState<string | null>(null);
  const valid = /^\d+(\.\d+)?$/.test(amount) && Number(amount) > 0;

  if (!config.rails.wise) {
    return <Notice>Wise is not configured on the server (set WISE_API_TOKEN &amp; WISE_PROFILE_ID).</Notice>;
  }

  async function request() {
    setBusy(true);
    setStatus(null);
    setResult(null);
    try {
      const res = await api<{ paymentRequest: any }>("/api/deposits/wise", {
        body: { amount, currency, description: "YieldSwarm deposit" },
      });
      if (!res.ok) throw new Error(res.error ?? "Could not create payment request");
      setResult(res.data?.paymentRequest);
      onChange();
    } catch (e) {
      setStatus((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-3">
      <AmountFields
        amount={amount}
        setAmount={setAmount}
        currency={currency}
        setCurrency={setCurrency}
        currencies={config.fiatCurrencies}
      />
      <button className="btn-primary w-full" onClick={request} disabled={!valid || busy}>
        {busy ? "Creating…" : "Create Wise payment request"}
      </button>
      {result?.link && (
        <a className="btn-ghost w-full" href={result.link} target="_blank" rel="noreferrer">
          Open Wise payment link →
        </a>
      )}
      {result?.kind === "account_details" && (
        <pre className="max-h-40 overflow-auto rounded-xl border border-swarm-border bg-black/40 p-3 text-xs text-slate-300">
          {JSON.stringify(result.accountDetails, null, 2)}
        </pre>
      )}
      {status && <p className="text-xs text-swarm-danger">{status}</p>}
    </div>
  );
}

function Web3Deposit({ config, onChange }: { config: PublicConfig; onChange: () => void }) {
  const wallet = useWallet();
  const ton = useTon();
  const [chain, setChain] = useState<ChainKind>("evm");
  const [evmChainId, setEvmChainId] = useState<number>(config.chains.evm[0]?.id ?? 1);
  const [asset, setAsset] = useState<string>("");
  const [amount, setAmount] = useState("");
  const [intent, setIntent] = useState<{ id: string; depositAddress: string } | null>(null);
  const [txHash, setTxHash] = useState("");
  const [busy, setBusy] = useState<string | null>(null);
  const [status, setStatus] = useState<string | null>(null);

  const assets = useMemo(() => {
    if (chain === "evm") return config.chains.evm.find((c) => c.id === evmChainId)?.assets ?? [];
    if (chain === "solana") return config.chains.solana.assets;
    return config.chains.ton.assets;
  }, [chain, evmChainId, config]);

  const currentAsset = asset || assets[0] || "";

  async function start() {
    setBusy("start");
    setStatus(null);
    setIntent(null);
    try {
      const res = await api<{ intent: { id: string }; depositAddress: string }>("/api/deposits/web3", {
        body: { chain, asset: currentAsset, evmChainId: chain === "evm" ? evmChainId : undefined },
      });
      if (!res.ok || !res.data) throw new Error(res.error ?? "Could not start deposit");
      setIntent({ id: res.data.intent.id, depositAddress: res.data.depositAddress });
    } catch (e) {
      setStatus((e as Error).message);
    } finally {
      setBusy(null);
    }
  }

  async function sendViaWallet() {
    if (!intent) return;
    setBusy("send");
    setStatus(null);
    try {
      let hash = "";
      if (chain === "evm") {
        const meta = config.chains.evmAssetMeta[`${evmChainId}:${currentAsset}`];
        if (!meta) throw new Error(`Unknown asset ${currentAsset}`);
        hash = await wallet.sendEvmDeposit({
          to: intent.depositAddress,
          amount,
          decimals: meta.decimals,
          erc20: meta.native ? undefined : meta.erc20,
        });
      } else if (chain === "solana") {
        hash = await wallet.sendSolanaDeposit({ to: intent.depositAddress, amount });
      } else {
        await ton.sendTon(intent.depositAddress, amount);
        setStatus("TON sent. Paste the transaction hash from your wallet to verify.");
        setBusy(null);
        return;
      }
      setTxHash(hash);
      await verify(hash);
    } catch (e) {
      setStatus((e as Error).message);
    } finally {
      setBusy(null);
    }
  }

  async function verify(hashArg?: string) {
    const hash = hashArg ?? txHash;
    if (!intent || !hash) return;
    setBusy("verify");
    setStatus(null);
    try {
      const res = await api<{ status: string; message?: string }>("/api/deposits/web3/verify", {
        body: { intentId: intent.id, txHash: hash, evmChainId: chain === "evm" ? evmChainId : undefined },
      });
      if (!res.ok) throw new Error(res.error ?? "Verification failed");
      const s = res.data?.status;
      setStatus(
        s === "completed"
          ? "Deposit confirmed and credited."
          : res.data?.message ?? `Status: ${s}. Re-verify once confirmed.`,
      );
      onChange();
    } catch (e) {
      setStatus((e as Error).message);
    } finally {
      setBusy(null);
    }
  }

  const treasuryMissing =
    (chain === "evm" && !config.treasury.evm) ||
    (chain === "solana" && !config.treasury.solana) ||
    (chain === "ton" && !config.treasury.ton);

  return (
    <div className="space-y-3">
      <div className="grid grid-cols-2 gap-2">
        <div>
          <label className="label">Network</label>
          <select
            className="input"
            value={chain}
            onChange={(e) => {
              setChain(e.target.value as ChainKind);
              setAsset("");
              setIntent(null);
            }}
          >
            <option value="evm">EVM</option>
            <option value="solana">Solana</option>
            <option value="ton">TON</option>
          </select>
        </div>
        {chain === "evm" ? (
          <div>
            <label className="label">Chain</label>
            <select className="input" value={evmChainId} onChange={(e) => setEvmChainId(Number(e.target.value))}>
              {config.chains.evm.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
            </select>
          </div>
        ) : (
          <div>
            <label className="label">Asset</label>
            <select className="input" value={currentAsset} onChange={(e) => setAsset(e.target.value)}>
              {assets.map((a) => (
                <option key={a} value={a}>
                  {a}
                </option>
              ))}
            </select>
          </div>
        )}
      </div>

      {chain === "evm" && (
        <div>
          <label className="label">Asset</label>
          <select className="input" value={currentAsset} onChange={(e) => setAsset(e.target.value)}>
            {assets.map((a) => (
              <option key={a} value={a}>
                {a}
              </option>
            ))}
          </select>
        </div>
      )}

      <div>
        <label className="label">Amount</label>
        <input className="input" inputMode="decimal" placeholder="0.05" value={amount} onChange={(e) => setAmount(e.target.value)} />
      </div>

      {treasuryMissing ? (
        <Notice>Treasury address for {chain.toUpperCase()} is not configured on the server.</Notice>
      ) : !intent ? (
        <button className="btn-primary w-full" onClick={start} disabled={busy === "start" || !currentAsset}>
          {busy === "start" ? "Preparing…" : "Start deposit"}
        </button>
      ) : (
        <div className="space-y-3">
          <div className="rounded-xl border border-swarm-border bg-black/40 p-3">
            <p className="label">Send {currentAsset} to</p>
            <p className="break-all font-mono text-xs text-swarm-accent2">{intent.depositAddress}</p>
          </div>
          <button
            className="btn-muted w-full"
            onClick={sendViaWallet}
            disabled={!!busy || !amount}
          >
            {busy === "send" ? "Sending…" : `Send with ${chain.toUpperCase()} wallet`}
          </button>
          <div>
            <label className="label">…or paste transaction hash</label>
            <input className="input" placeholder="0x… / signature" value={txHash} onChange={(e) => setTxHash(e.target.value)} />
          </div>
          <button className="btn-primary w-full" onClick={() => verify()} disabled={busy === "verify" || !txHash}>
            {busy === "verify" ? "Verifying…" : "Verify deposit"}
          </button>
        </div>
      )}

      {status && <p className="text-xs text-swarm-accent2">{status}</p>}
    </div>
  );
}

function Notice({ children }: { children: React.ReactNode }) {
  return (
    <p className="rounded-xl border border-swarm-border bg-black/30 p-3 text-xs text-swarm-muted">
      {children}
    </p>
  );
}
