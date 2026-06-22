const { z } = require('zod');

const TelemetrySchema = z.object({
  email: z.string().email(),
  plan: z.string().default('Lite'),
  currentBalance: z.number().nonnegative().default(1000.0),
  geomines: z.number().int().nonnegative().default(0),
  geodrops: z.number().int().nonnegative().default(0),
  surveys: z.number().int().nonnegative().default(0),
  spentGeoclaims: z.number().nonnegative().default(0.0),
  spentGeodrops: z.number().nonnegative().default(0.0),
  spentSweepstakes: z.number().nonnegative().default(0.0),
});

module.exports = { TelemetrySchema };
