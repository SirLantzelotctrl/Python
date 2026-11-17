import { defineConfig } from 'vite';

// base './' para que el mismo build funcione en Vercel, itch.io y portales
// (que sirven el juego desde subcarpetas).
export default defineConfig(({ mode }) => ({
  base: './',
  build: {
    outDir: mode === 'portal' ? 'dist-portal' : 'dist',
    assetsInlineLimit: 0,
    chunkSizeWarningLimit: 1200,
    target: 'es2020',
  },
  server: { port: 5173 },
}));
