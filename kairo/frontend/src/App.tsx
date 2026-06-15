import { useCallback, useEffect, useMemo, useState } from "react";
import MapView from "./components/MapView";
import { apiBase, createDriverIdentity, fetchContribution, submitTelemetry } from "./lib/api";

const CUSTOMER_FEE_PCT = 0.01;
const DRIVER_MULTIPLIER = 2.0;

function calcFare(distanceKm: number, durationMin: number) {
  const base = distanceKm * 1.5 + durationMin * 0.25 + 2.5;
  const fee = base * CUSTOMER_FEE_PCT;
  return {
    base: +base.toFixed(2),
    fee: +fee.toFixed(2),
    total: +(base + fee).toFixed(2),
    driverPay: +(base * DRIVER_MULTIPLIER).toFixed(2),
    depinEstimate: +((distanceKm * 0.01 + durationMin * 0.005) * 0.02).toFixed(4),
  };
}

export default function App() {
  const [driverId, setDriverId] = useState<string>("");
  const [identity, setIdentity] = useState<Record<string, unknown> | null>(null);
  const [contribution, setContribution] = useState<Record<string, unknown> | null>(null);
  const [mode, setMode] = useState<"ride" | "delivery">("ride");
  const [position, setPosition] = useState({ lat: 37.7749, lng: -122.4194 });
  const [distanceKm, setDistanceKm] = useState(5.2);
  const [durationMin, setDurationMin] = useState(18);
  const [status, setStatus] = useState("");

  const fare = useMemo(() => calcFare(distanceKm, durationMin), [distanceKm, durationMin]);

  const refreshContribution = useCallback(async (id: string) => {
    try {
      const data = await fetchContribution(id);
      setContribution(data);
    } catch {
      /* ignore */
    }
  }, []);

  useEffect(() => {
    if (driverId) refreshContribution(driverId);
  }, [driverId, refreshContribution]);

  async function handleRegister() {
    setStatus("Creating cryptographic identity…");
    try {
      const data = await createDriverIdentity();
      setDriverId(data.driverId as string);
      setIdentity(data);
      setStatus(`Registered — EVM ${String(data.evmAddress).slice(0, 10)}…`);
    } catch (e) {
      setStatus(`Error: ${(e as Error).message}`);
    }
  }

  async function handleTripComplete() {
    if (!driverId) return;
    setStatus("Signing & submitting telemetry…");
    try {
      await submitTelemetry({
        driverId,
        lat: position.lat,
        lng: position.lng,
        speedKmh: 35,
        distanceKm,
        durationMin,
        tripId: `trip-${Date.now()}`,
        dataQuality: 1.0,
      });
      await refreshContribution(driverId);
      setStatus("Trip telemetry signed and routed to Mandelbrot shard ✓");
    } catch (e) {
      setStatus(`Telemetry error: ${(e as Error).message}`);
    }
  }

  return (
    <>
      <header>
        <div>
          <h1>Kairo</h1>
          <span>Driver-first rides & delivery · 1% customer fee · 2× driver pay</span>
        </div>
        <span className="badge">YieldSwarm DePIN Node</span>
      </header>
      <main>
        <div className="map-panel">
          <MapView lat={position.lat} lng={position.lng} onMove={setPosition} />
        </div>
        <aside className="side-panel">
          <div className="card">
            <h2>Driver Identity</h2>
            {!identity ? (
              <button onClick={handleRegister}>Register as DePIN Node</button>
            ) : (
              <>
                <div className="row"><span>Driver ID</span><span>{driverId}</span></div>
                <div className="row"><span>EVM</span><span style={{ fontSize: "0.75rem" }}>{String(identity.evmAddress)}</span></div>
                <div className="row"><span>IoTeX</span><span style={{ fontSize: "0.75rem" }}>{String(identity.iotexAddress)}</span></div>
                <div className="row"><span>Shard</span><span>{String(identity.mandelbrotShard)}</span></div>
              </>
            )}
          </div>

          <div className="card">
            <h2>Trip</h2>
            <select value={mode} onChange={(e) => setMode(e.target.value as "ride" | "delivery")}>
              <option value="ride">Ride</option>
              <option value="delivery">Delivery</option>
            </select>
            <label>Distance (km)</label>
            <input type="number" value={distanceKm} step={0.1} min={0}
              onChange={(e) => setDistanceKm(Number(e.target.value))} />
            <label>Duration (min)</label>
            <input type="number" value={durationMin} step={1} min={0}
              onChange={(e) => setDurationMin(Number(e.target.value))} />
          </div>

          <div className="card">
            <h2>Customer — 1% flat fee</h2>
            <div className="row"><span>Base fare</span><span>${fare.base}</span></div>
            <div className="row fee"><span>Platform fee (1%)</span><span>${fare.fee}</span></div>
            <div className="row total"><span>Customer pays</span><span>${fare.total}</span></div>
          </div>

          <div className="card">
            <h2>Driver — 2× pay + DePIN</h2>
            <div className="row driver-pay"><span>App earnings (2×)</span><span>${fare.driverPay}</span></div>
            <div className="row"><span>DePIN reward est.</span><span>${fare.depinEstimate}</span></div>
            <div className="row"><span>Instant cashout</span><span>Available</span></div>
            {contribution && (
              <>
                <div className="row"><span>Total contribution</span>
                  <span>{String(contribution.totalContributionScore ?? 0)}</span></div>
                <div className="row"><span>Est. DePIN USD</span>
                  <span>${String(contribution.estimatedRewardUsd ?? 0)}</span></div>
              </>
            )}
          </div>

          <button disabled={!driverId} onClick={handleTripComplete}>
            Complete {mode} &amp; submit signed telemetry
          </button>
          {status && <p style={{ color: "var(--muted)", fontSize: "0.85rem", marginTop: 12 }}>{status}</p>}
          <p style={{ color: "var(--muted)", fontSize: "0.75rem", marginTop: 8 }}>API: {apiBase()}</p>
        </aside>
      </main>
    </>
  );
}
