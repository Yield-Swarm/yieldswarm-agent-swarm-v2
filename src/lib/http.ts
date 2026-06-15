import { NextResponse } from "next/server";
import { headers, cookies } from "next/headers";
import { ZodError, ZodType, z } from "zod";
import { SESSION_COOKIE, USER_HEADER, verifySession } from "@/lib/auth/session";
import { ensureUser } from "@/lib/auth/users";
import { User } from "@/lib/db/models";

export function ok<T>(data: T, init?: ResponseInit) {
  return NextResponse.json({ ok: true, data }, init);
}

export function fail(message: string, status = 400, extra?: Record<string, unknown>) {
  return NextResponse.json({ ok: false, error: message, ...extra }, { status });
}

/** Resolve the current user from the middleware header or the signed cookie. */
export async function getCurrentUser(): Promise<User | null> {
  const hdrs = headers();
  const fromHeader = hdrs.get(USER_HEADER);
  if (fromHeader) return ensureUser(fromHeader);

  const token = cookies().get(SESSION_COOKIE)?.value;
  const userId = await verifySession(token);
  if (!userId) return null;
  return ensureUser(userId);
}

export async function requireUser(): Promise<
  { user: User } | { response: NextResponse }
> {
  const user = await getCurrentUser();
  if (!user) return { response: fail("Authentication required", 401) };
  return { user };
}

export async function parseBody<S extends ZodType>(
  request: Request,
  schema: S,
): Promise<{ data: z.infer<S> } | { response: NextResponse }> {
  let json: unknown;
  try {
    json = await request.json();
  } catch {
    return { response: fail("Invalid JSON body", 400) };
  }
  const result = schema.safeParse(json);
  if (!result.success) {
    return {
      response: fail("Validation failed", 422, {
        issues: (result.error as ZodError).issues.map((i) => ({
          path: i.path.join("."),
          message: i.message,
        })),
      }),
    };
  }
  return { data: result.data };
}
