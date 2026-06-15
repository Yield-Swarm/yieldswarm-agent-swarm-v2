const API = import.meta.env.VITE_API_BASE || "/api/kairo";
const MAPBOX_TOKEN = import.meta.env.VITE_MAPBOX_TOKEN || "";
const FEE_PERCENT = 0.01;
const DRIVER_MULTIPLIER = 2;

function calcFare(miles = 5.2) {
  const base = miles * 2.5;
  const fee = base * FEE_PERCENT;
  const driverGross = base * DRIVER_MULTIPLIER;
  return { base, fee, total: base + fee, driverGross };
}

async function loadContributions() {
  const el = document.getElementById("contributions");
  try {
    const res = await fetch(`${API}/contributions?limit=5`);
    const data = await res.json();
    const rows = data.contributions || [];
    el.innerHTML = rows.length
      ? rows.map((r) => `<div>${r.driver_id}: $${(r.estimated_rewards_usd || 0).toFixed(2)}</div>`).join("")
      : "No trips yet — drive to earn DePIN rewards";
    const depin = rows.reduce((s, r) => s + (r.depin_rewards_usd || 0), 0);
    document.getElementById("depin-rewards").textContent = `DePIN rewards: $${depin.toFixed(2)}`;
  } catch {
    el.textContent = "Connect backend at :8787";
  }
}

function initMap() {
  const mapEl = document.getElementById("map");
  if (!MAPBOX_TOKEN) {
    mapEl.innerHTML = '<div style="padding:2rem;color:#8b95a5">Set VITE_MAPBOX_TOKEN for live map</div>';
    return;
  }
  mapboxgl.accessToken = MAPBOX_TOKEN;
  const map = new mapboxgl.Map({
    container: "map",
    style: "mapbox://styles/mapbox/dark-v11",
    center: [-122.4194, 37.7749],
    zoom: 12,
  });
  new mapboxgl.Marker({ color: "#5b8def" }).setLngLat([-122.4194, 37.7749]).addTo(map);
  return map;
}

function updateFareUI() {
  const { base, fee, total, driverGross } = calcFare();
  document.getElementById("fare-estimate").textContent = `Est. fare: $${total.toFixed(2)}`;
  document.getElementById("fee-breakdown").textContent =
    `Ride $${base.toFixed(2)} + 1% fee $${fee.toFixed(2)} · Driver earns $${driverGross.toFixed(2)}`;
}

document.getElementById("book-btn").addEventListener("click", async () => {
  const btn = document.getElementById("book-btn");
  btn.disabled = true;
  btn.textContent = "Matching driver…";
  setTimeout(() => {
    btn.textContent = "Driver en route";
    btn.disabled = false;
  }, 1500);
});

initMap();
updateFareUI();
loadContributions();
setInterval(loadContributions, 20000);
