import { useBalance, useWallet } from "@/wallet";
import { NAMESPACE_LABEL, explorerAddressUrl, getChain, shortenAddress } from "@/wallet";
import type { ChainNamespace } from "@/wallet";
import { ConnectGate } from "../components/ConnectGate";

const NAMESPACES: ChainNamespace[] = ["evm", "solana", "ton", "bitcoin"];

/**
 * Portal — the cross-chain portfolio dashboard. Fetches balances for every
 * connected ecosystem in parallel through the unified wallet layer.
 */
export function Portal() {
  return (
    <ConnectGate
      title="Your Portal"
      subtitle="Connect wallets to see your unified multi-chain portfolio."
    >
      <PortalInner />
    </ConnectGate>
  );
}

function PortalInner() {
  const wallet = useWallet();
  const connected = NAMESPACES.filter((ns) => wallet.accounts[ns]);

  return (
    <section className="page">
      <div className="page__head">
        <h1>Portal</h1>
        <p className="ysw-muted">
          {connected.length} chain{connected.length === 1 ? "" : "s"} connected
        </p>
      </div>

      <div className="portfolio">
        {connected.map((ns) => (
          <PortfolioRow key={ns} namespace={ns} />
        ))}
      </div>

      <button className="ysw-btn ysw-btn--ghost" onClick={() => wallet.openConnectModal()}>
        + Add another chain
      </button>
    </section>
  );
}

function PortfolioRow({ namespace }: { namespace: ChainNamespace }) {
  const wallet = useWallet();
  const account = wallet.accounts[namespace]!;
  const chain = getChain(account.chainId);
  const { data, isLoading, error, refetch } = useBalance({ namespace });
  const explorer = chain ? explorerAddressUrl(chain, account.address) : undefined;

  return (
    <div className="portfolio__row">
      <div className="portfolio__chain">
        {chain?.iconUrl && <img src={chain.iconUrl} alt="" width={32} height={32} />}
        <div>
          <div className="portfolio__name">{NAMESPACE_LABEL[namespace]}</div>
          <div className="ysw-mono ysw-muted">
            {explorer ? (
              <a href={explorer} target="_blank" rel="noreferrer">
                {shortenAddress(account.address, 6)}
              </a>
            ) : (
              shortenAddress(account.address, 6)
            )}
          </div>
        </div>
      </div>
      <div className="portfolio__balance">
        {error ? (
          <button className="ysw-btn ysw-btn--ghost" onClick={refetch}>
            Retry
          </button>
        ) : isLoading && !data ? (
          <span className="ysw-spinner" />
        ) : (
          <>
            <div className="portfolio__amount">
              {data?.formatted ?? "0"} {data?.symbol}
            </div>
            <button
              className="ysw-btn ysw-btn--ghost"
              style={{ padding: "4px 10px", fontSize: 12 }}
              onClick={() => wallet.setActiveNamespace(namespace)}
            >
              {wallet.activeNamespace === namespace ? "Active" : "Set active"}
            </button>
          </>
        )}
      </div>
    </div>
  );
}
