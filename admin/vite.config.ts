/// <reference types="vitest/config" />
import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  // 5173 is the origin registered with the Google web client and the R2
  // CORS rule, so fail rather than silently move to another port.
  server: { port: 5173, strictPort: true },
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/test/setup.ts'],
    // Most tests render the whole site. With every file running in
    // parallel, a slow machine can pass the 5 s default (bolt 052).
    testTimeout: 15_000,
  },
})
