import type { Config } from "tailwindcss";

const config: Config = {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        swarm: {
          bg: "#05070a",
          panel: "#0c1118",
          border: "#1b2430",
          accent: "#22d3ee",
          accent2: "#34d399",
          danger: "#f87171",
          muted: "#7d8da0",
        },
      },
      fontFamily: {
        mono: ["ui-monospace", "SFMono-Regular", "Menlo", "monospace"],
      },
    },
  },
  plugins: [],
};

export default config;
