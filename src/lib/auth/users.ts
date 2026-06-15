import { store } from "@/lib/db/store";
import { User } from "@/lib/db/models";
import { nowIso } from "@/lib/ids";

/** Ensure a user row exists for the given id (lazy provisioning). Node-only. */
export async function ensureUser(userId: string, email?: string): Promise<User> {
  return store.mutate((db) => {
    const existing = db.users[userId];
    if (existing) return existing;
    const user: User = {
      id: userId,
      email: email ?? `${userId.slice(0, 8)}@anon.yieldswarm.local`,
      createdAt: nowIso(),
    };
    db.users[userId] = user;
    return user;
  });
}
