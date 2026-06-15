import { describe, it, expect } from "vitest";
import {
  createTransaction,
  getBalance,
  reserveWithdrawal,
  refundWithdrawal,
  completeWithdrawal,
} from "@/lib/ledger";

const user = () => `u_${Math.random().toString(36).slice(2)}`;

describe("ledger", () => {
  it("credits balance only when a deposit completes", async () => {
    const u = user();
    await createTransaction({
      userId: u,
      direction: "deposit",
      rail: "web3",
      amount: "5",
      currency: "ETH",
      status: "pending",
    });
    expect(await getBalance(u, "ETH")).toBe("0");

    const tx = await createTransaction({
      userId: u,
      direction: "deposit",
      rail: "web3",
      amount: "2.5",
      currency: "ETH",
      status: "completed",
    });
    expect(tx.status).toBe("completed");
    expect(await getBalance(u, "ETH")).toBe("2.5");
  });

  it("reserves and refunds withdrawals atomically", async () => {
    const u = user();
    await createTransaction({
      userId: u,
      direction: "deposit",
      rail: "square",
      amount: "100",
      currency: "USD",
      status: "completed",
    });

    const reserved = await reserveWithdrawal({
      userId: u,
      rail: "wise",
      amount: "30",
      currency: "USD",
    });
    expect("tx" in reserved).toBe(true);
    expect(await getBalance(u, "USD")).toBe("70");

    if ("tx" in reserved) {
      await refundWithdrawal(reserved.tx.id, "test failure");
    }
    expect(await getBalance(u, "USD")).toBe("100");
  });

  it("rejects withdrawals over balance", async () => {
    const u = user();
    const res = await reserveWithdrawal({
      userId: u,
      rail: "web3",
      amount: "1",
      currency: "SOL",
    });
    expect("error" in res).toBe(true);
  });

  it("keeps balance debited when a withdrawal completes", async () => {
    const u = user();
    await createTransaction({
      userId: u,
      direction: "deposit",
      rail: "square",
      amount: "10",
      currency: "USD",
      status: "completed",
    });
    const reserved = await reserveWithdrawal({
      userId: u,
      rail: "wise",
      amount: "4",
      currency: "USD",
    });
    if ("tx" in reserved) {
      await completeWithdrawal(reserved.tx.id, { externalId: "wise-1" });
    }
    expect(await getBalance(u, "USD")).toBe("6");
  });
});
