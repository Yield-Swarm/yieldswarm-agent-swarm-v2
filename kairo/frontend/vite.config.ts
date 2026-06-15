import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5174,
    proxy: {
      "/api": {
        target: process.env.KAIRO_API_URL || "http://127.0.0.1:8100",
        changeOrigin: true,
      },
    },
  },
  define: {
    "import.meta.env.VITE_MAPBOX_TOKEN": JSON.stringify(process.env.VITE_MAPBOX_TOKEN || ""),
    "import.meta.env.VITE_KAIRO_API_URL": JSON.stringify(process.env.VITE_KAIRO_API_URL || ""),
  },
});
