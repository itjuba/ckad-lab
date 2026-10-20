import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// 127.0.0.1, not localhost: the server listens on IPv4 only and Node may resolve localhost to ::1.
const BACKEND = 'http://127.0.0.1:8090'

// The Go server (sim/ui/server) serves dist/ and the API on :8090.
// `npm run dev` proxies the API (including the terminal WebSocket) to it. The server only
// accepts same-origin requests, so the proxy presents the backend's own origin.
export default defineConfig({
  plugins: [react()],
  build: { outDir: 'dist', chunkSizeWarningLimit: 1200 },
  server: {
    port: 5180,
    proxy: {
      '/api': {
        target: BACKEND,
        ws: true,
        changeOrigin: true,
        configure: (proxy) => {
          proxy.on('proxyReq', (req) => req.setHeader('origin', BACKEND))
          proxy.on('proxyReqWs', (req) => req.setHeader('origin', BACKEND))
        },
      },
    },
  },
})
