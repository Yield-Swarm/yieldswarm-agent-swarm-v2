import { useEffect, useMemo, useState } from "react";

import { useConnectModal, useWalletManager } from "../react/hooks";
import { NAMESPACE_LABEL } from "../chains";
import type { ChainNamespace, WalletConnector } from "../types";
import "./wallet.css";

const NAMESPACES: ChainNamespace[] = ["evm", "solana", "ton", "bitcoin"];

/**
 * Built-in multi-wallet connect modal. Groups wallets by ecosystem, shows
 * install state, deep-links to downloads, and reflects connecting/error status.
 */
export function ConnectModal() {
  const { manager } = useWalletManager();
  const modal = useConnectModal();
  const [tab, setTab] = useState<ChainNamespace>("evm");
  const [pending, setPending] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (modal.isOpen) {
      setTab(modal.namespaceFilter ?? "evm");
      setError(null);
      setPending(null);
    }
  }, [modal.isOpen, modal.namespaceFilter]);

  const visibleNamespaces = useMemo(
    () => (modal.namespaceFilter ? [modal.namespaceFilter] : NAMESPACES),
    [modal.namespaceFilter],
  );

  const connectors = useMemo(() => manager.getConnectors(tab), [manager, tab]);

  if (!modal.isOpen) return null;

  const handleConnect = async (c: WalletConnector) => {
    if (!c.installed && c.downloadUrl && !c.remote) {
      window.open(c.downloadUrl, "_blank", "noopener,noreferrer");
      return;
    }
    setPending(c.id);
    setError(null);
    try {
      await manager.connect(c.namespace, c.id);
      modal.close();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to connect");
    } finally {
      setPending(null);
    }
  };

  const installed = connectors.filter((c) => c.installed || c.remote);
  const notInstalled = connectors.filter((c) => !c.installed && !c.remote);

  return (
    <div
      className="ysw-overlay"
      onClick={(e) => {
        if (e.target === e.currentTarget) modal.close();
      }}
      role="dialog"
      aria-modal="true"
      aria-label="Connect a wallet"
    >
      <div className="ysw-modal">
        <div className="ysw-modal__header">
          <h2 className="ysw-modal__title">Connect a wallet</h2>
          <button className="ysw-close" onClick={modal.close} aria-label="Close">
            ×
          </button>
        </div>

        {visibleNamespaces.length > 1 && (
          <div className="ysw-tabs" role="tablist">
            {visibleNamespaces.map((ns) => (
              <button
                key={ns}
                role="tab"
                aria-selected={tab === ns}
                className={`ysw-tab ${tab === ns ? "ysw-tab--active" : ""}`}
                onClick={() => setTab(ns)}
              >
                {NAMESPACE_LABEL[ns]}
              </button>
            ))}
          </div>
        )}

        {error && <div className="ysw-error">{error}</div>}

        <ul className="ysw-list">
          {installed.map((c) => (
            <li key={c.id}>
              <WalletRow connector={c} pending={pending === c.id} onClick={() => handleConnect(c)} />
            </li>
          ))}

          {notInstalled.length > 0 && (
            <li className="ysw-section-label">Not installed</li>
          )}
          {notInstalled.map((c) => (
            <li key={c.id}>
              <WalletRow connector={c} pending={false} onClick={() => handleConnect(c)} />
            </li>
          ))}

          {connectors.length === 0 && (
            <li className="ysw-muted" style={{ padding: 16 }}>
              No {NAMESPACE_LABEL[tab]} wallets available.
            </li>
          )}
        </ul>

        <div className="ysw-footer">
          Powered by the YieldSwarm unified wallet layer · EVM · Solana · TON · Bitcoin
        </div>
      </div>
    </div>
  );
}

function WalletRow({
  connector,
  pending,
  onClick,
}: {
  connector: WalletConnector;
  pending: boolean;
  onClick: () => void;
}) {
  const status = connector.installed
    ? "Detected"
    : connector.remote
      ? "QR / Mobile"
      : "Install";
  return (
    <button className="ysw-wallet" onClick={onClick} disabled={pending}>
      <img
        className="ysw-wallet__icon"
        src={connector.iconUrl}
        alt=""
        onError={(e) => {
          (e.currentTarget as HTMLImageElement).style.visibility = "hidden";
        }}
      />
      <div className="ysw-wallet__body">
        <div className="ysw-wallet__name">{connector.name}</div>
        <div className="ysw-wallet__meta">{NAMESPACE_LABEL[connector.namespace]}</div>
      </div>
      {pending ? (
        <span className="ysw-spinner" />
      ) : (
        <span
          className={`ysw-wallet__badge ${
            connector.installed ? "" : "ysw-wallet__badge--install"
          }`}
        >
          {status}
        </span>
      )}
    </button>
  );
}
