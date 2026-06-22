export interface RetryOptions {
  maxAttempts?: number;
  baseDelayMs?: number;
  maxDelayMs?: number;
  /** Extra delay when response status is 429 */
  rateLimitDelayMs?: number;
}

const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

function isRetryableStatus(status?: number): boolean {
  if (!status) return true;
  return status === 429 || status >= 500;
}

export async function withRetry<T>(
  label: string,
  fn: () => Promise<T>,
  opts: RetryOptions = {},
): Promise<T> {
  const maxAttempts = opts.maxAttempts ?? 3;
  const baseDelayMs = opts.baseDelayMs ?? 400;
  const maxDelayMs = opts.maxDelayMs ?? 8_000;
  const rateLimitDelayMs = opts.rateLimitDelayMs ?? 2_000;

  let lastError: unknown;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastError = err;
      const status =
        err && typeof err === "object" && "status" in err
          ? Number((err as { status: number }).status)
          : undefined;
      if (attempt >= maxAttempts || !isRetryableStatus(status)) break;

      const backoff = Math.min(baseDelayMs * 2 ** (attempt - 1), maxDelayMs);
      const delay = status === 429 ? Math.max(backoff, rateLimitDelayMs) : backoff;
      await sleep(delay);
    }
  }
  const msg = lastError instanceof Error ? lastError.message : String(lastError);
  throw new Error(`${label} failed after ${maxAttempts} attempts: ${msg}`);
}
