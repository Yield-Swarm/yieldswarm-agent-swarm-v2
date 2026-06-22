import { createHash } from "crypto";
import { z } from "zod";

/** TON user-friendly address (EQ/UQ + 46 base64url chars). */
export const TON_ADDRESS_REGEX = /^(EQ|UQ)[a-zA-Z0-9_-]{46}$/;

/**
 * Hash equipment loadout for on-chain PlayerSBT storage.
 * Accepts either a 64-char SHA-256 hex (passthrough) or a raw comma-separated loadout.
 */
export function hashEquipment(loadout: string): string {
  const trimmed = loadout.trim();
  if (/^[a-f0-9]{64}$/i.test(trimmed)) return trimmed.toLowerCase();
  return createHash("sha256").update(trimmed).digest("hex");
}

export const PlayerProfileSchema = z.object({
  walletAddress: z.string().regex(TON_ADDRESS_REGEX, "Invalid TON address format"),
  level: z.number().int().min(1).max(100),
  experience: z.number().int().nonnegative(),
  equipmentHash: z
    .string()
    .min(1)
    .transform((val) => hashEquipment(val))
    .pipe(z.string().regex(/^[a-f0-9]{64}$/, "equipmentHash must be SHA-256 hex")),
  lastSaveTimestamp: z.number().int().positive(),
});

export type PlayerProfile = z.infer<typeof PlayerProfileSchema>;

export const ProofOfEngagementActionSchema = z.object({
  baseFactor: z.number().positive(),
  enemyLevel: z.number().int().positive(),
  precision: z.number().positive(),
  deltaTime: z.number().int().nonnegative(),
  actionType: z.enum(["combat", "crafting", "exploration", "social"]),
});

export type ProofOfEngagementAction = z.infer<typeof ProofOfEngagementActionSchema>;

export const ClaimPayloadSchema = z.object({
  player: PlayerProfileSchema,
  action: ProofOfEngagementActionSchema,
});

export type ClaimPayload = z.infer<typeof ClaimPayloadSchema>;
