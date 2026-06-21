import { NavLink, Navigate, Route, Routes } from "react-router-dom";

import { WalletButton } from "@/wallet";
import { Arena } from "./routes/Arena";
import { Portal } from "./routes/Portal";
import { Payments } from "./routes/Payments";
import { SovereignCommand } from "./routes/SovereignCommand";

export function App() {
  return (
    <div className="app">
      <header className="topbar">
        <div className="topbar__brand">
          <span className="topbar__logo">◈</span>
          <span>YieldSwarm v2</span>
        </div>
        <nav className="topbar__nav">
          <NavLink to="/arena" className={navClass}>
            Arena
          </NavLink>
          <NavLink to="/portal" className={navClass}>
            Portal
          </NavLink>
          <NavLink to="/payments" className={navClass}>
            Payments
          </NavLink>
          <NavLink to="/sovereign" className={navClass}>
            Sovereign TV
          </NavLink>
        </nav>
        <WalletButton />
      </header>

      <main className="content">
        <Routes>
          <Route path="/" element={<Navigate to="/arena" replace />} />
          <Route path="/arena" element={<Arena />} />
          <Route path="/portal" element={<Portal />} />
          <Route path="/payments" element={<Payments />} />
          <Route path="/sovereign" element={<SovereignCommand />} />
          <Route path="*" element={<Navigate to="/arena" replace />} />
        </Routes>
      </main>

      <footer className="footer">
        Unified wallet layer · EVM · Solana · TON · Bitcoin
      </footer>
    </div>
  );
}

function navClass({ isActive }: { isActive: boolean }) {
  return isActive ? "topbar__link topbar__link--active" : "topbar__link";
}
