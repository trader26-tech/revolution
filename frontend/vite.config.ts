import { fileURLToPath, URL } from "node:url";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { VitePWA } from "vite-plugin-pwa";

// https://vite.dev/config/
export default defineConfig({
  // Baked in at build time and shown on the Settings screen, so any device can
  // prove which deploy it is actually running (ends the "is my change live?"
  // guessing game — a stale PWA shows a stale stamp).
  define: {
    __BUILD_TS__: JSON.stringify(new Date().toISOString()),
  },
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
    },
  },
  // `vite preview` in production (Railway) serves behind an unknown host.
  // Allow it so it doesn't return "Blocked request. This host is not allowed."
  preview: {
    host: true,
    allowedHosts: true,
  },
  plugins: [
    react(),
    VitePWA({
      // "prompt" so a new deploy surfaces an in-app "Update available" dialog
      // instead of swapping silently (which left users on the old UI until they
      // happened to fully relaunch). See <UpdatePrompt/>.
      registerType: "prompt",
      includeAssets: ["favicon.svg", "apple-touch-icon.png"],
      manifest: {
        name: "Revolution — Subscription Tracker",
        short_name: "Revolution",
        description:
          "The subscription tracker that stops surprise charges. See every bill before you're charged.",
        theme_color: "#0b0320",
        background_color: "#060010",
        display: "standalone",
        orientation: "portrait",
        scope: "/",
        start_url: "/",
        categories: ["finance", "productivity"],
        icons: [
          { src: "icon-192.png", sizes: "192x192", type: "image/png" },
          { src: "icon-512.png", sizes: "512x512", type: "image/png" },
          {
            src: "icon-maskable-512.png",
            sizes: "512x512",
            type: "image/png",
            purpose: "maskable",
          },
        ],
      },
      workbox: {
        globPatterns: ["**/*.{js,css,html,svg,png,woff2}"],
        navigateFallback: "index.html",
      },
      devOptions: { enabled: false },
    }),
  ],
});
