"use client";

import { useEffect, useMemo, useState } from "react";
import { loadStripe } from "@stripe/stripe-js";
import {
  Elements,
  PaymentElement,
  useElements,
  useStripe,
} from "@stripe/react-stripe-js";
import { api } from "@/lib/api";
import { calculateCustomerPayment } from "@/lib/payments/fees";

interface Breakdown {
  creditAmount: string;
  platformFee: string;
  totalCharge: string;
  feeRate: string;
}

function FeeBreakdown({
  amount,
  currency,
}: {
  amount: string;
  currency: string;
}) {
  const breakdown = useMemo(() => {
    if (!/^\d+(\.\d+)?$/.test(amount) || Number(amount) <= 0) return null;
    return calculateCustomerPayment(amount);
  }, [amount]);

  if (!breakdown) return null;

  return (
    <div className="rounded-xl border border-swarm-border bg-black/40 p-3 text-sm">
      <div className="flex justify-between text-swarm-muted">
        <span>Credit to balance</span>
        <span>
          {breakdown.creditAmount} {currency}
        </span>
      </div>
      <div className="mt-1 flex justify-between text-swarm-muted">
        <span>Platform fee (1%)</span>
        <span>
          {breakdown.platformFee} {currency}
        </span>
      </div>
      <div className="mt-2 flex justify-between border-t border-swarm-border pt-2 font-semibold text-white">
        <span>Total charge</span>
        <span>
          {breakdown.totalCharge} {currency}
        </span>
      </div>
    </div>
  );
}

function StripeElementsForm({
  clientSecret,
  breakdown,
  currency,
  onChange,
}: {
  clientSecret: string;
  breakdown: Breakdown;
  currency: string;
  onChange: () => void;
}) {
  const stripe = useStripe();
  const elements = useElements();
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<string | null>(null);

  async function submit(e: React.FormEvent) {
    e.preventDefault();
    if (!stripe || !elements) return;
    setBusy(true);
    setStatus(null);
    const result = await stripe.confirmPayment({
      elements,
      confirmParams: {
        return_url: `${window.location.origin}/payments?stripe=return`,
      },
      redirect: "if_required",
    });
    if (result.error) {
      setStatus(result.error.message ?? "Payment failed");
      setBusy(false);
      return;
    }
    if (result.paymentIntent?.status === "succeeded") {
      setStatus("Payment succeeded — balance will update shortly.");
      onChange();
    } else {
      setStatus(`Payment status: ${result.paymentIntent?.status ?? "processing"}`);
    }
    setBusy(false);
  }

  return (
    <form onSubmit={submit} className="space-y-3">
      <FeeBreakdown amount={breakdown.creditAmount} currency={currency} />
      <PaymentElement />
      <button className="btn-primary w-full" type="submit" disabled={!stripe || busy}>
        {busy ? "Processing…" : `Pay ${breakdown.totalCharge} ${currency}`}
      </button>
      {status && <p className="text-xs text-swarm-accent2">{status}</p>}
    </form>
  );
}

export function StripePaymentForm({
  amount,
  currency,
  onChange,
}: {
  amount: string;
  currency: string;
  onChange: () => void;
}) {
  const publishableKey = process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY ?? "";
  const [clientSecret, setClientSecret] = useState<string | null>(null);
  const [breakdown, setBreakdown] = useState<Breakdown | null>(null);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState<string | null>(null);

  const stripePromise = useMemo(
    () => (publishableKey ? loadStripe(publishableKey) : null),
    [publishableKey],
  );

  const valid = /^\d+(\.\d+)?$/.test(amount) && Number(amount) > 0;

  useEffect(() => {
    setClientSecret(null);
    setBreakdown(null);
    setStatus(null);
  }, [amount, currency]);

  async function startEmbedded() {
    if (!publishableKey) return;
    setBusy(true);
    setStatus(null);
    try {
      const res = await api<{
        clientSecret: string;
        breakdown: Breakdown;
      }>("/api/deposits/stripe", {
        body: {
          mode: "payment_intent",
          amount,
          currency,
          description: "YieldSwarm payment",
        },
      });
      if (!res.ok || !res.data?.clientSecret) {
        throw new Error(res.error ?? "Could not start Stripe payment");
      }
      setClientSecret(res.data.clientSecret);
      setBreakdown(res.data.breakdown);
    } catch (e) {
      setStatus((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  async function hostedCheckout() {
    setBusy(true);
    setStatus(null);
    try {
      const res = await api<{ checkoutUrl: string; breakdown: Breakdown }>(
        "/api/deposits/stripe",
        {
          body: {
            mode: "checkout",
            amount,
            currency,
            description: "YieldSwarm payment",
          },
        },
      );
      if (!res.ok || !res.data?.checkoutUrl) {
        throw new Error(res.error ?? "Could not create checkout");
      }
      window.location.href = res.data.checkoutUrl;
    } catch (e) {
      setStatus((e as Error).message);
      setBusy(false);
    }
  }

  if (!valid) {
    return (
      <p className="text-xs text-swarm-muted">Enter a valid amount to see the 1% fee breakdown.</p>
    );
  }

  if (clientSecret && breakdown && stripePromise) {
    return (
      <Elements stripe={stripePromise} options={{ clientSecret }}>
        <StripeElementsForm
          clientSecret={clientSecret}
          breakdown={breakdown}
          currency={currency}
          onChange={onChange}
        />
      </Elements>
    );
  }

  return (
    <div className="space-y-3">
      <FeeBreakdown amount={amount} currency={currency} />
      {publishableKey ? (
        <button className="btn-primary w-full" onClick={startEmbedded} disabled={busy}>
          {busy ? "Preparing…" : "Pay with card (Stripe)"}
        </button>
      ) : null}
      <button
        className={publishableKey ? "btn-ghost w-full" : "btn-primary w-full"}
        onClick={hostedCheckout}
        disabled={busy}
      >
        {busy ? "Redirecting…" : "Pay with Stripe Checkout"}
      </button>
      {!publishableKey && (
        <p className="text-xs text-swarm-muted">
          Set NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY to enable the embedded card form.
          Hosted Checkout works with the secret key only.
        </p>
      )}
      {status && <p className="text-xs text-swarm-danger">{status}</p>}
    </div>
  );
}
