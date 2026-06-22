/** Shared env helpers for game module (avoids circular imports with serverEnv). */
export function str(name: string, fallback = ""): string {
  return process.env[name]?.trim() || fallback;
}

export function bool(name: string, fallback = false): boolean {
  const v = process.env[name]?.trim().toLowerCase();
  if (v === undefined || v === "") return fallback;
  return v === "1" || v === "true" || v === "yes" || v === "on";
}
