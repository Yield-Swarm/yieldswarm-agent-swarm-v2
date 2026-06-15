import { useState } from "react";

import { useWallet } from "../react/hooks";
import { getChain } from "../chains";
import { shortenAddress } from "../format";
import { AccountModal } from "./AccountModal";
import "./wallet.css";

interface WalletButtonProps {
  /** Optional label override for the disconnected state. */
  label?: string;
}

/**
 * Primary entry point UI — the one component most of the app drops in. Renders a
 * "Connect Wallet" button when disconnected, or an account chip (chain icon +
 * address + connection count) that opens the account modal when connected.
 */
export function WalletButton({ label = "Connect Wallet" }: WalletButtonProps) {
  const wallet = useWallet();
  const [accountOpen, setAccountOpen] = useState(false);

  if (!wallet.isConnected) {
    return (
      <button
        className="ysw-btn"
        onClick={() => wallet.openConnectModal()}
        disabled={wallet.isConnecting}
      >
        {wallet.isConnecting ? <span className="ysw-spinner" /> : null}
        {wallet.isConnecting ? "Connecting…" : label}
      </button>
    );
  }

  const active = wallet.activeAccount;
  const chain = active ? getChain(active.chainId) : null;
  const connectionCount = Object.values(wallet.accounts).filter(Boolean).length;

  return (
    <>
      <button className="ysw-account" onClick={() => setAccountOpen(true)}>
        <span className="ysw-dot" />
        {chain?.iconUrl && <img src={chain.iconUrl} alt={chain.name} />}
        <span>{active ? shortenAddress(active.address) : "Wallet"}</span>
        {connectionCount > 1 && <span className="ysw-chip">+{connectionCount - 1}</span>}
      </button>
      {accountOpen && <AccountModal onClose={() => setAccountOpen(false)} />}
    </>
  );
}
