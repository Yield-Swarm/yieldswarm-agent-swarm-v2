"use client";

import { useEffect, useRef, useState } from "react";
import { api } from "@/lib/api";

declare global {
  interface Window {
    Square?: any;
  }
}

const APP_ID = process.env.NEXT_PUBLIC_SQUARE_APP_ID || "";
const LOCATION_ID = process.env.NEXT_PUBLIC_SQUARE_LOCATION_ID || "";
const ENV = process.env.NEXT_PUBLIC_SQUARE_ENVIRONMENT || "sandbox";

function scriptUrl() {
  return ENV === "production"
    ? "https://web.squarecdn.com/v1/square.js"
    : "https://sandbox.web.squarecdn.com/v1/square.js";
}

function loadSquareSdk(): Promise<void> {
  return new Promise((resolve, reject) => {
    if (window.Square) return resolve();
    const existing = document.querySelector<HTMLScriptElement>("script[data-square-sdk]");
    if (existing) {
      existing.addEventListener("load", () => resolve());
      existing.addEventListener("error", () => reject(new Error("Failed to load Square SDK")));
      return;
    }
    const s = document.createElement("script");
    s.src = scriptUrl();
    s.async = true;
    s.dataset.squareSdk = "true";
    s.onload = () => resolve();
    s.onerror = () => reject(new Error("Failed to load Square SDK"));
    document.body.appendChild(s);
  });
}

export function SquarePaymentForm({
  amount,
  currency,
  onChange,
}: {
  amount: string;
  currency: string;
  onChange: () => void;
}) {
  const cardRef = useRef<any>(null);
  const paymentsRef = useRef<any>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const [ready, setReady] = useState(false);
  const [busy, setBusy] = useState<string | null>(null);
  const [status, setStatus] = useState<string | null>(null);
  const [holderName, setHolderName] = useState("");

  useEffect(() => {
    let cancelled = false;
    (async () => {
      try {
        await loadSquareSdk();
        if (cancelled || !window.Square) return;
        const payments = window.Square.payments(APP_ID, LOCATION_ID);
        paymentsRef.current = payments;
        const card = await payments.card();
        if (cancelled) return;
        await card.attach(containerRef.current);
        cardRef.current = card;
        setReady(true);
      } catch (e) {
        setStatus((e as Error).message);
      }
    })();
    return () => {
      cancelled = true;
      cardRef.current?.destroy?.();
    };
  }, []);

  async function payWithToken(sourceId: string, verificationToken: string | undefined, method: "CARD" | "ACH") {
    const res = await api("/api/deposits/square", {
      body: { mode: "payment", amount, currency, sourceId, verificationToken, method },
    });
    if (!res.ok) throw new Error(res.error ?? "Payment failed");
    setStatus(`Deposit submitted (${method}). It will settle shortly.`);
    onChange();
  }

  async function payCard() {
    if (!cardRef.current) return;
    setBusy("card");
    setStatus(null);
    try {
      const result = await cardRef.current.tokenize();
      if (result.status !== "OK") throw new Error(result.errors?.[0]?.message ?? "Card tokenize failed");
      await payWithToken(result.token, undefined, "CARD");
    } catch (e) {
      setStatus((e as Error).message);
    } finally {
      setBusy(null);
    }
  }

  async function payAch() {
    if (!paymentsRef.current) return;
    if (!holderName.trim()) {
      setStatus("Enter the account holder name for ACH.");
      return;
    }
    setBusy("ach");
    setStatus(null);
    try {
      const ach = await paymentsRef.current.ach();
      const result = await ach.tokenize({ accountHolderName: holderName.trim() });
      if (result.status !== "OK") throw new Error(result.errors?.[0]?.message ?? "ACH tokenize failed");
      await payWithToken(result.token, undefined, "ACH");
    } catch (e) {
      setStatus((e as Error).message);
    } finally {
      setBusy(null);
    }
  }

  return (
    <div className="space-y-3">
      <div>
        <p className="label">Card details</p>
        <div ref={containerRef} className="rounded-xl border border-swarm-border bg-black/40 p-3" />
      </div>
      <button className="btn-primary w-full" onClick={payCard} disabled={!ready || !!busy}>
        {busy === "card" ? "Processing…" : `Pay ${amount} ${currency} by card`}
      </button>

      <div className="border-t border-swarm-border pt-3">
        <p className="label">ACH bank transfer</p>
        <input
          className="input"
          placeholder="Account holder name"
          value={holderName}
          onChange={(e) => setHolderName(e.target.value)}
        />
        <button className="btn-muted mt-2 w-full" onClick={payAch} disabled={!ready || !!busy}>
          {busy === "ach" ? "Opening bank link…" : `Pay ${amount} ${currency} via ACH`}
        </button>
      </div>

      {status && <p className="text-xs text-swarm-accent2">{status}</p>}
    </div>
  );
}
