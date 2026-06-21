import { memo, useCallback, useEffect, useMemo, useRef } from "react";
import { useHelixDeltaStore } from "./helixDeltaStore";
import { useSpaceExpansion } from "./useSpaceExpansion";
import "./helix-delta.css";

const PENNING_CRITICAL = 99.999;

function fmtNum(n: number, digits = 2) {
  return n.toLocaleString(undefined, {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  });
}

function fmtSci(n: number) {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(2)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
  return fmtNum(n, 1);
}

const PenningArc = memo(function PenningArc({ integrity }: { integrity: number }) {
  const radius = 54;
  const circumference = 2 * Math.PI * radius;
  const pct = Math.max(0, Math.min(100, integrity));
  const offset = circumference - (pct / 100) * circumference;

  return (
    <svg className="hdv-arc" viewBox="0 0 128 128" aria-hidden>
      <circle className="hdv-arc__track" cx="64" cy="64" r={radius} />
      <circle
        className="hdv-arc__fill"
        cx="64"
        cy="64"
        r={radius}
        strokeDasharray={circumference}
        strokeDashoffset={offset}
      />
      <text x="64" y="60" className="hdv-arc__label" textAnchor="middle">
        {fmtNum(pct, 3)}%
      </text>
      <text x="64" y="78" className="hdv-arc__sub" textAnchor="middle">
        PENNING
      </text>
    </svg>
  );
});

const VelocityBar = memo(function VelocityBar({ beta }: { beta: number }) {
  const pct = Math.min(100, beta * 100);
  return (
    <div className="hdv-bar">
      <div className="hdv-bar__track">
        <div className="hdv-bar__fill" style={{ width: `${pct}%` }} />
      </div>
      <span className="hdv-mono">{fmtNum(beta, 4)} c</span>
    </div>
  );
});

const CoordMatrix = memo(function CoordMatrix({
  positionMpc,
  distanceMpc,
  shift,
}: {
  positionMpc: number;
  distanceMpc: number;
  shift: { x: number; y: number; z: number };
}) {
  return (
    <div className="hdv-matrix">
      <div className="hdv-matrix__row">
        <span>POS</span>
        <span className="hdv-mono">{fmtSci(positionMpc)} Mpc</span>
      </div>
      <div className="hdv-matrix__row">
        <span>Δ FINAL</span>
        <span className="hdv-mono">{fmtSci(distanceMpc)} Mpc</span>
      </div>
      <div className="hdv-matrix__row">
        <span>SHIFT</span>
        <span className="hdv-mono">
          {fmtNum(shift.x, 3)},{fmtNum(shift.y, 3)},{fmtNum(shift.z, 3)}
        </span>
      </div>
    </div>
  );
});

export const HelixDeltaVariantPanel = memo(function HelixDeltaVariantPanel() {
  const engine = useHelixDeltaStore((s) => s.engine);
  const focused = useHelixDeltaStore((s) => s.focused);
  const setFocused = useHelixDeltaStore((s) => s.setFocused);
  const tick = useHelixDeltaStore((s) => s.tick);
  const space = useSpaceExpansion();
  const rafRef = useRef<number>(0);
  const lastRef = useRef<number>(performance.now());

  const breach = engine.penningTrapIntegrityPct < PENNING_CRITICAL || engine.containmentBreach;

  const panelClass = useMemo(
    () =>
      ["hdv-panel", focused && "hdv-panel--focused", breach && "hdv-panel--alarm"]
        .filter(Boolean)
        .join(" "),
    [focused, breach],
  );

  const onFocus = useCallback(() => setFocused(true), [setFocused]);
  const onBlur = useCallback(() => setFocused(false), [setFocused]);

  useEffect(() => {
    const loop = (now: number) => {
      const dt = Math.min(0.1, (now - lastRef.current) / 1000);
      lastRef.current = now;
      if (dt > 0) tick(dt);
      rafRef.current = requestAnimationFrame(loop);
    };
    rafRef.current = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(rafRef.current);
  }, [tick]);

  return (
    <section
      className={panelClass}
      tabIndex={0}
      onFocus={onFocus}
      onBlur={onBlur}
      aria-label="Helix Chain v5.0 Delta Variant Telemetry"
    >
      <header className="hdv-header">
        <h2>Helix v5.0 · Delta Variant</h2>
        <span className="hdv-tag">Solenoid 2 · Reverberator</span>
      </header>

      <div className="hdv-split">
        <div className="hdv-side hdv-side--reactor">
          <h3>Antimatter Reactor Core</h3>
          <div className="hdv-reactor-grid">
            <PenningArc integrity={engine.penningTrapIntegrityPct} />
            <div className="hdv-readouts">
              <div className="hdv-stat">
                <span className="hdv-stat__label">Antihydrogen Stockpile</span>
                <span className="hdv-mono hdv-stat__value">{fmtNum(engine.fuelStockpileUg, 3)} µg</span>
              </div>
              <div className="hdv-stat">
                <span className="hdv-stat__label">Annihilation Rate</span>
                <span className="hdv-mono hdv-stat__value">{fmtNum(engine.annihilationRateNgPerS, 1)} ng/s</span>
              </div>
              <div className="hdv-stat">
                <span className="hdv-stat__label">Specific Impulse</span>
                <span className="hdv-mono hdv-stat__value">{fmtSci(engine.specificImpulseS)} s</span>
              </div>
              <div className="hdv-stat">
                <span className="hdv-stat__label">γ Flux / Pions</span>
                <span className="hdv-mono hdv-stat__value">
                  {fmtNum(engine.gammaFluxSvPerS, 2)} Sv/s · {fmtSci(engine.pionRadiationMevPerS)} MeV/s
                </span>
              </div>
            </div>
          </div>
          <div className="hdv-velocity">
            <span className="hdv-stat__label">Exhaust Velocity</span>
            <VelocityBar beta={engine.exhaustVelocityBeta} />
          </div>
        </div>

        <div className="hdv-side hdv-side--expansion">
          <h3>Expansion Grid</h3>
          <CoordMatrix
            positionMpc={space.positionMpc}
            distanceMpc={space.distanceToFinalDimensionMpc}
            shift={space.coordinateShift}
          />
          <div className="hdv-stat">
            <span className="hdv-stat__label">Space Recession Velocity</span>
            <span className="hdv-mono hdv-stat__value hdv-stat__value--magenta">
              {fmtNum(space.recessionVelocityKmS, 2)} km/s
            </span>
          </div>
          <div className="hdv-stat">
            <span className="hdv-stat__label">Proper Velocity</span>
            <span className="hdv-mono hdv-stat__value">{fmtNum(space.properVelocityKmS, 2)} km/s</span>
          </div>
          <div className="hdv-stat">
            <span className="hdv-stat__label">Spatial Warping</span>
            <span className="hdv-mono hdv-stat__value">{fmtNum(space.spatialWarpingPct, 1)}%</span>
          </div>
          <div className="hdv-stat">
            <span className="hdv-stat__label">Scale Factor a(t)</span>
            <span className="hdv-mono hdv-stat__value">{fmtNum(space.scaleFactor, 6)}</span>
          </div>
        </div>
      </div>

      {breach && (
        <div className="hdv-alarm" role="alert">
          Penning trap containment breach — magnetic field below {PENNING_CRITICAL}%
        </div>
      )}
    </section>
  );
});
