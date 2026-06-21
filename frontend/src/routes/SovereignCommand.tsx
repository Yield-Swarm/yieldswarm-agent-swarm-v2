import { SovereignLoopProvider } from '../context/SovereignLoopContext';
import { SovereignLoopsPanel } from '../components/SovereignLoopsPanel';

/**
 * Full-screen TV command surface for Sovereign Loops (Fire Stick / Pixel / Samsung).
 */
export function SovereignCommand() {
  return (
    <SovereignLoopProvider pollMs={8000}>
      <div className="sovereign-command">
        <header className="sovereign-command__header">
          <h1>YieldSwarm Sovereign Loops</h1>
          <p>Nexus · Helix · Shadow · IoTeX — v1.0.0-Beta</p>
        </header>
        <SovereignLoopsPanel />
      </div>
    </SovereignLoopProvider>
  );
}
