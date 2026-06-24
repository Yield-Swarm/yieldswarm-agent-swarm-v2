import { NextResponse } from 'next/server';
import { CoinbaseSwarmManager } from '@/lib/coinbase/CoinbaseSwarmManager';

export const dynamic = 'force-dynamic';

export async function GET() {
  const manager = new CoinbaseSwarmManager();
  const data = await manager.fetchPortfolioMetrics();
  return NextResponse.json({
    status: 'Active',
    ecosystem: 'Open Claws Cluster Arena v4.0',
    tridentVersion: process.env.TRIDENT_VERSION ?? '3.05911111100',
    networksConfigured: [
      { name: 'Monero', token: 'XMR', layer: 'RandomX CPU' },
      { name: 'Kaspa', token: 'KAS', layer: 'kHeavyHash' },
      { name: 'Litecoin/Dogecoin', token: 'LTC_DOGE', layer: 'AuxPoW Merged' },
      { name: 'Zephyr', token: 'ZEPH', layer: 'RandomX CPU' },
      { name: 'Pyrin', token: 'PYI', layer: 'Pyrinhash GPU' },
    ],
    vaults: [
      'SOL', 'ETH', 'TON', 'HYPE', 'FLUX', 'mSOL', 'cbETH', 'cbSOL',
      'USDC', 'USDT', 'USD1', 'ZEC', 'TAO',
    ],
    domains: {
      frontend: ['defiswarmagents.com', 'yieldswarmofficial.pw', 'yieldswarmtreasury.pw', 'yslrcodex.com'],
      backend: ['helixpow.pw', 'defiswarmagents.info', 'starthelixchain.xyz'],
      blockchain: ['genushelix.blockchain', 'yieldswarmtreasury.blockchain', 'helixpow.blockchain'],
    },
    infrastructureBridges: {
      depinProviders: ['Akash', 'RunPod', 'Vast.io', 'Cherry Servers'],
      enterpriseClouds: ['Azure', 'Google Cloud'],
    },
    coinbase: data,
  });
}
