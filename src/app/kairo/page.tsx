import Link from "next/link";

export default function KairoPage() {
  return (
    <main className="mx-auto max-w-5xl px-4 py-8 md:py-12">
      <header className="mb-8">
        <div className="flex items-center gap-2 text-sm text-swarm-muted">
          <span className="chip border-emerald-500/40 text-emerald-400">Kairo</span>
          <span>Driver-First Marketplace</span>
        </div>
        <h1 className="mt-3 text-3xl font-semibold tracking-tight text-white md:text-4xl">
          Every Driver Is a YieldSwarm Node
        </h1>
        <p className="mt-2 max-w-2xl text-sm text-swarm-muted">
          Persistent cryptographic identity, signed telemetry, and DePIN rewards
          routed through the Mandelbrot / Tree of Life mesh.
        </p>
      </header>

      <div className="grid gap-4 md:grid-cols-2">
        <Link
          href="/kairo/dashboard"
          className="rounded-xl border border-swarm-border bg-swarm-surface p-6 transition hover:border-emerald-500/40"
        >
          <h2 className="text-lg font-medium text-white">Contribution Dashboard</h2>
          <p className="mt-2 text-sm text-swarm-muted">
            Data contribution stats and estimated DePIN reward points.
          </p>
        </Link>
        <Link
          href="/payments"
          className="rounded-xl border border-swarm-border bg-swarm-surface p-6 transition hover:border-swarm-accent/40"
        >
          <h2 className="text-lg font-medium text-white">Payments &amp; Cashout</h2>
          <p className="mt-2 text-sm text-swarm-muted">
            1% customer fee, 2× driver pay, instant cashout via Square / Wise / Web3.
          </p>
        </Link>
      </div>
    </main>
  );
}
