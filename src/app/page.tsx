import fs from "node:fs";
import path from "node:path";
import Script from "next/script";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "YieldSwarm — 14-Lane Jacuzzi Helix Solenoid | DePIN + AI DAO",
  description:
    "YieldSwarm v2: 10,080 agents, 120 crons, 169 Deities on Akash. Jacuzzi-energy Helix solenoid across 14 lanes. Z15 revenue, NFT marketplace.",
  openGraph: {
    title: "YieldSwarm — Jacuzzi Helix Solenoid",
    description: "14-lane energy flow mesh. $7,500+ revenue live.",
    images: ["/assets/jacuzzi-helix-hero.png"],
  },
};

function loadHomeBody(): string {
  const file = path.join(process.cwd(), "index.html");
  const html = fs.readFileSync(file, "utf8");
  const match = html.match(/<body[^>]*>([\s\S]*)<\/body>/i);
  return (match?.[1] ?? "").replace(/<script[\s\S]*?<\/script>/gi, "");
}

export default function HomePage() {
  return (
    <>
      <link rel="stylesheet" href="/assets/helix-jacuzzi.css" />
      <div dangerouslySetInnerHTML={{ __html: loadHomeBody() }} />
      <Script src="/assets/helix-site.js" strategy="afterInteractive" />
      <Script src="/integrations/neon-queries.js" strategy="afterInteractive" />
      <Script id="helix-home-init" strategy="afterInteractive">
        {`
          (function waitForSite() {
            if (typeof YieldSwarmSite === 'undefined') {
              setTimeout(waitForSite, 50);
              return;
            }
            var nav = document.getElementById('nav-root');
            if (nav) nav.innerHTML = YieldSwarmSite.renderNav('home');
            var grid = document.getElementById('lane-grid');
            if (grid) grid.innerHTML = YieldSwarmSite.renderLaneGrid();
            var bubbles = document.getElementById('hero-bubbles');
            if (bubbles) YieldSwarmSite.initBubbles(bubbles);
            YieldSwarmSite.hydrateMetrics();
            setInterval(function () { YieldSwarmSite.hydrateMetrics(); }, 30000);
          })();
        `}
      </Script>
    </>
  );
}
