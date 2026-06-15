import { NextRequest, NextResponse } from "next/server";
import {
  SESSION_COOKIE,
  USER_HEADER,
  newSessionToken,
  verifySession,
} from "@/lib/auth/session";

/**
 * Ensures every (non-webhook) request carries a valid anonymous session.
 * The resolved user id is forwarded to route handlers via a request header so
 * the very first request already has an identity, and the signed cookie is
 * (re)issued on the response.
 */
export async function middleware(request: NextRequest) {
  const existing = request.cookies.get(SESSION_COOKIE)?.value;
  let userId = await verifySession(existing);
  let token: string | null = null;

  if (!userId) {
    const created = await newSessionToken();
    userId = created.userId;
    token = created.token;
  }

  const requestHeaders = new Headers(request.headers);
  requestHeaders.set(USER_HEADER, userId);

  const response = NextResponse.next({ request: { headers: requestHeaders } });

  if (token) {
    response.cookies.set(SESSION_COOKIE, token, {
      httpOnly: true,
      sameSite: "lax",
      secure: process.env.NODE_ENV === "production",
      path: "/",
      maxAge: 60 * 60 * 24 * 365,
    });
  }

  return response;
}

export const config = {
  // Run on pages and app APIs, but never on webhooks (external callers have no
  // session) or static assets.
  matcher: ["/((?!api/webhooks|_next/static|_next/image|favicon.ico|tonconnect-manifest.json).*)"],
};
