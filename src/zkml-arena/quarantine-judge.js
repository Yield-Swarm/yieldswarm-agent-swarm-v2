/**
 * Quarantined LLM judge — sandboxed peer-review scorer.
 * Production: route to isolated Akash worker; dev: deterministic heuristic.
 */

const { MAX_INPUT } = require("./reputation-scorer");

const INJECTION_PATTERNS = [
  /ignore\s+(all\s+)?previous/i,
  /system\s*:/i,
  /<\s*script/i,
  /```/,
  /\bDAN\b/,
];

function sanitizeBattleLog(log) {
  if (log == null) return "";
  const text = String(log).slice(0, 16_384);
  for (const pattern of INJECTION_PATTERNS) {
    if (pattern.test(text)) {
      throw new Error("prompt_injection_blocked");
    }
  }
  return text.replace(/[\x00-\x08\x0b\x0c\x0e-\x1f]/g, "");
}

/**
 * Deterministic peer review from battle metrics (no external LLM in CI/dev).
 * @param {{ winRate?: number, consistency?: number, battleLog?: string, rounds?: number }} battle
 * @returns {Promise<number>} scaled 0–10000
 */
async function callQuarantinedJudge(battle = {}) {
  sanitizeBattleLog(battle.battleLog);

  const winRate = Number(battle.winRate ?? 5000);
  const consistency = Number(battle.consistency ?? 5000);
  const rounds = Math.max(1, Number(battle.rounds ?? 1));

  // Heuristic: blend win/consistency with log length signal (bounded)
  const logBonus = Math.min(1000, Math.floor((battle.battleLog?.length ?? 0) / 10));
  const raw = (winRate * 0.5 + consistency * 0.35 + logBonus * 1.5) / rounds;
  return Math.min(MAX_INPUT, Math.max(0, Math.floor(raw)));
}

module.exports = {
  sanitizeBattleLog,
  callQuarantinedJudge,
  INJECTION_PATTERNS,
};
