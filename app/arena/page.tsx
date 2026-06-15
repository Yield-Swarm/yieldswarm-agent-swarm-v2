"use client";

import { useEffect, useMemo, useState } from "react";

type WorkerStatus = "unknown" | "online" | "offline";

function parseWorkerUrls(input: string | null): string[] {
  if (!input) {
    return [];
  }
  return input
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);
}

export default function ArenaPage() {
  const [statuses, setStatuses] = useState<Record<string, WorkerStatus>>({});

  const workerUrls = useMemo(() => {
    const fromEnv = parseWorkerUrls(process.env.NEXT_PUBLIC_WORKER_URLS ?? null);
    const fromQuery =
      typeof window === "undefined"
        ? []
        : parseWorkerUrls(new URLSearchParams(window.location.search).get("workers"));
    return Array.from(new Set([...fromEnv, ...fromQuery]));
  }, []);

  useEffect(() => {
    if (workerUrls.length === 0) {
      return;
    }

    let cancelled = false;

    async function probe(url: string): Promise<void> {
      try {
        const response = await fetch(`${url.replace(/\/$/, "")}/health`, {
          method: "GET",
        });
        if (!cancelled) {
          setStatuses((previous) => ({
            ...previous,
            [url]: response.ok ? "online" : "offline",
          }));
        }
      } catch (_error) {
        if (!cancelled) {
          setStatuses((previous) => ({
            ...previous,
            [url]: "offline",
          }));
        }
      }
    }

    workerUrls.forEach((url) => {
      setStatuses((previous) => ({ ...previous, [url]: "unknown" }));
      void probe(url);
    });

    return () => {
      cancelled = true;
    };
  }, [workerUrls]);

  return (
    <main style={{ padding: "2rem", fontFamily: "Inter, Arial, sans-serif" }}>
      <h1>Arena Worker Mesh</h1>
      <p>
        Supply workers with <code>NEXT_PUBLIC_WORKER_URLS</code> (comma-separated) or
        <code>?workers=https://w1,https://w2</code>.
      </p>
      {workerUrls.length === 0 ? (
        <p>No worker URLs configured yet.</p>
      ) : (
        <ul>
          {workerUrls.map((url) => (
            <li key={url}>
              <strong>{url}</strong> - {statuses[url] ?? "unknown"}
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
