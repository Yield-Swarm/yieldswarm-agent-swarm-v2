/** DeFiRouter agent — TypeScript entrypoint */

import { evaluateCircuitBreaker, proposeSafeBatch } from "./security.js";
import { bestRoute, optimizeRoutes } from "./router.js";
import { DEFAULT_PORTFOLIO, portfolioTotalUsd, type Portfolio, type SimulationReport } from "./types.js";

export interface AgentResult {
  schemaVersion: string;
  status: "HALTED" | "DRY_RUN" | "EXECUTE";
  report: SimulationReport;
  message: string;
}

export async function runDeFiRouter(
  portfolio: Portfolio = DEFAULT_PORTFOLIO,
  options: { dryRun?: boolean; execute?: boolean } = {},
): Promise<AgentResult> {
  const dryRun = options.dryRun ?? process.env.DEFI_ROUTER_DRY_RUN !== "0";
  const total = portfolioTotalUsd(portfolio);
  const routes = optimizeRoutes(portfolio);
  const best = routes[0];
  const cb = evaluateCircuitBreaker(best, total);

  const report: SimulationReport = {
    portfolioUsd: total,
    bestRoute: best,
    allRoutes: routes,
    circuitBreaker: cb,
    execute: !cb.triggered && !dryRun && (options.execute ?? false),
  };

  if (cb.triggered) {
    return {
      schemaVersion: "defi-router/v1",
      status: "HALTED",
      report,
      message: cb.recommendation,
    };
  }

  if (dryRun) {
    return {
      schemaVersion: "defi-router/v1",
      status: "DRY_RUN",
      report,
      message: "Simulation complete — set DEFI_ROUTER_DRY_RUN=0 + multi-sig to execute",
    };
  }

  await proposeSafeBatch(best);
  return {
    schemaVersion: "defi-router/v1",
    status: "EXECUTE",
    report,
    message: "Route approved — awaiting Gnosis Safe signatures",
  };
}

export { bestRoute, optimizeRoutes, evaluateCircuitBreaker, DEFAULT_PORTFOLIO };
