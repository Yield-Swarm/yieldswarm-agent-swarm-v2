import { useMemo } from "react";
import { useHelixDeltaStore } from "./helixDeltaStore";

/**
 * Streams coordinate shifts, spatial warping, and expansion velocity
 * from the Helix v5.0 space expansion layer.
 */
export function useSpaceExpansion() {
  const expansion = useHelixDeltaStore((s) => s.expansion);
  const engine = useHelixDeltaStore((s) => s.engine);

  return useMemo(
    () => ({
      coordinateShift: expansion.coordinateShift,
      spatialWarpingPct: expansion.spatialWarpingPct,
      totalExpansionVelocityKmS: expansion.totalExpansionVelocityKmS,
      recessionVelocityKmS: expansion.recessionVelocityKmS,
      properVelocityKmS: expansion.properVelocityKmS,
      scaleFactor: expansion.scaleFactor,
      positionMpc: expansion.positionMpc,
      distanceToFinalDimensionMpc: expansion.distanceToFinalDimensionMpc,
      finalDimensionReached: expansion.finalDimensionReached,
      exhaustVelocityBeta: engine.exhaustVelocityBeta,
      thrustNewtons: engine.thrustNewtons,
    }),
    [expansion, engine],
  );
}
