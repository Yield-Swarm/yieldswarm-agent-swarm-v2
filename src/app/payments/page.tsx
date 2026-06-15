import { PaymentsApp } from "@/components/payments/PaymentsApp";

export const dynamic = "force-dynamic";

export default function PaymentsPage() {
  return (
    <main className="mx-auto max-w-5xl px-4 py-8 md:py-12">
      <header className="mb-8">
        <div className="flex items-center gap-2 text-sm text-swarm-muted">
          <span className="chip border-swarm-accent/40 text-swarm-accent">YieldSwarm</span>
          <span>Payment Rails</span>
        </div>
        <h1 className="mt-3 text-3xl font-semibold tracking-tight text-white md:text-4xl">
          Payments
        </h1>
        <p className="mt-2 max-w-2xl text-sm text-swarm-muted">
          Pay by card via Stripe (1% platform fee), Square, Wise, or Web3. Funds credit to your
          unified balance for withdrawals and on-chain off-ramps.
        </p>
      </header>
      <PaymentsApp />
    </main>
  );
}
