/**
 * Serialize signed claim into a TON Cell (BOC) for TonConnect wallet broadcast.
 * Step 4b — frontend sends `bocBase64` via @tonconnect/ui-react.
 */
import { Address, beginCell } from "@ton/core";
import { OP_CLAIM, gameEnv } from "@/lib/game/config";
import type { SettlementPayload } from "@/lib/game/signing";

export interface SettlementCell {
  contractAddress: string;
  valueNanoton: string;
  bocBase64: string;
  opcode: number;
}

function equipmentHashToInt(hex: string): bigint {
  return BigInt(`0x${hex.replace(/^0x/, "")}`);
}

export function buildClaimSettlementCell(
  payload: SettlementPayload,
  signatureHex: string,
): SettlementCell {
  const contract = gameEnv.playerSbtAddress();
  if (!contract) {
    throw new Error("PLAYERSBT_CONTRACT_ADDRESS not configured");
  }

  const sig = Buffer.from(signatureHex, "hex");
  const cell = beginCell()
    .storeUint(OP_CLAIM, 32)
    .storeAddress(Address.parse(payload.wallet))
    .storeUint(payload.level, 16)
    .storeUint(equipmentHashToInt(payload.equipmentHash), 256)
    .storeCoins(BigInt(payload.emissionNano))
    .storeUint(payload.chainTimestamp, 32)
    .storeUint(payload.serverTimestamp, 32)
    .storeUint(payload.deltaTime, 32)
    .storeBuffer(sig)
    .endCell();

  return {
    contractAddress: contract,
    valueNanoton: gameEnv.claimValueNanoton(),
    bocBase64: cell.toBoc().toString("base64"),
    opcode: OP_CLAIM,
  };
}
