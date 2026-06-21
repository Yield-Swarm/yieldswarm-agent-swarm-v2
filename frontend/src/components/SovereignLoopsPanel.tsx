import { useEffect, useRef } from 'react';
import { useSovereignLoopContext } from '../context/SovereignLoopContext';
import './SovereignLoopsPanel.css';

const STATE_ACCENTS: Record<string, string> = {
  'Active Loop Running': 'emerald',
  'Rebalancing Funds': 'amber',
  'Deploying Replica': 'cyan',
  'Executing Self-Heal Patch': 'magenta',
  'Configuration Error': 'red',
};

function formatUsd(value: number) {
  if (value >= 1_000_000) return `$${(value / 1_000_000).toFixed(2)}M`;
  if (value >= 1_000) return `$${(value / 1_000).toFixed(1)}K`;
  return `$${value.toFixed(0)}`;
}

function logType(entry: { phase?: string; type?: string; message?: string }) {
  const t = String(entry.type || entry.phase || '').toLowerCase();
  if (t.includes('critical') || t.includes('error') || t.includes('adaptation')) return 'critical';
  if (t.includes('warning') || t.includes('economic') || t.includes('override')) return 'warning';
  if (t.includes('system') || t.includes('replication') || t.includes('boot')) return 'system';
  return 'info';
}

type OverrideButtonProps = {
  label: string;
  onClick: () => void;
  disabled?: boolean;
  accent?: string;
};

function OverrideButton({ label, onClick, disabled, accent = 'cyan' }: OverrideButtonProps) {
  return (
    <button
      type="button"
      className={`slp-btn slp-btn--${accent}`}
      onClick={onClick}
      disabled={disabled}
    >
      {label}
    </button>
  );
}

/**
 * TV-friendly dark-mode panel for Sovereign Loop telemetry.
 * Consumes useSovereignLoopContext (wrap parent in SovereignLoopProvider).
 */
export function SovereignLoopsPanel() {
  const {
    loopState,
    logs,
    metrics,
    thresholds,
    tickCount,
    credentialsOk,
    loading,
    error,
    actionPending,
    forceRebalance,
    forceReplicate,
    triggerPatch,
    pauseReset,
  } = useSovereignLoopContext();

  const terminalRef = useRef<HTMLDivElement>(null);
  const accent = STATE_ACCENTS[loopState] ?? 'emerald';
  const penningPct = Math.round(metrics.penning_trap_integrity * 100);
  const penningLow = metrics.penning_trap_integrity < (thresholds?.penning_trap_min ?? 0.72);

  useEffect(() => {
    const el = terminalRef.current;
    if (el) el.scrollTop = el.scrollHeight;
  }, [logs.length]);

  return (
    <section className="slp" aria-label="Sovereign Loops Panel">
      <header className={`slp-state slp-state--${accent}`}>
        <span className="slp-pulse" aria-hidden />
        <div>
          <p className="slp-state__label">Active Loop State</p>
          <h1 className="slp-state__value">{loading ? 'Syncing…' : loopState}</h1>
        </div>
        <div className="slp-state__meta">
          <span>Tick {tickCount}</span>
          <span className={credentialsOk ? 'slp-ok' : 'slp-warn'}>
            {credentialsOk ? 'Vault OK' : 'Fallback'}
          </span>
        </div>
      </header>

      {error ? <div className="slp-error" role="alert">{error}</div> : null}

      <div className="slp-metrics">
        <div className="slp-metric">
          <span className="slp-metric__label">Consolidated Treasury</span>
          <span className="slp-metric__value">{formatUsd(metrics.consolidated_treasury_usd)}</span>
        </div>
        <div className="slp-metric slp-metric--wide">
          <span className="slp-metric__label">
            Replication Surplus
            {' '}
            <em>{formatUsd(metrics.replication_surplus_usd)}</em>
          </span>
          <div className="slp-progress" role="progressbar" aria-valuenow={metrics.replication_progress_pct} aria-valuemin={0} aria-valuemax={100}>
            <span className="slp-progress__fill" style={{ width: `${metrics.replication_progress_pct}%` }} />
            <span className="slp-progress__pct">{metrics.replication_progress_pct}%</span>
          </div>
        </div>
        <div className={`slp-metric ${penningLow ? 'slp-metric--alert' : ''}`}>
          <span className="slp-metric__label">Penning Trap Integrity</span>
          <span className="slp-metric__value">{penningPct}%</span>
        </div>
      </div>

      <div className="slp-terminal" ref={terminalRef} role="log" aria-live="polite" aria-relevant="additions">
        {logs.length === 0 ? (
          <div className="slp-log slp-log--info">
            <span className="slp-log__ts">—</span>
            <span className="slp-log__phase">system</span>
            <span className="slp-log__msg">Awaiting telemetry stream…</span>
          </div>
        ) : (
          logs.slice(-40).map((entry, i) => {
            const kind = logType(entry);
            return (
              <div key={`${entry.ts}-${i}`} className={`slp-log slp-log--${kind}`}>
                <span className="slp-log__ts">{entry.ts?.slice(11, 19) ?? '—'}</span>
                <span className="slp-log__phase">{entry.phase ?? '—'}</span>
                <span className="slp-log__msg">{entry.message}</span>
              </div>
            );
          })
        )}
      </div>

      <nav className="slp-actions" aria-label="Manual overrides">
        <OverrideButton
          label="Force Rebalance"
          accent="amber"
          onClick={forceRebalance}
          disabled={!!actionPending}
        />
        <OverrideButton
          label="Force Replicate"
          accent="cyan"
          onClick={forceReplicate}
          disabled={!!actionPending}
        />
        <OverrideButton
          label="Trigger Patch"
          accent="magenta"
          onClick={triggerPatch}
          disabled={!!actionPending}
        />
        <OverrideButton
          label="Pause / Reset"
          accent="emerald"
          onClick={pauseReset}
          disabled={!!actionPending}
        />
      </nav>
    </section>
  );
}
