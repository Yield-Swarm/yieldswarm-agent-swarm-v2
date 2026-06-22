import { Config } from "@ton/blueprint";

export const config: Config = {
  network: {
    endpoint: process.env.TON_RPC_ENDPOINT || "https://testnet.toncenter.com/api/v2/jsonRPC",
    type: "testnet",
    version: "v2",
    key: process.env.TONCENTER_API_KEY,
  },
};
