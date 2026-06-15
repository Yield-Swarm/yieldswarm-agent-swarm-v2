/** Shared utilities for adapters: a tiny typed event emitter. */
import type { AdapterState, Unsubscribe } from "../types";

export class StateEmitter {
  private listeners = new Set<(s: AdapterState) => void>();

  subscribe(listener: (s: AdapterState) => void): Unsubscribe {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  emit(state: AdapterState): void {
    for (const l of this.listeners) {
      try {
        l(state);
      } catch (err) {
        // A misbehaving listener must not break the emit loop.
        console.error("[wallet] listener error", err);
      }
    }
  }

  clear(): void {
    this.listeners.clear();
  }
}

const SESSION_PREFIX = "yieldswarm.wallet.";

/** Persist the last used connector per namespace to enable auto-reconnect. */
export const session = {
  save(namespace: string, connectorId: string): void {
    try {
      localStorage.setItem(`${SESSION_PREFIX}${namespace}`, connectorId);
    } catch {
      /* storage unavailable (SSR / private mode) */
    }
  },
  load(namespace: string): string | null {
    try {
      return localStorage.getItem(`${SESSION_PREFIX}${namespace}`);
    } catch {
      return null;
    }
  },
  clear(namespace: string): void {
    try {
      localStorage.removeItem(`${SESSION_PREFIX}${namespace}`);
    } catch {
      /* noop */
    }
  },
};
