/**
 * Emission router telemetry.
 *
 * The emission router is the on-chain component that mints/distributes $APN
 * rewards to stakers, workers and the treasury each epoch. We derive live
 * signals from the $APN mint supply on Solana; when on-chain reads are
 * unavailable we fall back to a deterministic projection flagged as such.
 */

import config from '../config.js';
import { getTokenSupply, getSolBalance } from './solana.js';

const EPOCH_SECONDS = 60 * 60; // hourly emission epoch
const TARGET_ANNUAL_INFLATION = 0.08; // 8% annual emission target

export async function getEmissions() {
  const supply = await getTokenSupply(config.solana.apnMint);
  const router = config.solana.emissionRouter
    ? await getSolBalance(config.solana.emissionRouter)
    : { live: false, sol: 0, error: 'no EMISSION_ROUTER_ADDRESS configured' };

  const live = supply.live;
  const circulating = live ? supply.uiAmount : 1_000_000_000;
  const decimals = live ? supply.decimals : 9;

  // Emission per epoch derived from annual inflation target.
  const epochsPerYear = (365 * 24 * 3600) / EPOCH_SECONDS;
  const emissionPerEpoch = (circulating * TARGET_ANNUAL_INFLATION) / epochsPerYear;

  return {
    source: live ? 'solana-rpc' : 'fallback',
    live,
    mint: config.solana.apnMint,
    routerAddress: config.solana.emissionRouter || null,
    routerBalanceSol: router.sol ?? 0,
    routerConnected: router.live,
    circulatingSupply: Number(circulating.toFixed(decimals > 6 ? 6 : decimals)),
    decimals,
    epochSeconds: EPOCH_SECONDS,
    targetAnnualInflation: TARGET_ANNUAL_INFLATION,
    emissionPerEpoch: Number(emissionPerEpoch.toFixed(4)),
    emissionPerDay: Number((emissionPerEpoch * (24 * 3600 / EPOCH_SECONDS)).toFixed(4)),
    // Great Delta 50/30/15/5 emission routing (matches on-chain router)
    routes: [
      { destination: 'coreTreasury', share: 0.5, bps: 5000, perEpoch: Number((emissionPerEpoch * 0.5).toFixed(4)) },
      { destination: 'growthTreasury', share: 0.3, bps: 3000, perEpoch: Number((emissionPerEpoch * 0.3).toFixed(4)) },
      { destination: 'insuranceTreasury', share: 0.15, bps: 1500, perEpoch: Number((emissionPerEpoch * 0.15).toFixed(4)) },
      { destination: 'opsTreasury', share: 0.05, bps: 500, perEpoch: Number((emissionPerEpoch * 0.05).toFixed(4)) },
    ],
    error: live ? null : supply.error,
  };
}
