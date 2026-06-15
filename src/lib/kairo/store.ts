/**
 * Kairo data store — same pattern as payments (memory / file drivers).
 */

import { promises as fs } from "node:fs";
import path from "node:path";
import { KairoDB, emptyKairoDB } from "@/lib/kairo/models";

export interface KairoStore {
  read(): Promise<KairoDB>;
  mutate<T>(fn: (db: KairoDB) => T | Promise<T>): Promise<T>;
}

class MemoryKairoStore implements KairoStore {
  private db: KairoDB = emptyKairoDB();
  private lock: Promise<unknown> = Promise.resolve();

  async read(): Promise<KairoDB> {
    return this.db;
  }

  async mutate<T>(fn: (db: KairoDB) => T | Promise<T>): Promise<T> {
    const run = this.lock.then(() => fn(this.db));
    this.lock = run.then(
      () => undefined,
      () => undefined,
    );
    return run;
  }
}

class FileKairoStore implements KairoStore {
  private lock: Promise<unknown> = Promise.resolve();
  private readonly file: string;

  constructor(dir: string) {
    this.file = path.resolve(process.cwd(), dir, "kairo-db.json");
  }

  private async load(): Promise<KairoDB> {
    try {
      const raw = await fs.readFile(this.file, "utf8");
      return { ...emptyKairoDB(), ...(JSON.parse(raw) as KairoDB) };
    } catch {
      return emptyKairoDB();
    }
  }

  private async save(db: KairoDB): Promise<void> {
    await fs.mkdir(path.dirname(this.file), { recursive: true });
    await fs.writeFile(this.file, JSON.stringify(db, null, 2), "utf8");
  }

  async read(): Promise<KairoDB> {
    return this.load();
  }

  async mutate<T>(fn: (db: KairoDB) => T | Promise<T>): Promise<T> {
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

function createKairoStore(): KairoStore {
  const driver = process.env.KAIRO_STORE_DRIVER ?? "memory";
  if (driver === "file") {
    return new FileKairoStore(process.env.KAIRO_STORE_DIR ?? ".data");
  }
  return new MemoryKairoStore();
}

const g = globalThis as unknown as { __kairoStore?: KairoStore };
export const kairoStore: KairoStore = g.__kairoStore ?? (g.__kairoStore = createKairoStore());
