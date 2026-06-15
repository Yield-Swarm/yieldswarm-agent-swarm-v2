import { getCurrentSession } from "../shared/auth.js";
import { resolveConfig } from "../shared/config.js";
import { loadUnifiedTelemetry } from "../shared/telemetry.js";

const root = document.querySelector("[data-arena-dashboard]");
const statusNode = document.querySelector("[data-arena-status]");
const refreshedNode = document.querySelector("[data-arena-refreshed]");
const config = resolveConfig();

function formatNumber(value) {
  return new Intl.NumberFormat("en-US", {
    maximumFractionDigits: value >= 100 ? 0 : 2
  }).format(Number(value) || 0);
}

function formatCurrency(value) {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 0
  }).format(Number(value) || 0);
}

function metricCard(label, value, hint) {
  return `
    <article class="metric-card">
      <span>${label}</span>
      <strong>${value}</strong>
      <small>${hint}</small>
    </article>
  `;
}

function laneCard(lane) {
  return `
    <article class="lane-card lane-${lane.status}">
      <header>
        <h3>${lane.name}</h3>
        <span>${lane.status}</span>
      </header>
      <strong>${lane.primaryMetric}</strong>
      <small>${lane.secondaryMetric}</small>
    </article>
  `;
}

function alertRow(alert) {
  return `<li><strong>${alert.source}</strong>: ${alert.message}</li>`;
}

function renderDashboard(model) {
  root.innerHTML = `
    <section class="metrics-grid">
      ${metricCard("Active systems", formatNumber(model.totals.activeSystems), "Akash workers + Odysseus agents")}
      ${metricCard("Akash workers", formatNumber(model.totals.akashWorkers), `${formatNumber(model.totals.gpuCount)} GPUs allocated`)}
      ${metricCard("Odysseus agents", formatNumber(model.totals.odysseusAgents), `${formatNumber(model.totals.activeResearchRuns)} active research runs`)}
      ${metricCard("Memory items", formatNumber(model.totals.memoryItems), `${formatNumber(model.totals.vectorCount)} vectors indexed`)}
      ${metricCard("Queue depth", formatNumber(model.totals.queueDepth), "Odysseus research + memory backlog")}
      ${metricCard("Akash spend", formatCurrency(model.totals.monthlyCostUsd), "Projected monthly worker cost")}
    </section>

    <section class="lanes-grid">
      ${model.lanes.map(laneCard).join("")}
    </section>

    <section class="alert-panel">
      <h2>Unified telemetry alerts</h2>
      ${
        model.alerts.length
          ? `<ul>${model.alerts.map(alertRow).join("")}</ul>`
          : "<p>No telemetry alerts from Akash or Odysseus.</p>"
      }
    </section>
  `;

  statusNode.textContent = model.health;
  statusNode.dataset.health = model.health;
  refreshedNode.textContent = `Updated ${new Date(model.updatedAt).toLocaleTimeString()}`;
}

async function refreshTelemetry() {
  root.setAttribute("aria-busy", "true");

  try {
    const session = await getCurrentSession({ config });
    const model = await loadUnifiedTelemetry({ config, session });
    renderDashboard(model);
  } catch (error) {
    statusNode.textContent = "critical";
    statusNode.dataset.health = "critical";
    root.innerHTML = `
      <section class="alert-panel">
        <h2>Telemetry load failed</h2>
        <p>${error.message}</p>
      </section>
    `;
  } finally {
    root.setAttribute("aria-busy", "false");
  }
}

document.querySelector("[data-refresh-telemetry]")?.addEventListener("click", refreshTelemetry);
refreshTelemetry();
setInterval(refreshTelemetry, config.telemetryRefreshMs);
