"use client";

import { useEffect, useRef } from "react";

/**
 * Telegram Mini Apps Analytics (tganalytics.xyz) bootstrap.
 *
 * Initialises the official `@telegram-apps/analytics` SDK on the client so the
 * YieldSwarm Mini App reports engagement to the `yieldswarmprod` project.
 *
 * The token and identifier are read from public env vars (the SDK runs in the
 * browser, so the token is necessarily client-side). Nothing is hardcoded and
 * the call is fully guarded: when the token is unset, or the app is opened
 * outside Telegram, init is skipped/caught so the page never breaks.
 *
 *   NEXT_PUBLIC_TELEGRAM_ANALYTICS_TOKEN     SDK auth token from TON Builders
 *   NEXT_PUBLIC_TELEGRAM_ANALYTICS_APP_NAME  analytics identifier (yieldswarmprod)
 */
export function TelegramAnalytics() {
  const started = useRef(false);

  useEffect(() => {
    if (started.current) return;
    started.current = true;

    const token = process.env.NEXT_PUBLIC_TELEGRAM_ANALYTICS_TOKEN;
    const appName =
      process.env.NEXT_PUBLIC_TELEGRAM_ANALYTICS_APP_NAME || "yieldswarmprod";

    if (!token) {
      // No token configured (e.g. local dev without secrets) — skip silently.
      return;
    }

    let cancelled = false;
    void (async () => {
      try {
        const { default: telegramAnalytics } = await import(
          "@telegram-apps/analytics"
        );
        if (cancelled) return;
        await telegramAnalytics.init({ token, appName });
      } catch (err) {
        // Most common cause: opened outside the Telegram WebApp container.
        // Analytics are non-critical, so never let this surface to the user.
        if (process.env.NODE_ENV !== "production") {
          // eslint-disable-next-line no-console
          console.warn("[TelegramAnalytics] init skipped:", err);
        }
      }
    })();

    return () => {
      cancelled = true;
    };
  }, []);

  return null;
}
