import express from "express";
import { z } from "zod";
import { runSyncLoop } from "./sync/sync-loop.js";

const SyncBody = z.object({
  wallet: z.string().min(10),
  activityScore: z.number().min(0).max(100).default(50),
  sessionId: z.string().optional(),
});

export function createSyncRouter(): express.Router {
  const router = express.Router();

  router.post("/sync", async (req, res) => {
    try {
      const body = SyncBody.parse(req.body);
      const secret = process.env.SYNC_API_SECRET;
      if (secret) {
        const auth = req.get("authorization")?.replace(/^Bearer\s+/i, "");
        if (auth !== secret) {
          return res.status(401).json({ ok: false, error: "unauthorized" });
        }
      }
      const result = await runSyncLoop(body);
      return res.json(result);
    } catch (e) {
      const err = e as Error & { statusCode?: number };
      if (err instanceof z.ZodError) {
        return res.status(400).json({ ok: false, error: "validation", issues: err.errors });
      }
      if (err.statusCode === 429) {
        return res.status(429).json({ ok: false, error: err.message });
      }
      console.error("[sync]", err);
      return res.status(500).json({ ok: false, error: err.message || "sync failed" });
    }
  });

  router.get("/health", (_req, res) => {
    res.json({
      ok: true,
      service: "ton-mmorpg-server",
      shadowChain: "server-authoritative",
    });
  });

  return router;
}
