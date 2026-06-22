import { z } from "zod";

/** Authoritative on-chain / indexed player profile (TON SBT layout). */
export const PlayerProfileSchema = z.object({
  walletAddress: z
    .string()
    .regex(/^(EQ|UQ)[a-zA-Z0-9_-]{46}$/, "Invalid TON address format"),
  level: z.number().int().min(1).max(100),
  experience: z.number().int().nonnegative(),
  equipmentHash: z
    .string()
    .length(64)
    .regex(/^[a-f0-9]{64}$/i, "equipmentHash must be 64-char hex"),
  lastSaveTimestamp: z.number().int().positive(),
});

export type PlayerProfile = z.infer<typeof PlayerProfileSchema>;

export const PoEActionTypeSchema = z.enum([
  "combat",
  "crafting",
  "exploration",
  "social",
]);

export type PoEActionType = z.infer<typeof PoEActionTypeSchema>;

export const PoEActionInputSchema = z.object({
  baseFactor: z.number().positive().max(10_000),
  metrics: z.array(z.number().finite().nonnegative()).min(1).max(16),
  weights: z.array(z.number().finite().nonnegative()).min(1).max(16),
  actionType: PoEActionTypeSchema,
  deltaTime: z.number().int().nonnegative().optional(),
});

export type PoEActionInput = z.infer<typeof PoEActionInputSchema>;

export const ClaimRequestSchema = z.object({
  walletAddress: z
    .string()
    .regex(/^(EQ|UQ)[a-zA-Z0-9_-]{46}$/, "Invalid TON address format"),
  action: PoEActionInputSchema.omit({ deltaTime: true }),
  nonce: z.number().int().positive(),
});

export type ClaimRequest = z.infer<typeof ClaimRequestSchema>;
