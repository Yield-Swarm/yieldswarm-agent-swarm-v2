import type { Metadata, Viewport } from "next";
import "./tv.css";

export const metadata: Metadata = {
  title: "YieldSwarm Command Center",
  description: "TV dashboard — agents, treasury, multi-cloud, domains",
};

export const viewport: Viewport = {
  themeColor: "#06080f",
  colorScheme: "dark",
};

export default function TvLayout({ children }: { children: React.ReactNode }) {
  return <div className="tv-shell">{children}</div>;
}
