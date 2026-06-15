"use client";

import dynamic from "next/dynamic";
import type { ReactNode } from "react";
import { WalletProvider } from "@/components/wallet/WalletProvider";

// TonConnect touches `window`/`localStorage`, so load it client-only.
const TonProvider = dynamic(
  () => import("@/components/wallet/TonProvider").then((m) => m.TonProvider),
  { ssr: false },
);

function manifestUrl(): string {
  if (process.env.NEXT_PUBLIC_TONCONNECT_MANIFEST_URL) {
    return process.env.NEXT_PUBLIC_TONCONNECT_MANIFEST_URL;
  }
  if (typeof window !== "undefined") {
    return `${window.location.origin}/tonconnect-manifest.json`;
  }
  return "http://localhost:3000/tonconnect-manifest.json";
}

export function Providers({ children }: { children: ReactNode }) {
  return (
    <TonProvider manifestUrl={manifestUrl()}>
      <WalletProvider>{children}</WalletProvider>
    </TonProvider>
  );
}
