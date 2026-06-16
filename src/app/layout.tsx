import type { Metadata } from "next";
import "./globals.css";
import { Providers } from "./providers";
import { TelegramAnalytics } from "@/components/TelegramAnalytics";

export const metadata: Metadata = {
  title: "YieldSwarm Payments",
  description:
    "Deposit and withdraw via Square, Wise, or any connected Web3 wallet (EVM / Solana / TON).",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className="min-h-screen font-sans antialiased">
        <TelegramAnalytics />
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
