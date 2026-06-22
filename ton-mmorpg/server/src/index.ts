import express from "express";
import { createSyncRouter } from "./routes/sync.js";

const app = express();
const port = Number(process.env.PORT || 3100);

app.use(express.json({ limit: "16kb" }));
app.use("/api", createSyncRouter());

app.get("/healthz", (_req, res) => {
  res.json({ status: "ACTIVE", game: "ton-mmorpg" });
});

app.listen(port, () => {
  console.log(`TON MMORPG server listening on :${port}`);
});
