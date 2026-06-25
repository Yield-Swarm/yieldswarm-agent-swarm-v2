// Hello-world end-to-end check for the Payments app:
// anonymous session -> nonce challenge -> EVM signature -> wallet link -> list.
import { Wallet } from "ethers";

const BASE = process.env.BASE_URL ?? "http://localhost:3000";
let cookie = "";

async function call(path, init = {}) {
  const headers = { "content-type": "application/json", ...(init.headers ?? {}) };
  if (cookie) headers.cookie = cookie;
  const res = await fetch(`${BASE}${path}`, { ...init, headers });
  const setCookie = res.headers.get("set-cookie");
  if (setCookie) cookie = setCookie.split(";")[0];
  const body = await res.json().catch(() => ({}));
  return { status: res.status, body };
}

const wallet = Wallet.createRandom();
console.log(`1. Generated EVM wallet: ${wallet.address}`);

const cfg = await call("/api/config");
console.log(`2. GET /api/config -> ${cfg.status} (session established); rails=${JSON.stringify(cfg.body?.data?.rails)}`);

const nonce = await call("/api/wallets/nonce", {
  method: "POST",
  body: JSON.stringify({ chain: "evm", address: wallet.address }),
});
console.log(`3. POST /api/wallets/nonce -> ${nonce.status}`);
const message = nonce.body?.data?.message;
if (!message) throw new Error(`No challenge message returned: ${JSON.stringify(nonce.body)}`);
console.log(`   challenge: ${JSON.stringify(message)}`);

const signature = await wallet.signMessage(message);
console.log(`4. Signed challenge -> ${signature.slice(0, 24)}...`);

const link = await call("/api/wallets", {
  method: "POST",
  body: JSON.stringify({ chain: "evm", address: wallet.address, message, signature, label: "hello-world" }),
});
console.log(`5. POST /api/wallets -> ${link.status}: ${JSON.stringify(link.body)}`);

const list = await call("/api/wallets");
console.log(`6. GET /api/wallets -> ${list.status}: ${JSON.stringify(list.body)}`);

const linked = list.body?.data?.wallets ?? [];
const ok = link.status === 200 && linked.some((w) => w.address?.toLowerCase() === wallet.address.toLowerCase());
console.log(ok ? "\nHELLO-WORLD OK: wallet linked & verified end-to-end." : "\nHELLO-WORLD FAILED.");
process.exit(ok ? 0 : 1);
