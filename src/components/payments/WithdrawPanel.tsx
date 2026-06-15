"use client";

import { useMemo, useState } from "react";
import { api } from "@/lib/api";
import type { ChainKind, PublicConfig } from "./types";

type Tab = "bank" | "web3";

export function WithdrawPanel({
  config,
  balances,
  onChange,
}: {
  config: PublicConfig;
  balances: Record<string, string>;
  onChange: () => void;
}) {
  const [tab, setTab] = useState<Tab>(config.rails.wise ? "bank" : "web3");

  return (
    <section className="panel p-5">
      <h2 className="text-lg font-semibold text-white">Withdraw</h2>
      <div className="mt-3 flex gap-1 rounded-xl border border-swarm-border bg-black/30 p-1">
        <button className={`tab flex-1 ${tab === "bank" ? "tab-active" : ""}`} onClick={() => setTab("bank")}>
          Bank (Wise)
        </button>
        <button className={`tab flex-1 ${tab === "web3" ? "tab-active" : ""}`} onClick={() => setTab("web3")}>
          Wallet (Web3)
        </button>
      </div>
      <div className="mt-4">
        {tab === "bank" ? (
          <BankWithdraw config={config} balances={balances} onChange={onChange} />
        ) : (
          <Web3Withdraw config={config} balances={balances} onChange={onChange} />
        )}
      </div>
    </section>
  );
}

const RECIPIENT_PLACEHOLDERS: Record<string, string> = {
  iban: '{ "iban": "DE89370400440532013000" }',
  aba: '{ "abartn": "026009593", "accountNumber": "12345678", "accountType": "CHECKING", "address": { "country": "US", "city": "NY", "postCode": "10001", "firstLine": "1 Main St" } }',
  sort_code: '{ "sortCode": "231470", "accountNumber": "28821822" }',
  email: '{ "email": "payee@example.com" }',
};

function BankWithdraw({
  config,
  balances,
  onChange,
}: {
  config: PublicConfig;
  balances: Record<string, string>;
  onChange: () => void;
}) {
  const [amount, setAmount] = useState("");
  const [sourceCurrency, setSourceCurrency] = useState(config.fiatCurrencies[0] ?? "USD");
  const [targetCurrency, setTargetCurrency] = useState(config.fiatCurrencies[0] ?? "USD");
  const [type, setType] = useState("iban");
  const [holder, setHolder] = useState("");
  const [details, setDetails] = useState(RECIPIENT_PLACEHOLDERS.iban);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<string | null>(null);

  if (!config.rails.wise) {
    return <Notice>Wise is not configured on the server.</Notice>;
  }

  const available = balances[sourceCurrency] ?? "0";

  async function submit() {
    setBusy(true);
    setStatus(null);
    try {
      let parsedDetails: Record<string, unknown>;
      try {
        parsedDetails = JSON.parse(details);
      } catch {
        throw new Error("Recipient details must be valid JSON");
      }
      const res = await api("/api/withdrawals/bank", {
        body: {
          amount,
          sourceCurrency,
          targetCurrency,
          recipient: { currency: targetCurrency, type, accountHolderName: holder, details: parsedDetails },
        },
      });
      if (!res.ok) throw new Error(res.error ?? "Payout failed");
      setStatus("Payout created via Wise.");
      onChange();
    } catch (e) {
      setStatus((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-3">
      <div className="grid grid-cols-3 gap-2">
        <div>
          <label className="label">Amount</label>
          <input className="input" inputMode="decimal" value={amount} onChange={(e) => setAmount(e.target.value)} />
          <p className="mt-1 text-[11px] text-swarm-muted">Avail: {available}</p>
        </div>
        <div>
          <label className="label">From</label>
          <select className="input" value={sourceCurrency} onChange={(e) => setSourceCurrency(e.target.value)}>
            {config.fiatCurrencies.map((c) => (
              <option key={c}>{c}</option>
            ))}
          </select>
        </div>
        <div>
          <label className="label">To</label>
          <select className="input" value={targetCurrency} onChange={(e) => setTargetCurrency(e.target.value)}>
            {config.fiatCurrencies.map((c) => (
              <option key={c}>{c}</option>
            ))}
          </select>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-2">
        <div>
          <label className="label">Recipient type</label>
          <select
            className="input"
            value={type}
            onChange={(e) => {
              setType(e.target.value);
              setDetails(RECIPIENT_PLACEHOLDERS[e.target.value] ?? "{}");
            }}
          >
            <option value="iban">IBAN</option>
            <option value="aba">ABA (US)</option>
            <option value="sort_code">Sort code (UK)</option>
            <option value="email">Email</option>
          </select>
        </div>
        <div>
          <label className="label">Account holder</label>
          <input className="input" value={holder} onChange={(e) => setHolder(e.target.value)} />
        </div>
      </div>

      <div>
        <label className="label">Recipient details (JSON)</label>
        <textarea className="input min-h-[90px] font-mono text-xs" value={details} onChange={(e) => setDetails(e.target.value)} />
      </div>

      <button className="btn-primary w-full" onClick={submit} disabled={busy || !amount || !holder}>
        {busy ? "Sending…" : "Withdraw to bank"}
      </button>
      {status && <p className="text-xs text-swarm-accent2">{status}</p>}
    </div>
  );
}

function Web3Withdraw({
  config,
  balances,
  onChange,
}: {
  config: PublicConfig;
  balances: Record<string, string>;
  onChange: () => void;
}) {
  const [chain, setChain] = useState<ChainKind>("evm");
  const [evmChainId, setEvmChainId] = useState<number>(config.chains.evm[0]?.id ?? 1);
  const [asset, setAsset] = useState("");
  const [amount, setAmount] = useState("");
  const [toAddress, setToAddress] = useState("");
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<string | null>(null);

  const assets = useMemo(() => {
    if (chain === "evm") return config.chains.evm.find((c) => c.id === evmChainId)?.assets ?? [];
    if (chain === "solana") return config.chains.solana.assets;
    return config.chains.ton.assets;
  }, [chain, evmChainId, config]);

  const currentAsset = asset || assets[0] || "";
  const available = balances[currentAsset] ?? "0";

  async function submit() {
    setBusy(true);
    setStatus(null);
    try {
      const res = await api<{ result: { explorerUrl?: string } }>("/api/withdrawals/web3", {
        body: {
          chain,
          asset: currentAsset,
          amount,
          toAddress,
          evmChainId: chain === "evm" ? evmChainId : undefined,
        },
      });
      if (!res.ok) throw new Error(res.error ?? "Withdrawal failed");
      setStatus(`Sent. ${res.data?.result?.explorerUrl ?? ""}`);
      onChange();
    } catch (e) {
      setStatus((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

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
                <option key={a}>{a}</option>
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
              <option key={a}>{a}</option>
            ))}
          </select>
        </div>
      )}

      <div className="grid grid-cols-2 gap-2">
        <div>
          <label className="label">Amount</label>
          <input className="input" inputMode="decimal" value={amount} onChange={(e) => setAmount(e.target.value)} />
          <p className="mt-1 text-[11px] text-swarm-muted">Avail: {available}</p>
        </div>
      </div>

      <div>
        <label className="label">Destination address</label>
        <input className="input" placeholder="0x… / Solana / TON address" value={toAddress} onChange={(e) => setToAddress(e.target.value)} />
      </div>

      <button className="btn-primary w-full" onClick={submit} disabled={busy || !amount || !toAddress}>
        {busy ? "Sending…" : `Withdraw ${currentAsset}`}
      </button>
      {chain === "ton" && (
        <p className="text-[11px] text-swarm-muted">
          TON withdrawals require a server-side @ton/ton hot wallet; EVM and Solana are enabled.
        </p>
      )}
      {status && <p className="break-all text-xs text-swarm-accent2">{status}</p>}
    </div>
  );
}

function Notice({ children }: { children: React.ReactNode }) {
  return (
    <p className="rounded-xl border border-swarm-border bg-black/30 p-3 text-xs text-swarm-muted">{children}</p>
  );
}
