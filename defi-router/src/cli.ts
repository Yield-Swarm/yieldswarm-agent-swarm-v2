#!/usr/bin/env node
/** CLI: npm run simulate (after npm run build) */

import { runDeFiRouter } from "./index.js";

const result = await runDeFiRouter();
const { report } = result;
const best = report.bestRoute;

console.log("YieldSwarm DeFiRouter — Execution Report");
console.log("=".repeat(44));
console.log(`Portfolio Value:     $${report.portfolioUsd.toFixed(2)}`);
console.log(`Best Strategy:       ${best.strategyName}`);
console.log(`Projected Fees:      $${best.totalFeesUsd.toFixed(2)} (${best.feePct.toFixed(1)}%)`);
console.log(`Net Retained:        ${best.retentionPct.toFixed(1)}% ($${best.netOutputUsd.toFixed(2)})`);
console.log(`Circuit Breaker:     ${report.circuitBreaker.triggered ? "TRIGGERED" : "OK"}`);
console.log(`Status:              ${result.status}`);
console.log(`Recommendation:      ${result.message}`);

process.exit(result.status === "HALTED" ? 1 : 0);
