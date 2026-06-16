/**
 * Infrastructure wallet helpers — tier-aware signing boundaries (Greek D¹).
 * @module src/infrastructure/wallet/index
 */

/**
 * Resolve max spend for NFT tier (used by dYdX + leasing modules).
 * @param {number} tier 0..4
 */
export function tierSpendLimitUsd(tier) {
  const limits = [500, 2_000, 10_000, 50_000, 250_000];
  return limits[Math.min(tier, 4)] ?? limits[0];
}

/**
 * Check whether address is authorized for agent tokenId operations.
 * @param {string} address
 * @param {object} nftOwnerMap tokenId → owner address
 * @param {string|number} tokenId
 */
export function isAuthorizedForAgent(address, nftOwnerMap, tokenId) {
  const owner = nftOwnerMap[String(tokenId)];
  return owner && owner.toLowerCase() === address.toLowerCase();
}

export default { tierSpendLimitUsd, isAuthorizedForAgent };
