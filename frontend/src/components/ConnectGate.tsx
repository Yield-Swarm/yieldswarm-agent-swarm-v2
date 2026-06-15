import type { ReactNode } from "react";

import { useWallet } from "@/wallet";

/**
 * Wraps page content that requires a connected wallet. Renders a friendly
 * connect prompt (opening the unified modal) until at least one ecosystem is
 * connected.
 */
export function ConnectGate({
  title = "Connect your wallet",
  subtitle = "Connect an EVM, Solana, TON, or Bitcoin wallet to continue.",
  children,
}: {
  title?: string;
  subtitle?: string;
  children: ReactNode;
}) {
  const wallet = useWallet();

  if (wallet.initializing) {
    return (
      <div className="gate">
        <span className="ysw-spinner" />
        <p>Restoring wallet session…</p>
      </div>
    );
  }

  if (!wallet.isConnected) {
    return (
      <div className="gate">
        <h2>{title}</h2>
        <p>{subtitle}</p>
        <button className="ysw-btn" onClick={() => wallet.openConnectModal()}>
          Connect Wallet
        </button>
      </div>
    );
  }

  return <>{children}</>;
}
