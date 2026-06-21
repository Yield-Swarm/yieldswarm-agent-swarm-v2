import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(import.meta.url);
const { SovereignLoopManager } = require(
  path.join(__dirname, "..", "..", "src", "infrastructure", "SovereignLoopManager.js"),
);

describe("SovereignLoopsPanel engine import", () => {
  it("exposes manual action snapshot", () => {
    const mgr = new SovereignLoopManager();
    const snap = mgr.forceReplicate();
    assert.equal(snap.currentState, "Deploying Replica");
    assert.ok(snap.logs.length > 0);
  });
});
