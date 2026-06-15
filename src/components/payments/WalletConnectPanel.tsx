"use client";

import { useEffect, useRef, useState } from "react";
import { api } from "@/lib/api";
import { useWallet } from "@/components/wallet/WalletProvider";
import { useTon } from "@/components/wallet/useTon";
import type { LinkedWallet, PublicConfig } from "./types";

function shorten(addr: string) {
  return addr.length > 14 ? `${addr.slice(0, 8)}…${addr.slice(-6)}` : addr;
}

export function WalletConnectPanel({
  config,
  wallets,
  onLinked,
}: {
  config: PublicConfig;
  wallets: LinkedWallet[];
  onLinked: () => void;
}) {
  void config;
  const wallet = useWallet();
  const ton = useTon();
  const [status, setStatus] = useState<string | null>(null);
  const [busy, setBusy] = useState<string | null>(null);
  const tonLinking = useRef(false);

  const linked = (chain: string, address?: string) =>
    wallets.some(
      (w) => w.chain === chain && (!address || w.address.toLowerCase() === address.toLowerCase()),
    );

  async function linkEvm() {
    setBusy("evm");
    setStatus(null);
    try {
      const conn = await wallet.connectEvm();
      if (!conn) throw new Error(wallet.error ?? "Connection failed");
      const nonce = await api<{ message: string }>("/api/wallets/nonce", {
        body: { chain: "evm", address: conn.address },
      });
      if (!nonce.ok || !nonce.data) throw new Error(nonce.error ?? "Could not get challenge");
      const signature = await wallet.signEvm(nonce.data.message);
      const res = await api("/api/wallets", {
        body: { chain: "evm", address: conn.address, message: nonce.data.message, signature },
      });
      if (!res.ok) throw new Error(res.error ?? "Link failed");
      setStatus("EVM wallet linked.");
      onLinked();
    } catch (e) {
      setStatus((e as Error).message);
    } finally {
      setBusy(null);
    }
  }

  async function linkSolana() {
    setBusy("solana");
    setStatus(null);
    try {
      const conn = await wallet.connectSolana();
      if (!conn) throw new Error(wallet.error ?? "Connection failed");
      const nonce = await api<{ message: string }>("/api/wallets/nonce", {
        body: { chain: "solana", address: conn.address },
      });
      if (!nonce.ok || !nonce.data) throw new Error(nonce.error ?? "Could not get challenge");
      const signature = await wallet.signSolana(nonce.data.message);
      const res = await api("/api/wallets", {
        body: { chain: "solana", address: conn.address, message: nonce.data.message, signature },
      });
      if (!res.ok) throw new Error(res.error ?? "Link failed");
      setStatus("Solana wallet linked.");
      onLinked();
    } catch (e) {
      setStatus((e as Error).message);
    } finally {
      setBusy(null);
    }
  }

  async function linkTon() {
    setBusy("ton");
    setStatus(null);
    try {
      tonLinking.current = true;
      await ton.connectWithProof(crypto.randomUUID());
    } catch (e) {
      setStatus((e as Error).message);
      tonLinking.current = false;
      setBusy(null);
    }
  }

  // Submit the TON proof once the wallet connects.
  useEffect(() => {
    if (!tonLinking.current || !ton.wallet) return;
    const proofItem = ton.wallet.connectItems?.tonProof;
    const account = ton.wallet.account;
    if (proofItem && "proof" in proofItem && account.publicKey) {
      tonLinking.current = false;
      const { proof } = proofItem;
      (async () => {
        const res = await api("/api/wallets", {
          body: {
            chain: "ton",
            address: account.address,
            message: "ton_proof",
            signature: proof.signature,
            tonProof: {
              publicKey: account.publicKey,
              address: account.address,
              domain: proof.domain.value,
              timestamp: proof.timestamp,
              payload: proof.payload,
              signature: proof.signature,
            },
          },
        });
        setStatus(res.ok ? "TON wallet linked." : res.error ?? "TON link failed");
        setBusy(null);
        if (res.ok) onLinked();
      })();
    }
  }, [ton.wallet, onLinked]);

  return (
    <section className="panel p-5">
      <h2 className="text-lg font-semibold text-white">Connect wallets</h2>
      <p className="mt-1 text-sm text-swarm-muted">
        Link a self-custody wallet to deposit or withdraw on-chain. Linking proves ownership via a
        signed message.
      </p>

      <div className="mt-4 space-y-3">
        <WalletRow
          label="EVM (MetaMask)"
          connected={wallet.evm?.address}
          linked={linked("evm", wallet.evm?.address)}
          busy={busy === "evm"}
          onClick={linkEvm}
        />
        <WalletRow
          label="Solana (Phantom)"
          connected={wallet.solana?.address}
          linked={linked("solana", wallet.solana?.address)}
          busy={busy === "solana"}
          onClick={linkSolana}
        />
        <WalletRow
          label="TON (TonConnect)"
          connected={ton.address || undefined}
          linked={linked("ton")}
          busy={busy === "ton"}
          onClick={linkTon}
        />
      </div>

      {wallets.length > 0 && (
        <div className="mt-4 border-t border-swarm-border pt-3">
          <p className="label">Linked</p>
          <ul className="space-y-1">
            {wallets.map((w) => (
              <li key={w.id} className="flex items-center justify-between text-xs">
                <span className="chip uppercase">{w.chain}</span>
                <span className="font-mono text-slate-300">{shorten(w.address)}</span>
              </li>
            ))}
          </ul>
        </div>
      )}

      {status && <p className="mt-3 text-xs text-swarm-accent2">{status}</p>}
    </section>
  );
}

function WalletRow({
  label,
  connected,
  linked,
  busy,
  onClick,
}: {
  label: string;
  connected?: string;
  linked: boolean;
  busy: boolean;
  onClick: () => void;
}) {
  return (
    <div className="flex items-center justify-between rounded-xl border border-swarm-border bg-black/30 px-4 py-3">
      <div>
        <p className="text-sm font-medium text-slate-200">{label}</p>
        {connected ? (
          <p className="font-mono text-xs text-swarm-muted">{shorten(connected)}</p>
        ) : (
          <p className="text-xs text-swarm-muted">Not connected</p>
        )}
      </div>
      <button className="btn-ghost !px-3 !py-1.5 text-xs" onClick={onClick} disabled={busy}>
        {busy ? "…" : linked ? "Re-link" : "Connect & link"}
      </button>
    </div>
  );
}
