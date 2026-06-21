import {
  createContext,
  useContext,
  type ReactNode,
} from 'react';
import { useSovereignLoops, type SovereignLoopsState } from '../hooks/useSovereignLoops';

type SovereignLoopContextValue = ReturnType<typeof useSovereignLoops>;

const SovereignLoopContext = createContext<SovereignLoopContextValue | null>(null);

export function SovereignLoopProvider({
  children,
  pollMs,
}: {
  children: ReactNode;
  pollMs?: number;
}) {
  const value = useSovereignLoops(pollMs);
  return (
    <SovereignLoopContext.Provider value={value}>
      {children}
    </SovereignLoopContext.Provider>
  );
}

export function useSovereignLoopContext() {
  const ctx = useContext(SovereignLoopContext);
  if (!ctx) {
    throw new Error('useSovereignLoopContext requires SovereignLoopProvider');
  }
  return ctx;
}

export type { SovereignLoopsState };
