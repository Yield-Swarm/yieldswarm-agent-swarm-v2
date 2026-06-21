# TV & Mobile Command Dashboard

Unified dark-mode dashboard for **Samsung TV**, **Fire Stick**, **Apple TV**, and **Pixel 10a**.

Connects all three solenoids + 14 spiritual elevators + live treasury (including IoTeX).

## URL

| Device | URL |
|--------|-----|
| Any TV browser | `http://<host>:8080/command` |
| Short alias | `http://<host>:8080/tv` |
| API payload | `GET /api/command/overview` |

## Quick start (VM / local)

```bash
cd yieldswarm-agent-swarm-v2
git checkout cursor/solenoid-nexus-helix-shadow-4f85
cp .env.example .env   # fill UD_API_KEY, VAULT_*, RPC URLs
./scripts/run-tv-dashboard.sh
```

## Samsung TV

1. Open **Samsung Internet** (or Smart Hub browser)
2. Navigate to `http://4.147.152.142:8080/command`
3. Add to Home Screen: Menu → Add Page to → Home Screen
4. Use arrow keys on remote — dashboard supports D-pad focus navigation

## Amazon Fire Stick

1. Install **Silk Browser** or **Firefox** from Amazon Appstore
2. Open `http://<your-server-ip>:8080/command`
3. Bookmark for one-tap launch

## Apple TV

1. Use **AirPlay** from iPhone Safari, or
2. Install a browser app (e.g. **Surfer**) if available on tvOS
3. URL: `http://<server>:8080/command`

## Google Pixel 10a

```bash
# Termux on Pixel
pkg install termux-api
cd ~/yieldswarm-agent-swarm-v2
./scripts/run-tv-dashboard.sh

# Or tunnel to remote VM:
ssh -L 8080:127.0.0.1:8080 -i ~/.ssh/yieldswarm_key yieldswarm@4.147.152.142
```

Then open Chrome: `http://localhost:8080/command`

## Environment variables

| Variable | Purpose |
|----------|---------|
| `UD_API_KEY` | Unstoppable Domains resolution |
| `UD_DOMAINS` | Comma-separated domain list (optional) |
| `VAULT_ADDR` | Vault health indicator |
| `SOLANA_RPC_URL` | Solana live status |
| `PORT` | Backend port (default 8080) |

Secrets live in Vault / `.env` only — never committed.

## 14 Spiritual Elevators

Configured in `config/spiritual-elevators.json`:

1. Emerald Tablets of Thoth
2. Book of Enoch
3. Judas · Mary Magdalene · Lost Books
4. Astrology texts
5. The Iliad
6. The Odyssey
7. Percy Jackson (Greek/Roman/Egyptian)
8. Bulgarian Bible
9. The Quran
10. Lotus texts of Mahayana Buddhism
11. Tibetan Book of the Dead
12. The Kybalion
13. Popol Vuh
14. Tao Te Ching

## API

```bash
curl -s http://localhost:8080/api/command/overview | jq '.solenoids, .treasury.mining_roots.iotex'
curl -s http://localhost:8080/api/command/health
curl -s http://localhost:8080/api/command/elevators
```
