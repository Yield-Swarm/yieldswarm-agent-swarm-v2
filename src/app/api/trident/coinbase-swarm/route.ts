import { NextResponse } from 'next/server';
import { CoinbaseSwarmManager } from '@/lib/coinbase/CoinbaseSwarmManager';

export const dynamic = 'force-dynamic';

export async function GET() {
  try {
    const manager = new CoinbaseSwarmManager();
    return NextResponse.json(await manager.fetchPortfolioMetrics());
  } catch (err) {
    return NextResponse.json(
      { error: 'Coinbase swarm metrics failed', details: String(err) },
      { status: 500 },
    );
  }
}

export async function POST(req: Request) {
  try {
    const manager = new CoinbaseSwarmManager();
    const body = await req.json();
    const { amount, fromToken, toToken } = manager.parseTradeBody(body);
    const result = await manager.executeAutomatedSwarmTrade(amount, fromToken, toToken);
    return NextResponse.json(result);
  } catch (err) {
    return NextResponse.json(
      { error: 'Trade routing failed', details: String(err) },
      { status: 400 },
    );
  }
}
