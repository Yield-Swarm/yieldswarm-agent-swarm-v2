import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import path from 'path';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@yieldswarm/onchain-sdk': path.resolve(__dirname, '../sdk/src/index.ts'),
    },
  },
  server: { port: 3000, host: true },
  build: { outDir: 'dist' },
  css: { postcss: {} },
});
