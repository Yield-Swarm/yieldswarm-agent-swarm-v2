export interface PublicConfig {
  rails: { square: boolean; wise: boolean; web3: boolean };
  fiatCurrencies: string[];
  chains: {
    evm: { id: number; name: string; shortName: string; nativeSymbol: string; assets: string[] }[];
    solana: { name: string; assets: string[] };
    ton: { name: string; assets: string[] };
    evmAssetMeta: Record<string, { decimals: number; native: boolean; erc20?: string }>;
  };
  treasury: { evm: string | null; solana: string | null; ton: string | null };
  minConfirmations: number;
}

export interface Transaction {
  id: string;
  direction: "deposit" | "withdrawal";
  rail: "square" | "wise" | "web3";
  status: string;
  amount: string;
  currency: string;
  chain?: string;
  externalId?: string;
  reference: string;
  createdAt: string;
  metadata?: Record<string, unknown>;
}

export interface LinkedWallet {
  id: string;
  chain: "evm" | "solana" | "ton";
  address: string;
  label?: string;
  verifiedAt: string;
}

export interface BalanceResponse {
  user: { id: string; email: string };
  balances: Record<string, string>;
  transactions: Transaction[];
  wallets: LinkedWallet[];
}

export type ChainKind = "evm" | "solana" | "ton";
