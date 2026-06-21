import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  base: '/runic/',
  server: {
    port: 5175,
    proxy: {
      '/api': 'http://127.0.0.1:8099',
      '/ws': { target: 'ws://127.0.0.1:8099', ws: true },
    },
  },
  build: {
    outDir: 'dist',
    emptyOutDir: true,
  },
});
