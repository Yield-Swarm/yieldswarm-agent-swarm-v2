export interface CharacterStateRowProps {
  wallet?: string;
  connected: boolean;
  settlementHash?: string;
  lastSyncedLabel: string;
}

export function CharacterStateRow({
  wallet,
  connected,
  settlementHash,
  lastSyncedLabel,
}: CharacterStateRowProps) {
  const shortWallet = wallet ? `${wallet.slice(0, 6)}…${wallet.slice(-4)}` : "—";
  const shortHash = settlementHash
    ? `${settlementHash.slice(0, 8)}…${settlementHash.slice(-6)}`
    : "—";

  return (
    <section
      style={{
        border: "1px solid #333",
        borderRadius: 10,
        padding: 12,
        background: "#111",
        color: "#eee",
      }}
    >
      <div style={{ fontSize: 12, opacity: 0.65, marginBottom: 8 }}>Character State</div>
      <div style={{ display: "flex", justifyContent: "space-between", fontSize: 14 }}>
        <span>Wallet</span>
        <span>{connected ? shortWallet : "Not connected"}</span>
      </div>
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          fontSize: 14,
          marginTop: 6,
        }}
      >
        <span>On-chain hash</span>
        <span style={{ fontFamily: "monospace", fontSize: 12 }}>{shortHash}</span>
      </div>
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          fontSize: 14,
          marginTop: 6,
        }}
      >
        <span>Last synced</span>
        <span>{lastSyncedLabel}</span>
      </div>
    </section>
  );
}
