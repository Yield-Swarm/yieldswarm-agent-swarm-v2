# Helix Nodes — install (developer mode)

1. Open `chrome://extensions`
2. Enable **Developer mode**
3. **Load unpacked** → select this folder (`extensions/helix-node`)
4. Ensure YieldSwarm backend is running on `http://127.0.0.1:8080`

The extension registers a node, sends heartbeats every 5 minutes, and shows lottery tickets in the popup.

**Production API:** set `apiBase` in extension storage to `https://mainnet.yieldswarm.network` (or your LB).

Icons: add `icons/icon16.png`, `icon48.png`, `icon128.png` before Chrome Web Store publish.
