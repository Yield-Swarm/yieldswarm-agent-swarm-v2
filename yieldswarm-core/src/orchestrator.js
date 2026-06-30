#!/usr/bin/env node
/**
 * Trident Protocol — master WebSocket telemetry streaming server.
 * Binds 127.0.0.1:8095, broadcasts TELEMETRY_UPDATE every 2000ms.
 */
import { WebSocketServer } from "ws";
import { readFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { buildSystemState } from "./lib/trident-state.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, "..");
const HOST = process.env.TRIDENT_WS_HOST || "127.0.0.1";
const PORT = Number(process.env.TRIDENT_WS_PORT || 8095);
const INTERVAL_MS = Number(process.env.TRIDENT_TELEMETRY_MS || 2000);

function loadVlanProfile() {
  const path = join(ROOT, "config/network/vlan-trident.json");
  if (!existsSync(path)) {
    console.warn(`[orchestrator] WARN: missing ${path}`);
    return null;
  }
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch (err) {
    console.error(`[orchestrator] ERROR parsing vlan profile: ${err.message}`);
    return null;
  }
}

function enrichState(base) {
  const vlan = loadVlanProfile();
  return {
    ...base,
    vlanTrident: vlan,
    systemState: base,
  };
}

const wss = new WebSocketServer({ host: HOST, port: PORT });
const clients = new Set();

wss.on("connection", (ws, req) => {
  clients.add(ws);
  const addr = req.socket.remoteAddress;
  console.log(`[orchestrator] client connected (${addr}) — ${clients.size} total`);

  const snapshot = enrichState(buildSystemState());
  ws.send(
    JSON.stringify({
      type: "TELEMETRY_UPDATE",
      timestamp: new Date().toISOString(),
      payload: snapshot,
    })
  );

  ws.on("close", () => {
    clients.delete(ws);
    console.log(`[orchestrator] client disconnected — ${clients.size} remaining`);
  });

  ws.on("error", (err) => {
    console.error(`[orchestrator] ws error: ${err.message}`);
    clients.delete(ws);
  });
});

function broadcastTelemetry() {
  const payload = enrichState(buildSystemState());
  const frame = JSON.stringify({
    type: "TELEMETRY_UPDATE",
    timestamp: new Date().toISOString(),
    payload,
  });

  for (const ws of clients) {
    if (ws.readyState === ws.OPEN) {
      ws.send(frame);
    }
  }
}

wss.on("listening", () => {
  console.log(`[orchestrator] Trident WebSocket listening on ws://${HOST}:${PORT}`);
  console.log(`[orchestrator] telemetry interval ${INTERVAL_MS}ms`);
  setInterval(broadcastTelemetry, INTERVAL_MS);
});

wss.on("error", (err) => {
  console.error(`[orchestrator] FATAL: ${err.message}`);
  process.exit(1);
});

process.on("SIGINT", () => {
  console.log("[orchestrator] shutting down...");
  for (const ws of clients) ws.close();
  wss.close(() => process.exit(0));
});

process.on("SIGTERM", () => process.emit("SIGINT"));
