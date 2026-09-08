import { defineConfig } from "vite";
import { svelte } from "@sveltejs/vite-plugin-svelte";
import { resolve } from "path";

export default defineConfig({
  server: {
    port: 1420,
    strictPort: true
  },
  plugins: [svelte()],
  build: {
    rollupOptions: {
      input: {
        main: resolve(__dirname, "index.html"),
        viewer: resolve(__dirname, "viewer.html")
      }
    }
  }
});
