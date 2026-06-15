import { NextResponse } from "next/server";
import { railConfigured, serverEnv, publicConfig } from "@/lib/config/env";
import { chainCatalog } from "@/lib/web3/chains";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** Public, non-secret config the Payments page uses to render available rails. */
export async function GET() {
  return NextResponse.json({
    ok: true,
    data: {
      rails: {
        stripe: railConfigured("stripe"),
        square: railConfigured("square"),
        wise: railConfigured("wise"),
        web3: true,
      },
      fiatCurrencies: ["USD", "EUR", "GBP", "CAD", "AUD"],
      platformFeeRate: publicConfig.platformFeeRate,
      chains: chainCatalog(),
      treasury: {
        evm: serverEnv.web3.treasury.evm() || null,
        solana: serverEnv.web3.treasury.solana() || null,
        ton: serverEnv.web3.treasury.ton() || null,
      },
      minConfirmations: serverEnv.web3.confirmations(),
    },
  });
}
