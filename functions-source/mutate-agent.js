// Chainlink Functions source — fetch Arena performance and compute mutation tier.
// Args: [0] = tokenId, secrets.ARENA_API_KEY for auth

const tokenId = args[0];
const apiBase = secrets.ARENA_API_BASE || "https://your-arena-api.example.com";
const apiKey = secrets.ARENA_API_KEY || "";

const response = await Functions.makeHttpRequest({
  url: `${apiBase}/api/agents/${tokenId}/arena-week`,
  headers: apiKey ? { Authorization: `Bearer ${apiKey}` } : {},
});

if (response.error) {
  throw Error(`Arena API error: ${response.error}`);
}

const data = response.data;
const winRate = Number(data.win_rate || data.winRate || 0);
let tier = 1;
if (winRate > 50) tier = 2;
if (winRate > 75) tier = 3;
if (winRate > 90) tier = 5;

const newURI = `${apiBase}/metadata/agent/${tokenId}?tier=${tier}&week=${data.week || 0}`;

return Functions.encodeAbi(
  ["uint256", "uint8", "uint16", "string"],
  [BigInt(tokenId), tier, Math.round(winRate * 100), newURI]
);
