/**
 * Storage abstraction for the payments subsystem.
 *
 * Two built-in drivers:
 *   - "memory" (default): process-local, great for dev / serverless demos.
 *   - "file": JSON file under PAYMENTS_STORE_DIR, survives restarts locally.
 *
 * For production, implement the `Store` interface against Neon/Postgres (the
 * README documents the schema) and return it from `createStore`. The rest of
 * the codebase only depends on this interface, never on a concrete driver.
 */

import { promises as fs } from "node:fs";
import path from "node:path";
import { serverEnv } from "@/lib/config/env";
import { DB, emptyDB } from "@/lib/db/models";

export interface Store {
  read(): Promise<DB>;
  /** Atomically mutate the DB. The callback may return a value to surface. */
  mutate<T>(fn: (db: DB) => T | Promise<T>): Promise<T>;
}

class MemoryStore implements Store {
  private db: DB = emptyDB();
  private lock: Promise<unknown> = Promise.resolve();

  async read(): Promise<DB> {
    return this.db;
  }

  async mutate<T>(fn: (db: DB) => T | Promise<T>): Promise<T> {
    const run = this.lock.then(() => fn(this.db));
    // Keep the chain alive even if a mutation rejects.
    this.lock = run.then(
      () => undefined,
      () => undefined,
    );
    return run;
  }
}

class FileStore implements Store {
  private lock: Promise<unknown> = Promise.resolve();
  private readonly file: string;

  constructor(dir: string) {
    this.file = path.resolve(process.cwd(), dir, "payments-db.json");
  }

  private async load(): Promise<DB> {
    try {
      const raw = await fs.readFile(this.file, "utf8");
      return { ...emptyDB(), ...(JSON.parse(raw) as DB) };
    } catch {
      return emptyDB();
    }
  }

  private async save(db: DB): Promise<void> {
    await fs.mkdir(path.dirname(this.file), { recursive: true });
    await fs.writeFile(this.file, JSON.stringify(db, null, 2), "utf8");
  }

  async read(): Promise<DB> {
    return this.load();
  }

  async mutate<T>(fn: (db: DB) => T | Promise<T>): Promise<T> {
    const run = this.lock.then(async () => {
      const db = await this.load();
      const result = await fn(db);
      await this.save(db);
      return result;
    });
    this.lock = run.then(
      () => undefined,
      () => undefined,
    );
    return run;
  }
}

function createStore(): Store {
  const driver = serverEnv.store.driver();
  if (driver === "file") {
    return new FileStore(serverEnv.store.fileDir());
  }
  return new MemoryStore();
}

// Survive Next.js dev hot-reloads by stashing the singleton on globalThis.
const g = globalThis as unknown as { __ysStore?: Store };
export const store: Store = g.__ysStore ?? (g.__ysStore = createStore());
